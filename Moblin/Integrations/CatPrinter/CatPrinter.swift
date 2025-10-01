// Based on https://github.com/rbaron/catprinter
// MIT License

import AVFoundation
import Collections
import CoreBluetooth
import CoreImage
import Foundation

private let catPrinterDispatchQueue = DispatchQueue(label: "com.eerimoq.cat-printer")
let catPrinterWidthPixels = 384

protocol CatPrinterDelegate: AnyObject {
    func catPrinterState(_ catPrinter: CatPrinter, state: CatPrinterState)
}

enum CatPrinterState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private enum DitheringAlgorithm {
    case floydSteinberg
    case atkinson
}

private enum JobState {
    case idle
    case waitingForReady
    case waitingForPrintResponse
    case writingChunks
    case failed
}

private class CurrentJob {
    let data: Data
    var offset: Int = 0
    let mtu: Int
    var state: JobState = .idle
    let feedPaperDelay: Double?
    let printMode: CatPrinterPrintMode

    init(data: Data, mtu: Int, feedPaperDelay: Double?, printMode: CatPrinterPrintMode) {
        self.data = data
        self.mtu = mtu
        self.feedPaperDelay = feedPaperDelay
        self.printMode = printMode
    }

    func setState(state: JobState) {
        guard state != self.state else {
            return
        }
        logger.debug("cat-printer: Job state change \(self.state) -> \(state)")
        self.state = state
    }

    func nextChunk() -> Data? {
        guard offset < data.count else {
            return nil
        }
        let chunk = data[offset ..< min(offset + mtu, data.count)]
        guard !chunk.isEmpty else {
            return nil
        }
        offset += chunk.count
        return chunk
    }
}

private let catPrinterServices = [
    CBUUID(string: "0000af30-0000-1000-8000-00805f9b34fb"),
]

let catPrinterScanner = BluetoothScanner(serviceIds: catPrinterServices)

private let printCharacteristicId = CBUUID(string: "AE01")
private let notifyCharacteristicId = CBUUID(string: "AE02")
private let dataCharacteristicId = CBUUID(string: "AE03")

private struct PrintJob {
    let image: CIImage
    let feedPaperDelay: Double?
    let printMode: CatPrinterPrintMode
}

class CatPrinter: NSObject {
    private var state: CatPrinterState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var printCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var dataCharacteristic: CBCharacteristic?
    private let context = CIContext()
    private var printJobs: Deque<PrintJob> = []
    private var currentJob: CurrentJob?
    private var deviceId: UUID?
    private let ditheringAlgorithm: DitheringAlgorithm = .atkinson
    weak var delegate: (any CatPrinterDelegate)?
    private var tryWriteNextChunkTimer = SimpleTimer(queue: catPrinterDispatchQueue)
    private var jobCompleteTimer = SimpleTimer(queue: catPrinterDispatchQueue)
    private var feedPaperTimer = SimpleTimer(queue: catPrinterDispatchQueue)
    private var audioPlayer: AVAudioPlayer?
    private var meowSoundEnabled: Bool = false

