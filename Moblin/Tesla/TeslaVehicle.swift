import Collections
import CoreBluetooth
import CryptoKit
import Telegraph

private let vehicleServiceUuid = CBUUID(string: "00000211-b2d1-43f0-9b88-960cebf8b91e")
private let toVehicleUuid = CBUUID(string: "00000212-b2d1-43f0-9b88-960cebf8b91e")
private let fromVehicleUuid = CBUUID(string: "00000213-b2d1-43f0-9b88-960cebf8b91e")

private enum TeslaVehicleState {
    case idle
    case discovering
    case connecting
    case handshaking
    case connected
}

private func createSymmetricKey(clientPrivateKey: P256.KeyAgreement.PrivateKey,
                                vehiclePublicKey: Data) throws -> SymmetricKey
{
    let publicKey = try P256.KeyAgreement.PublicKey(bytes: vehiclePublicKey)
    let shared = try clientPrivateKey.sharedSecretFromKeyAgreement(with: publicKey)
    let sharedData = shared.withUnsafeBytes { buffer in
        Data(bytes: buffer.baseAddress!, count: buffer.count)
    }
    let sharedSecret = SHA1(data: sharedData).digest[0 ..< 16]
    return SymmetricKey(data: sharedSecret)
}

extension P256.KeyAgreement.PublicKey {
    init(bytes: Data) throws {
        // Dirty, dirty, dirty...
        let derStuff = Data([
            0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86,
            0x48, 0xCE, 0x3D, 0x02, 0x01, 0x06, 0x08, 0x2A,
            0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03,
            0x42, 0x00,
        ])
        try self.init(derRepresentation: derStuff + bytes)
    }

    func toBytes() -> Data {
        return derRepresentation[26...]
    }
}

private struct Job {
    let address: Data
    let playload: Data
    let onCompleted: (_ request: UniversalMessage_RoutableMessage,
                      _ response: UniversalMessage_RoutableMessage) throws -> Void
}

private class VehicleDomain {
    private let clientPrivateKey: P256.KeyAgreement.PrivateKey
    private var sessionInfo: Signatures_SessionInfo?
    private var localClock: ContinuousClock.Instant = .now
    private var jobs: Deque<Job> = []
    private var symmetricKey: SymmetricKey?

    init(_ clientPrivateKey: P256.KeyAgreement.PrivateKey) {
        self.clientPrivateKey = clientPrivateKey
    }

    func updateSesionInfo(sessionInfo: Signatures_SessionInfo) throws {
        symmetricKey = try createSymmetricKey(
            clientPrivateKey: clientPrivateKey,
            vehiclePublicKey: sessionInfo.publicKey
        )
        self.sessionInfo = sessionInfo
        localClock = .now
    }

    func getSymmetricKey() throws -> SymmetricKey {
        guard let symmetricKey else {
            throw "Symmetric key missing"
        }
        return symmetricKey
    }

    func appendJob(
        address: Data,
        payload: Data,
        onCompleted: @escaping (_ request: UniversalMessage_RoutableMessage,
                                _ response: UniversalMessage_RoutableMessage) throws -> Void
    ) {
        jobs.append(Job(address: address, playload: payload, onCompleted: onCompleted))
    }

    func tryGetNextJob() -> Job? {
        guard hasSessionInfo() else {
            return nil
        }
        return jobs.popFirst()
    }

    func hasSessionInfo() -> Bool {
        return sessionInfo != nil
    }

    func epoch() -> Data {
        return sessionInfo?.epoch ?? Data()
    }

    func nextCounter() -> UInt32 {
        sessionInfo?.counter += 1
        return sessionInfo?.counter ?? 0
    }

    func expiresAt() -> UInt32 {
        let clockTime = sessionInfo?.clockTime ?? 0
        let elapsed = UInt32(localClock.duration(to: .now).seconds)
        return clockTime + elapsed + 15
    }
}

private func generateKeyPair() -> (P256.KeyAgreement.PrivateKey, P256.KeyAgreement.PublicKey) {
    let privateKey = P256.KeyAgreement.PrivateKey()
    let publicKey = privateKey.publicKey
    return (privateKey, publicKey)
}

class TeslaVehicle: NSObject {
    private let vin: String
    private let clientPrivateKey: P256.KeyAgreement.PrivateKey
    private let clientPublicKeyBytes: Data
    private var centralManager: CBCentralManager?
    private var vehiclePeripheral: CBPeripheral?
    private var toVehicleCharacteristic: CBCharacteristic?
    private var fromVehicleCharacteristic: CBCharacteristic?
    private var state: TeslaVehicleState = .idle
    private var responseHandlers: [Data: (UniversalMessage_RoutableMessage) throws -> Void] = [:]
    private var receiveBuffer = Data()
    private var vehicleDomains: [UniversalMessage_Domain: VehicleDomain] = [:]

