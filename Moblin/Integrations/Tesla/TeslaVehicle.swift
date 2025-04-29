import Collections
import CoreBluetooth
import CryptoKit

private let vehicleServiceUuid = CBUUID(string: "00000211-b2d1-43f0-9b88-960cebf8b91e")
private let toVehicleUuid = CBUUID(string: "00000212-b2d1-43f0-9b88-960cebf8b91e")
private let fromVehicleUuid = CBUUID(string: "00000213-b2d1-43f0-9b88-960cebf8b91e")

enum TeslaVehicleState {
    case idle
    case discovering
    case connecting
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
    let sharedSecret = Data(Insecure.SHA1.hash(data: sharedData).prefix(16))
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

    func removeJobs() {
        jobs.removeAll()
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

func teslaGeneratePrivateKey() -> P256.KeyAgreement.PrivateKey {
    return P256.KeyAgreement.PrivateKey()
}

protocol TeslaVehicleDelegate: AnyObject {
    func teslaVehicleState(_ vehicle: TeslaVehicle, state: TeslaVehicleState)
    func teslaVehicleVehicleSecurityConnected(_ vehicle: TeslaVehicle)
    func teslaVehicleInfotainmentConnected(_ vehicle: TeslaVehicle)
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
    weak var delegate: (any TeslaVehicleDelegate)?
    private let vehicleSecurityHandshakeTimer = SimpleTimer(queue: .main)
    private let infotainmentHandshakeTimer = SimpleTimer(queue: .main)

    init?(vin: String, privateKeyPem: String, handshake _: Bool = true) {
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
        reset()
        centralManager = CBCentralManager(delegate: self, queue: .main)
        vehicleDomains[.vehicleSecurity] = VehicleDomain(clientPrivateKey)
        vehicleDomains[.infotainment] = VehicleDomain(clientPrivateKey)
        setState(state: .discovering)
    }

    func stop() {
        reset()
    }

    private func reset() {
        vehicleSecurityHandshakeTimer.stop()
        infotainmentHandshakeTimer.stop()
        centralManager = nil
        vehiclePeripheral = nil
        toVehicleCharacteristic = nil
        fromVehicleCharacteristic = nil
        responseHandlers.removeAll()
        receiveBuffer.removeAll()
        vehicleDomains.removeAll()
        setState(state: .idle)
    }

    func addKeyRequestWithRole(privateKeyPem: String) {
        do {
            let privateKey = try P256.KeyAgreement.PrivateKey(pemRepresentation: privateKeyPem)
            let clientPublicKeyBytes = privateKey.publicKey.toBytes()
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
        } catch {
            logger.info("tesla-vehicle: Add key error \(error)")
        }
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

    func honk() {
        var action = CarServer_Action()
        action.vehicleAction.vehicleControlHonkHornAction = .init()
        executeCarServerAction(action) { _ in
            logger.debug("tesla-vehicle: Honk response")
        }
    }

    func flashLights() {
        var action = CarServer_Action()
        action.vehicleAction.vehicleControlFlashLightsAction = .init()
        executeCarServerAction(action) { _ in
            logger.debug("tesla-vehicle: Flash lights response")
        }
    }

    func mediaNextTrack() {
        var action = CarServer_Action()
        action.vehicleAction.mediaNextTrack = .init()
        executeCarServerAction(action) { _ in
            logger.debug("tesla-vehicle: Media next track response")
        }
    }

    func mediaPreviousTrack() {
        var action = CarServer_Action()
        action.vehicleAction.mediaPreviousTrack = .init()
        executeCarServerAction(action) { _ in
            logger.debug("tesla-vehicle: Media previous track response")
        }
    }

    func mediaTogglePlayback() {
        var action = CarServer_Action()
        action.vehicleAction.mediaPlayAction = .init()
        executeCarServerAction(action) { _ in
            logger.debug("tesla-vehicle: Media toggle playback response")
        }
    }

    func getChargeState(onCompleted: @escaping (CarServer_ChargeState) -> Void) {
        var action = CarServer_Action()
        action.vehicleAction.getVehicleData.getChargeState = .init()
        executeCarServerAction(action) { response in
            onCompleted(response.vehicleData.chargeState)
        }
    }

    func getDriveState(onCompleted: @escaping (CarServer_DriveState) -> Void) {
        var action = CarServer_Action()
        action.vehicleAction.getVehicleData.getDriveState = .init()
        executeCarServerAction(action) { response in
            onCompleted(response.vehicleData.driveState)
        }
    }

    func getMediaState(onCompleted: @escaping (CarServer_MediaState) -> Void) {
        var action = CarServer_Action()
        action.vehicleAction.getVehicleData.getMediaState = .init()
        executeCarServerAction(action) { response in
            onCompleted(response.vehicleData.mediaState)
        }
    }

    private func executeClosureMoveAction(_ closureMoveRequest: VCSEC_ClosureMoveRequest,
                                          onCompleted: @escaping () throws -> Void)
    {
        guard state == .connected else {
            return
        }
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
        guard state == .connected else {
            return
        }
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
        delegate?.teslaVehicleState(self, state: state)
    }

    private func localName() -> String {
        let hash = Data(Insecure.SHA1.hash(data: vin.utf8Data).prefix(8)).hexString()
        return "S\(hash)C"
    }

    private func getNextAddress() -> Data {
        return Data.random(length: 16)
    }

    private func startVehicleSecurityHandshake() throws {
        try sendSessionInfoRequest(domain: .vehicleSecurity)
        vehicleSecurityHandshakeTimer.startSingleShot(timeout: 10.0) { [weak self] in
            do {
                try self?.startVehicleSecurityHandshake()
            } catch {
                logger.info("tesla-vehicle: Failed to start vehicle security handshake with error \(error)")
            }
        }
    }

    private func startInfotainmentHandshake() throws {
        try sendSessionInfoRequest(domain: .infotainment)
        infotainmentHandshakeTimer.startSingleShot(timeout: 10.0) { [weak self] in
            do {
                try self?.startInfotainmentHandshake()
            } catch {
                logger.info("tesla-vehicle: Failed to start infotainment handshake with error \(error)")
            }
        }
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
            do {
                try self.handleSessionInfoResponse(message, response)
            } catch {
                logger.debug("tesla-vehicle: Session info failed with \(error)")
            }
        }
        try sendMessage(message: message)
    }

    private func handleSessionInfoResponse(
        _: UniversalMessage_RoutableMessage,
        _ response: UniversalMessage_RoutableMessage
    ) throws {
        let domain = response.fromDestination.domain
        let sessionInfo = try Signatures_SessionInfo(serializedBytes: response.sessionInfo)
        guard let vehicleDomain = vehicleDomains[domain] else {
            return
        }
        try vehicleDomain.updateSesionInfo(sessionInfo: sessionInfo)
        vehicleDomain.removeJobs()
        switch domain {
        case .vehicleSecurity:
            vehicleSecurityHandshakeTimer.stop()
            delegate?.teslaVehicleVehicleSecurityConnected(self)
            try startInfotainmentHandshake()
        case .infotainment:
            infotainmentHandshakeTimer.stop()
            delegate?.teslaVehicleInfotainmentConnected(self)
        default:
            break
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
        try job.onCompleted(request, response)
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
        try metadata.add(tag: .personalization, vin.utf8Data)
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
        logger.debug("tesla-vehicle: Connect failure")
        reset()
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.debug("tesla-vehicle: Connected")
        peripheral.discoverServices([vehicleServiceUuid])
    }

    func centralManager(_: CBCentralManager, didDisconnectPeripheral _: CBPeripheral, error _: Error?) {
        logger.debug("tesla-vehicle: Disconnected")
        reset()
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
        setState(state: .connected)
        do {
            try startVehicleSecurityHandshake()
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
            reset()
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