    func start(deviceId: UUID?, meowSoundEnabled: Bool) {
        catPrinterDispatchQueue.async {
            self.meowSoundEnabled = meowSoundEnabled
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        catPrinterDispatchQueue.async {
            self.stopInternal()
        }
    }

    func setMeowSoundEnabled(meowSoundEnabled: Bool) {
        catPrinterDispatchQueue.async {
            self.meowSoundEnabled = meowSoundEnabled
        }
    }

    func print(image: CIImage, feedPaperDelay: Double? = nil) {
        catPrinterDispatchQueue.async {
            self.printInternal(image: image, feedPaperDelay: feedPaperDelay)
        }
    }

    func getState() -> CatPrinterState {
        return state
    }

    private func startInternal(deviceId: UUID?) {
        self.deviceId = deviceId
        reset()
        reconnect()
    }

    private func stopInternal() {
        reset()
    }

    private func isMxw01() -> Bool {
        return peripheral?.name == "MXW01"
    }

    private func printInternal(image: CIImage, feedPaperDelay: Double?) {
        guard printJobs.count < 50 else {
            return
        }
        printJobs.append(PrintJob(image: image, feedPaperDelay: feedPaperDelay, printMode: .blackAndWhite))
        tryPrintNext()
    }

    private func tryPrintNext() {
        guard let peripheral else {
            reconnect()
            return
        }
        guard currentJob == nil else {
            return
        }
        guard let printJob = printJobs.popFirst() else {
            return
        }
        let image: [[UInt8]]
        do {
            image = try processImage(image: printJob.image, printMode: printJob.printMode)
        } catch {
            logger.info("cat-printer: \(error)")
            return
        }
        if isMxw01() {
            tryPrintNextMxw01(printJob: printJob, image: image, peripheral: peripheral)
        } else {
            tryPrintNextDefault(printJob: printJob, image: image, peripheral: peripheral)
        }
        if meowSoundEnabled {
            playMeowSound()
        }
    }

    private func tryPrintNextMxw01(printJob: PrintJob, image: [[UInt8]], peripheral: CBPeripheral) {
        let data = catPrinterPackPrintImageCommandsMxw01(image: image, printMode: printJob.printMode)
        currentJob = CurrentJob(
            data: data,
            mtu: peripheral.maximumWriteValueLength(for: .withoutResponse),
            feedPaperDelay: printJob.feedPaperDelay,
            printMode: printJob.printMode
        )
        guard let printCharacteristic, let currentJob else {
            reconnect()
            return
        }
        currentJob.setState(state: .waitingForReady)
        send(command: .statusRequest, peripheral, printCharacteristic)
        startJobCompleteTimer()
    }

    private func tryPrintNextDefault(printJob: PrintJob, image: [[UInt8]], peripheral: CBPeripheral) {
        let data = catPrinterPackPrintImageCommands(
            image: image,
            feedPaper: printJob.feedPaperDelay == nil,
            printMode: printJob.printMode
        )
        currentJob = CurrentJob(
            data: data,
            mtu: peripheral.maximumWriteValueLength(for: .withoutResponse),
            feedPaperDelay: printJob.feedPaperDelay,
            printMode: printJob.printMode
        )
        stopFeedPaperTimer()
        guard let printCharacteristic, let currentJob else {
            reconnect()
            return
        }
        send(command: CatPrinterCommand.getDeviceState(), peripheral, printCharacteristic)
        currentJob.setState(state: .waitingForReady)
    }

    private func playMeowSound() {
        guard let soundUrl = Bundle.main.url(forResource: "Alerts.bundle/Nya", withExtension: "mp3") else {
            return
        }
        audioPlayer = try? AVAudioPlayer(contentsOf: soundUrl)
        audioPlayer?.play()
    }

    private func send(
        command: CatPrinterCommand,
        _ peripheral: CBPeripheral,
        _ characteristic: CBCharacteristic
    ) {
        send(data: command.pack(), peripheral, characteristic)
    }

    private func send(
        command: CatPrinterCommandMxw01,
        _ peripheral: CBPeripheral,
        _ characteristic: CBCharacteristic
    ) {
        // logger.info("cat-printer: Send \(command)")
        send(data: command.pack(), peripheral, characteristic)
    }

    private func send(data: Data, _ peripheral: CBPeripheral, _ characteristic: CBCharacteristic) {
        // logger.info("cat-printer: \(characteristic.uuid): Send \(data.hexString())")
        peripheral.writeValue(data, for: characteristic, type: .withoutResponse)
    }

    private func tryWriteNextChunk() {
        if isMxw01() {
            tryWriteNextChunkMxw01()
        } else {
            tryWriteNextChunkDefault()
        }
    }

    private func tryWriteNextChunkMxw01() {
        guard let peripheral, let dataCharacteristic else {
            reconnect()
            return
        }
        if let chunk = currentJob?.nextChunk() {
            send(data: chunk, peripheral, dataCharacteristic)
            startTryWriteNextChunkTimer()
        }
    }

    private func tryWriteNextChunkDefault() {
        guard let peripheral, let printCharacteristic else {
            reconnect()
            return
        }
        if let chunk = currentJob?.nextChunk() {
            send(data: chunk, peripheral, printCharacteristic)
            startTryWriteNextChunkTimer()
        } else {
            if let feedPaperDelay = currentJob?.feedPaperDelay, printJobs.isEmpty {
                stopFeedPaperTimer()
                startFeedPaperTimer(delay: feedPaperDelay)
            }
            currentJob = nil
            tryPrintNext()
        }
    }

    private func processImage(image: CIImage, printMode: CatPrinterPrintMode) throws -> [[UInt8]] {
        var image = makeMonochrome(image: image)
        image = scaleToPrinterWidth(image: image)
        var pixels = try convertToPixels(image: image)
        if printMode == .blackAndWhite {
            switch ditheringAlgorithm {
            case .floydSteinberg:
                pixels = FloydSteinbergDithering().apply(image: pixels)
            case .atkinson:
                pixels = AtkinsonDithering().apply(image: pixels)
            }
        }
        switch printMode {
        case .blackAndWhite:
            return pixels.map { $0.map { (255 - $0) / 128 } }
        case .grayscale:
            return pixels.map { $0.map { (255 - $0) / 16 } }
        }
    }

    private func makeMonochrome(image: CIImage) -> CIImage {
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = image
        filter.color = CIColor(red: 0.9, green: 0.9, blue: 0.9)
        filter.intensity = 1
        return filter.outputImage ?? image
    }

    private func scaleToPrinterWidth(image: CIImage) -> CIImage {
        let scale = CGFloat(catPrinterWidthPixels) / image.extent.width
        return image.scaled(x: scale, y: scale)
    }

    private func convertToPixels(image: CIImage) throws -> [[UInt8]] {
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            throw "Failed to create core graphics image"
        }
        guard let data = cgImage.dataProvider?.data else {
            throw "Failed to get data"
        }
        var length = CFDataGetLength(data)
        guard let data = CFDataGetBytePtr(data) else {
            throw "Failed to get length"
        }
        guard cgImage.bitsPerComponent == 8 else {
            throw "Expected 8 bits per component, but got \(cgImage.bitsPerComponent)"
        }
        guard cgImage.bitsPerPixel == 32 else {
            throw "Expected 32 bits per pixel, but got \(cgImage.bitsPerPixel)"
        }
        length = min(length, 4 * Int(image.extent.width * image.extent.height))
        var pixels: [[UInt8]] = []
        for rowOffset in stride(from: 0, to: length, by: 4 * Int(image.extent.width)) {
            var row: [UInt8] = []
            for columnOffset in stride(from: 0, to: 4 * Int(image.extent.width), by: 4) {
                if data[rowOffset + columnOffset + 3] != 255 {
                    row.append(255)
                } else {
                    row.append(data[rowOffset + columnOffset])
                }
            }
            pixels.append(row)
        }
        return pixels
    }