    init?(vin: String, privateKeyPem: String) {
        self.vin = vin
        do {
            clientPrivateKey = try P256.KeyAgreement.PrivateKey(pemRepresentation: privateKeyPem)
        } catch {
            logger.error("tesla-vehicle: Error \(error)")
            return nil
        }
        clientPublicKeyBytes = clientPrivateKey.publicKey.toBytes()
    }

    func start() {
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: .main)
        vehicleDomains[.vehicleSecurity] = VehicleDomain(clientPrivateKey)
        vehicleDomains[.infotainment] = VehicleDomain(clientPrivateKey)
    }

    func stop() {
        centralManager = nil
        vehiclePeripheral = nil
        toVehicleCharacteristic = nil
        fromVehicleCharacteristic = nil
        responseHandlers.removeAll()
        receiveBuffer.removeAll()
        vehicleDomains.removeAll()
        setState(state: .idle)
    }

    func addKeyRequestWithRole() throws {
        var message = VCSEC_UnsignedMessage()
        message.whitelistOperation.addKeyToWhitelistAndAddPermissions.key.publicKeyRaw = clientPublicKeyBytes
        message.whitelistOperation.addKeyToWhitelistAndAddPermissions.keyRole = .owner
        message.whitelistOperation.metadataForKey.keyFormFactor = .cloudKey
        var encoded = try message.serializedData()
        var envelope = VCSEC_ToVCSECMessage()
        envelope.signedMessage.protobufMessageAsBytes = encoded
        envelope.signedMessage.signatureType = .presentKey
        encoded = try envelope.serializedData()
        sendData(message: encoded)
    }

    func openTrunk() {
        var closureMoveRequest = VCSEC_ClosureMoveRequest()
        closureMoveRequest.rearTrunk = .closureMoveTypeOpen
        executeClosureMoveAction(closureMoveRequest) {
            logger.info("tesla-vehicle: Open trunk response")
        }
    }

    func closeTrunk() {
        var closureMoveRequest = VCSEC_ClosureMoveRequest()
        closureMoveRequest.rearTrunk = .closureMoveTypeClose
        executeClosureMoveAction(closureMoveRequest) {
            logger.info("tesla-vehicle: Close trunk response")
        }
    }

    func ping() {
        var action = CarServer_Action()
        action.vehicleAction.ping.pingID = 1
        executeCarServerAction(action) { _ in
            logger.info("tesla-vehicle: Ping response")
            // try logger.info("tesla-vehicle: Message \(response.jsonString())")
        }
    }

    func honk() {
        var action = CarServer_Action()
        action.vehicleAction.vehicleControlHonkHornAction = .init()
        executeCarServerAction(action) { _ in
            logger.info("tesla-vehicle: Honk response")
        }
    }

    func flashLights() {
        var action = CarServer_Action()
        action.vehicleAction.vehicleControlFlashLightsAction = .init()
        executeCarServerAction(action) { _ in
            logger.info("tesla-vehicle: Flash lights response")
        }
    }

    func mediaNextTrack() {
        var action = CarServer_Action()
        action.vehicleAction.mediaNextTrack = .init()
        executeCarServerAction(action) { _ in
            logger.info("tesla-vehicle: Media next track response")
        }
    }

    func mediaTogglePlayback() {
        var action = CarServer_Action()
        action.vehicleAction.mediaPlayAction = .init()
        executeCarServerAction(action) { _ in
            logger.info("tesla-vehicle: Media toggle playback response")
        }
    }

    func getChargeState(onCompleted: @escaping (CarServer_ChargeState) -> Void) {
        var action = CarServer_Action()
        action.vehicleAction.getVehicleData.getChargeState = .init()
        executeCarServerAction(action) { response in
            let chargeState = response.vehicleData.chargeState
            logger.info("tesla-vehicle: Battery level \(chargeState.batteryLevel)")
            logger.info("tesla-vehicle: Minutes to charge limit \(chargeState.minutesToChargeLimit)")
            logger.info("tesla-vehicle: Charger power \(chargeState.chargerPower)")
            logger.info("tesla-vehicle: Charging state \(chargeState.chargingState)")
            onCompleted(chargeState)
        }
    }

    func getDriveState(onCompleted: @escaping (CarServer_DriveState) -> Void) {
        var action = CarServer_Action()
        action.vehicleAction.getVehicleData.getDriveState = .init()
        executeCarServerAction(action) { response in
            logger.info("tesla-vehicle: Drive state response")
            let driveState = response.vehicleData.driveState
            logger.info("tesla-vehicle: Active route destination \(driveState.activeRouteDestination)")
            logger.info("tesla-vehicle: Active route minutes to arrival \(driveState.activeRouteMinutesToArrival)")
            logger.info("tesla-vehicle: Power \(driveState.power)")
            logger.info("tesla-vehicle: Shift state \(driveState.shiftState)")
            try logger.info("tesla-vehicle: Message \(response.jsonString())")
            onCompleted(driveState)
        }
    }

    func getMediaState(onCompleted: @escaping (CarServer_MediaState) -> Void) {
        var action = CarServer_Action()
        action.vehicleAction.getVehicleData.getMediaState = .init()
        executeCarServerAction(action) { response in
            logger.info("tesla-vehicle: Media state response")
            let mediaState = response.vehicleData.mediaState
            logger.info("tesla-vehicle: Now playing title \(mediaState.nowPlayingTitle)")
            logger.info("tesla-vehicle: Now playing source \(mediaState.nowPlayingSource)")
            try logger.info("tesla-vehicle: Message \(response.jsonString())")
            onCompleted(mediaState)
        }
    }

    private func executeClosureMoveAction(_ closureMoveRequest: VCSEC_ClosureMoveRequest,
                                          onCompleted: @escaping () throws -> Void)
    {
        guard let vehicleDomain = vehicleDomains[.vehicleSecurity] else {
            return
        }
        var unsignedMessage = VCSEC_UnsignedMessage()
        unsignedMessage.closureMoveRequest = closureMoveRequest
        do {
            let payload = try unsignedMessage.serializedData()
            vehicleDomain.appendJob(address: getNextAddress(), payload: payload) { _, _ in
                try onCompleted()
            }
            try trySendNextJob(domain: .vehicleSecurity)
        } catch {
            logger.info("tesla-vehicle: Execute closure move action error \(error)")
        }
    }

    private func executeCarServerAction(
        _ action: CarServer_Action,
        onCompleted: @escaping (CarServer_Response) throws -> Void
    ) {
        guard let vehicleDomain = vehicleDomains[.infotainment] else {
            return
        }
        do {
            let payload = try action.serializedData()
            vehicleDomain.appendJob(address: getNextAddress(), payload: payload) { request, response in
                let aesGcmResponseData = response.signatureData.aesGcmResponseData
                let sealedBox = try AES.GCM.SealedBox(nonce: .init(data: aesGcmResponseData.nonce),
                                                      ciphertext: response.protobufMessageAsBytes,
                                                      tag: aesGcmResponseData.tag)
                let metadataHash = try self.createResponseMetadata(request, response)
                let decoded = try AES.GCM.open(sealedBox,
                                               using: vehicleDomain.getSymmetricKey(),
                                               authenticating: metadataHash)
                let response = try CarServer_Response(serializedBytes: decoded)
                if response.actionStatus.result != .operationstatusOk {
                    logger.info("tesla-vehicle: Car server response status not ok")
                }
                try onCompleted(response)
            }
            try trySendNextJob(domain: .infotainment)
        } catch {
            logger.info("tesla-vehicle: Execute car server action error \(error)")
        }
    }

    private func setState(state: TeslaVehicleState) {
        guard state != self.state else {
            return
        }
        logger.info("tesla-vehicle: State change \(self.state) -> \(state)")
        self.state = state
    }

    private func localName() -> String {
        let hash = SHA1.hash(vin.utf8Data).prefix(8).hexString()
        return "S\(hash)C"
    }

    private func getNextAddress() -> Data {
        return Data.random(length: 16)
    }

    private func startHandshake() throws {
        setState(state: .handshaking)
        try sendSessionInfoRequest(domain: .vehicleSecurity)
        try sendSessionInfoRequest(domain: .infotainment)
    }

    private func sendSessionInfoRequest(domain: UniversalMessage_Domain) throws {
        let address = getNextAddress()
        let uuid = Data.random(length: 16)
        var message = UniversalMessage_RoutableMessage()
        message.toDestination.domain = domain
        message.fromDestination.routingAddress = address
        message.sessionInfoRequest.publicKey = clientPublicKeyBytes
        message.uuid = uuid
        responseHandlers[address] = { response in
            try self.handleSessionInfoResponse(message, response)
        }
        try sendMessage(message: message)
    }

    private func handleSessionInfoResponse(
        _: UniversalMessage_RoutableMessage,
        _ response: UniversalMessage_RoutableMessage
    ) throws {
        let domain = response.fromDestination.domain
        let sessionInfo = try Signatures_SessionInfo(serializedBytes: response.sessionInfo)
        try vehicleDomains[domain]?.updateSesionInfo(sessionInfo: sessionInfo)
        if vehicleDomains.values.filter({ $0.hasSessionInfo() }).count == 2 {
            setState(state: .connected)
            try trySendNextJob(domain: .vehicleSecurity)
            try trySendNextJob(domain: .infotainment)
        }
    }

    private func startJob(domain: UniversalMessage_Domain, job: Job) throws {
        var request = UniversalMessage_RoutableMessage()
        request.toDestination.domain = domain
        request.fromDestination.routingAddress = job.address
        request.uuid = Data.random(length: 16)
        request.flags = 1 << UniversalMessage_Flags.flagEncryptResponse.rawValue
        try sign(message: &request, payload: job.playload)
        responseHandlers[job.address] = { response in
            try self.handleJobResponse(job, request, response)
        }
        try sendMessage(message: request)
    }

    private func handleJobResponse(_ job: Job,
                                   _ request: UniversalMessage_RoutableMessage,
                                   _ response: UniversalMessage_RoutableMessage) throws
    {
        let domain = response.fromDestination.domain
        try job.onCompleted(request, response)
        try trySendNextJob(domain: domain)
        guard response.signedMessageStatus.signedMessageFault == .rrorNone else {
            throw try "Request was not successful. Response \(response.jsonString())"
        }
    }

    private func trySendNextJob(domain: UniversalMessage_Domain) throws {
        while let job = vehicleDomains[domain]?.tryGetNextJob() {
            try startJob(domain: domain, job: job)
        }
    }

    private func handleData(data: Data) throws {
        receiveBuffer += data
        let reader = ByteArray(data: receiveBuffer)
        let size = try reader.readUInt16()
        if reader.bytesAvailable < size {
            return
        }
        let payload = try reader.readBytes(Int(size))
        // logger.info("tesla-vehicle: Got \(payload.hexString()) of \(payload.count) bytes")
        if reader.bytesAvailable > 0 {
            receiveBuffer = try reader.readBytes(reader.bytesAvailable)
        }
        let message = try UniversalMessage_RoutableMessage(serializedBytes: payload)
        guard case let .routingAddress(address) = message.toDestination.subDestination else {
            return
        }
        // try logger.info("tesla-vehicle: Got \(message.jsonString())")
        guard let responseHandler = responseHandlers.removeValue(forKey: address) else {
            logger.info("tesla-vehicle: No response handler found")
            return
        }
        try responseHandler(message)
    }

    private func sendMessage(message: UniversalMessage_RoutableMessage) throws {
        // try logger.info("tesla-vehicle: Sending \(message.jsonString())")
        try sendData(message: message.serializedData())
    }

    private func sendData(message: Data) {
        guard let toVehicleCharacteristic else {
            return
        }
        // logger.info("tesla-vehicle: Sending \(message.hexString())")
        let writer = ByteArray()
        writer.writeUInt16(UInt16(message.count))
        writer.writeBytes(message)
        let data = writer.data
        let blockLength = 20
        for offset in stride(from: 0, to: data.count, by: blockLength) {
            let block = data[offset ..< min(offset + blockLength, data.count)]
            vehiclePeripheral?.writeValue(block, for: toVehicleCharacteristic, type: .withResponse)
        }
    }

    private func sign(message: inout UniversalMessage_RoutableMessage, payload: Data) throws {
        guard let vehicleDomain = vehicleDomains[message.toDestination.domain] else {
            throw "Cannot sign for missing vehicle domain"
        }
        message.signatureData.signerIdentity.publicKey = clientPublicKeyBytes
        message.signatureData.aesGcmPersonalizedData.epoch = vehicleDomain.epoch()
        message.signatureData.aesGcmPersonalizedData.counter = vehicleDomain.nextCounter()
        message.signatureData.aesGcmPersonalizedData.expiresAt = vehicleDomain.expiresAt()
        let key = try vehicleDomain.getSymmetricKey()
        let metadataHash = try createRequestMetadata(message)
        let encrypted = try AES.GCM.seal(payload, using: key, authenticating: metadataHash)
        message.signatureData.aesGcmPersonalizedData.nonce = Data(encrypted.nonce.makeIterator())
        message.signatureData.aesGcmPersonalizedData.tag = encrypted.tag
        message.protobufMessageAsBytes = encrypted.ciphertext
    }

    private func createRequestMetadata(_ message: UniversalMessage_RoutableMessage) throws -> Data {
        let metadata = Metadata()
        try metadata.addUInt8(tag: .signatureType, UInt8(Signatures_SignatureType.aesGcmPersonalized.rawValue))
        try metadata.addUInt8(tag: .domain, UInt8(message.toDestination.domain.rawValue))
        try metadata.add(tag: .personalization, vin.utf8Data)
        try metadata.add(tag: .epoch, message.signatureData.aesGcmPersonalizedData.epoch)
        try metadata.addUInt32(tag: .expiresAt, message.signatureData.aesGcmPersonalizedData.expiresAt)
        try metadata.addUInt32(tag: .counter, message.signatureData.aesGcmPersonalizedData.counter)
        try metadata.addUInt32(tag: .flags, message.flags)
        return metadata.finalize(message: Data())
    }

    private func createResponseMetadata(_ request: UniversalMessage_RoutableMessage,
                                        _ response: UniversalMessage_RoutableMessage) throws -> Data
    {
        let metadata = Metadata()
        try metadata.addUInt8(tag: .signatureType, UInt8(Signatures_SignatureType.aesGcmResponse.rawValue))
        try metadata.addUInt8(tag: .domain, UInt8(response.fromDestination.domain.rawValue))
        try metadata.add(tag: .personalization, vin.utf8Data) // ?
        try metadata.addUInt32(tag: .counter, response.signatureData.aesGcmResponseData.counter)
        try metadata.addUInt32(tag: .flags, response.flags)
        var requestId = Data([UInt8(Signatures_SignatureType.aesGcmPersonalized.rawValue)])
        requestId += request.signatureData.aesGcmPersonalizedData.tag
        try metadata.add(tag: .requestHash, requestId)
        try metadata.addUInt32(tag: .fault, UInt32(response.signedMessageStatus.signedMessageFault.rawValue))
        return metadata.finalize(message: Data())
    }
}

