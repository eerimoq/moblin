// Based on https://github.com/rbaron/catprinter
// MIT License

import Collections
import CoreBluetooth
import CoreImage
import Foundation

enum CatPrinterState {
    case disconnected
    case discovering
    case connecting
    case connected
}

private enum JobState {
    case idle
    case waitingForReady
    case writingChunks
}

private class CurrentJob {
    let data: Data
    var offset: Int = 0
    let mtu: Int
    var state: JobState = .idle

    init(data: Data, mtu: Int) {
        self.data = data
        self.mtu = mtu
    }

    func setState(state: JobState) {
        guard state != self.state else {
            return
        }
        logger.info("cat-printer: Job sate change \(self.state) -> \(state)")
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

let catPrinterServices = [
    CBUUID(string: "0000af30-0000-1000-8000-00805f9b34fb"),
]

private let printId = CBUUID(string: "AE01")
// periphery:ignore
private let notifyId = CBUUID(string: "AE02")

private struct PrintJob {
    let image: CIImage
}

class CatPrinter: NSObject {
    private var state: CatPrinterState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var printCharacteristic: CBCharacteristic?
    private let context = CIContext()
    private var printJobs: Deque<PrintJob> = []
    private var currentJob: CurrentJob?
    private var deviceId: UUID?

    func start(deviceId: UUID?) {
        self.deviceId = deviceId
        reset()
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stop() {
        reset()
    }

    func print(image: CIImage) {
        logger.info("cat-printer: Print!")
        guard printJobs.count < 10 else {
            logger.info("cat-printer: Too many jobs. Discarding image.")
            return
        }
        printJobs.append(PrintJob(image: image))
        tryPrintNext()
    }

    private func tryPrintNext() {
        logger.info("cat-printer: Try print!")
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
        logger.info("cat-printer: Printing...")
        _ = process(image: printJob.image)
        let blackFirstRow: [Bool] = (0 ..< 384).map { i in
            (i / 32) % 2 == 0
        }
        let whiteFirstRow: [Bool] = (0 ..< 384).map { i in
            (i / 32) % 2 == 1
        }
        let blackFirstRows: [[Bool]] = (0 ..< 32).map { _ in
            blackFirstRow
        }
        let whiteFirstRows: [[Bool]] = (0 ..< 32).map { _ in
            whiteFirstRow
        }
        let data = catPrinterPackPrintImageCommands(
            image: blackFirstRows + whiteFirstRows + blackFirstRows + whiteFirstRows
                + blackFirstRows + whiteFirstRows + blackFirstRows + whiteFirstRows
                + blackFirstRows + whiteFirstRows + blackFirstRows + whiteFirstRows
        )
        currentJob = CurrentJob(data: data, mtu: peripheral.maximumWriteValueLength(for: .withoutResponse))
        let message = CatPrinterCommand.getDeviceState().pack()
        guard let printCharacteristic, let currentJob else {
            return
        }
        currentJob.setState(state: .waitingForReady)
        peripheral.writeValue(message, for: printCharacteristic, type: .withoutResponse)
    }

    private func tryWriteNextChunk() {
        guard let peripheral, let printCharacteristic else {
            return
        }
        if let chunk = currentJob?.nextChunk() {
            peripheral.writeValue(chunk, for: printCharacteristic, type: .withoutResponse)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.tryWriteNextChunk()
            }
        } else {
            currentJob = nil
            tryPrintNext()
        }
    }

    // Each returned byte is a grayscale pixel
    private func process(image: CIImage) -> ([UInt8], CGSize)? {
        var image = image
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = image
        filter.color = CIColor(red: 0.75, green: 0.75, blue: 0.75)
        filter.intensity = 1.0
        image = filter.outputImage ?? image
        let scale = 384 / image.extent.width
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            return nil
        }
        guard let data = cgImage.dataProvider?.data else {
            return nil
        }
        let length = CFDataGetLength(data)
        guard let data = CFDataGetBytePtr(data) else {
            return nil
        }
        return (Data(bytes: data, count: length).bytes, image.extent.size)
    }

    private func reset() {
        centralManager = nil
        printJobs.removeAll()
        currentJob = nil
        setState(state: .disconnected)
    }

    private func reconnect() {
        centralManager = nil
        setState(state: .disconnected)
    }

    private func setState(state: CatPrinterState) {
        guard state != self.state else {
            return
        }
        logger.info("cat-printer: State change \(self.state) -> \(state)")
        self.state = state
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

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error _: Error?) {
        logger.info("cat-printer: centralManager didFailToConnect \(peripheral)")
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        peripheral.discoverServices(nil)
        setState(state: .connected)
    }

    func centralManager(
        _: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error _: Error?
    ) {
        logger.info("cat-printer: centralManager didDisconnectPeripheral \(peripheral)")
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
            case printId:
                printCharacteristic = characteristic
            default:
                break
            }
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        guard let value = characteristic.value, let currentJob else {
            return
        }
        guard let command = CatPrinterCommand(data: value) else {
            logger.info("cat-printer: Unknown command \(value.hexString())")
            return
        }
        logger.info("cat-printer: Got \(command)!")
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
        }
    }

    func peripheral(_: CBPeripheral, didWriteValueFor _: CBCharacteristic, error _: (any Error)?) {
        logger.info("cat-printer: Write response.")
        // tryWriteNextChunk()
    }
}