    private func reset() {
        centralManager = nil
        peripheral = nil
        printCharacteristic = nil
        notifyCharacteristic = nil
        dataCharacteristic = nil
        printJobs.removeAll()
        currentJob = nil
        stopTryWriteNextChunkTimer()
        stopJobCompleteTimer()
        stopFeedPaperTimer()
        setState(state: .disconnected)
    }

    private func reconnect() {
        peripheral = nil
        printCharacteristic = nil
        notifyCharacteristic = nil
        dataCharacteristic = nil
        currentJob = nil
        setState(state: .discovering)
        stopTryWriteNextChunkTimer()
        stopJobCompleteTimer()
        stopFeedPaperTimer()
        centralManager = CBCentralManager(delegate: self, queue: catPrinterDispatchQueue)
    }

    private func setState(state: CatPrinterState) {
        guard state != self.state else {
            return
        }
        logger.debug("cat-printer: State change \(self.state) -> \(state)")
        self.state = state
        delegate?.catPrinterState(self, state: state)
    }

    private func startTryWriteNextChunkTimer() {
        tryWriteNextChunkTimer.startSingleShot(timeout: 0.1) { [weak self] in
            self?.tryWriteNextChunk()
        }
    }

    private func stopTryWriteNextChunkTimer() {
        tryWriteNextChunkTimer.stop()
    }

    private func startJobCompleteTimer() {
        jobCompleteTimer.startSingleShot(timeout: 60) { [weak self] in
            self?.currentJob = nil
            self?.tryPrintNext()
        }
    }

    private func stopJobCompleteTimer() {
        jobCompleteTimer.stop()
    }

    private func startFeedPaperTimer(delay: Double) {
        feedPaperTimer.startSingleShot(timeout: delay) { [weak self] in
            self?.feedPaper()
        }
    }

    private func stopFeedPaperTimer() {
        feedPaperTimer.stop()
    }

    private func feedPaper() {
        guard let peripheral, let printCharacteristic else {
            return
        }
        send(command: .feedPaper(pixels: catPrinterFeedPaperPixels), peripheral, printCharacteristic)
    }
}

extension CatPrinter: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            centralManager?.scanForPeripherals(withServices: catPrinterServices)
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData _: [String: Any],
                        rssi _: NSNumber)
    {
        guard peripheral.identifier == deviceId else {
            return
        }
        central.stopScan()
        self.peripheral = peripheral
        peripheral.delegate = self
        central.connect(peripheral, options: nil)
        setState(state: .connecting)
    }

    func centralManager(_: CBCentralManager, didFailToConnect _: CBPeripheral, error _: Error?) {}

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
    }

    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral _: CBPeripheral,
        error _: Error?
    ) {
        reconnect()
    }
}