extension TeslaVehicle: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.scanForPeripherals(withServices: nil)
        default:
            break
        }
    }

    func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        guard let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return
        }
        guard localName == self.localName() else {
            return
        }
        logger.info("tesla-vehicle: Connecting to \(localName)")
        central.stopScan()
        vehiclePeripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {
        logger.info("tesla-vehicle: Connect failure")
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("tesla-vehicle: Connected")
        peripheral.discoverServices([vehicleServiceUuid])
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        logger.info("tesla-vehicle: Disconnected")
    }
}

extension TeslaVehicle: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        guard let peripheralServices = peripheral.services else {
            logger.error("tesla-vehicle: No services found")
            return
        }
        for service in peripheralServices {
            peripheral.discoverCharacteristics([toVehicleUuid, fromVehicleUuid], for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error _: Error?) {
        for characteristic in service.characteristics ?? [] {
            if characteristic.uuid == toVehicleUuid {
                toVehicleCharacteristic = characteristic
            } else if characteristic.uuid == fromVehicleUuid {
                fromVehicleCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: fromVehicleCharacteristic!)
            }
        }
        do {
            try startHandshake()
        } catch {
            logger.info("tesla-vehicle: Failed to start handshake \(error)")
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value else {
            return
        }
        do {
            try handleData(data: value)
        } catch {
            logger.info("tesla-vehicle: Message handling error \(error)")
        }
    }
}

private class Metadata {
    private var writer = ByteArray()
    private var lastTag: Signatures_Tag?

    func add(tag: Signatures_Tag, _ value: Data) throws {
        if let lastTag {
            guard tag.rawValue > lastTag.rawValue else {
                throw "Must be added in increasing tags order"
            }
        }
        guard value.count <= 255 else {
            throw "Metadata value too long \(value.count)"
        }
        lastTag = tag
        writer.writeUInt8(UInt8(tag.rawValue))
        writer.writeUInt8(UInt8(value.count))
        writer.writeBytes(value)
    }

    func addUInt8(tag: Signatures_Tag, _ value: UInt8) throws {
        try add(tag: tag, Data([value]))
    }

    func addUInt32(tag: Signatures_Tag, _ value: UInt32) throws {
        var data = Data(count: 4)
        data.setUInt32Be(value: value)
        try add(tag: tag, data)
    }

    func finalize(message: Data) -> Data {
        writer.writeUInt8(UInt8(Signatures_Tag.end.rawValue))
        writer.writeBytes(message)
        return Data(SHA256.hash(data: writer.data))
    }
}