extension CatPrinter: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices _: Error?) {
        if let service = peripheral.services?.first {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case printCharacteristicId:
                printCharacteristic = characteristic
            case notifyCharacteristicId:
                notifyCharacteristic = characteristic
                peripheral?.setNotifyValue(true, for: characteristic)
            case dataCharacteristicId:
                dataCharacteristic = characteristic
            default:
                break
            }
        }
        if printCharacteristic != nil, notifyCharacteristic != nil, dataCharacteristic != nil {
            setState(state: .connected)
            tryPrintNext()
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        if isMxw01() {
            handleMessageMxw01(characteristic: characteristic)
        } else {
            handleMessageDefault(characteristic: characteristic)
        }
    }

    private func handleMessageMxw01(characteristic: CBCharacteristic) {
        guard let value = characteristic.value else {
            return
        }
        guard let command = CatPrinterCommandMxw01(data: value) else {
            return
        }
        // logger.info("cat-printer: Got \(command) \(value.hexString())")
        guard let currentJob else {
            return
        }
        switch currentJob.state {
        case .waitingForReady:
            handleMessageMxw01WaitingForReady(command: command, currentJob: currentJob)
        case .waitingForPrintResponse:
            handleMessageMxw01WaitingForPrintResponse(command: command, currentJob: currentJob)
        case .writingChunks:
            handleMessageMxw01WritingChunks(command: command)
        default:
            break
        }
    }

    private func handleMessageMxw01WaitingForReady(command: CatPrinterCommandMxw01, currentJob: CurrentJob) {
        guard let peripheral, let printCharacteristic else {
            return
        }
        switch command {
        case .statusResponse:
            currentJob.setState(state: .waitingForPrintResponse)
            let bytesPerLine: Int
            switch currentJob.printMode {
            case .blackAndWhite:
                bytesPerLine = catPrinterWidthPixels / 8
            case .grayscale:
                bytesPerLine = catPrinterWidthPixels / 2
            }
            let lineCount = UInt16(currentJob.data.count / bytesPerLine)
            send(command: .printRequest(printMode: currentJob.printMode, count: lineCount),
                 peripheral,
                 printCharacteristic)
        default:
            break
        }
    }

    private func handleMessageMxw01WaitingForPrintResponse(command: CatPrinterCommandMxw01, currentJob: CurrentJob) {
        switch command {
        case let .printResponse(status: status):
            if status == 0 {
                currentJob.setState(state: .writingChunks)
                tryWriteNextChunk()
            } else {
                currentJob.setState(state: .failed)
            }
        default:
            break
        }
    }

    private func handleMessageMxw01WritingChunks(command: CatPrinterCommandMxw01) {
        switch command {
        case .printCompleteIndication:
            stopJobCompleteTimer()
            currentJob = nil
            tryPrintNext()
        default:
            break
        }
    }

    private func handleMessageDefault(characteristic: CBCharacteristic) {
        guard let value = characteristic.value, let currentJob else {
            return
        }
        guard let command = CatPrinterCommand(data: value) else {
            return
        }
        switch currentJob.state {
        case .idle:
            break
        case .waitingForReady:
            switch command {
            case .getDeviceState:
                currentJob.setState(state: .writingChunks)
                tryWriteNextChunk()
            default:
                break
            }
        case .writingChunks:
            switch command {
            case .writePacing:
                tryWriteNextChunk()
            default:
                break
            }
        default:
            break
        }
    }
}

func catPrinterEncodeImageRow(_ imageRow: [UInt8], _ printMode: CatPrinterPrintMode) -> Data {
    switch printMode {
    case .blackAndWhite:
        var data = Data(count: imageRow.count / 8)
        for byteIndex in 0 ..< data.count {
            var byte: UInt8 = 0
            for bitIndex in 0 ..< 8 where imageRow[8 * byteIndex + bitIndex] == 1 {
                byte |= (1 << bitIndex)
            }
            data[byteIndex] = byte
        }
        return data
    case .grayscale:
        var data = Data(count: imageRow.count / 2)
        for byteIndex in 0 ..< data.count {
            data[byteIndex] = (imageRow[2 * byteIndex] << 4) | imageRow[2 * byteIndex + 1]
        }
        return data
    }
}
