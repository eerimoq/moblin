// Based on https://github.com/rbaron/catprinter
// MIT License

import Collections
import CoreBluetooth
import CoreImage
import Foundation

private let catPrinterDispatchQueue = DispatchQueue(label: "com.eerimoq.cat-printer")

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
    private let ditheringAlgorithm: DitheringAlgorithm = .atkinson

    func start(deviceId: UUID?) {
        catPrinterDispatchQueue.async {
            self.startInternal(deviceId: deviceId)
        }
    }

    func stop() {
        catPrinterDispatchQueue.async {
            self.stopInternal()
        }
    }

    func print(image: CIImage) {
        catPrinterDispatchQueue.async {
            self.printInternal(image: image)
        }
    }

    private func startInternal(deviceId: UUID?) {
        self.deviceId = deviceId
        reset()
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: catPrinterDispatchQueue)
    }

    private func stopInternal() {
        reset()
    }

    private func printInternal(image: CIImage) {
        guard printJobs.count < 10 else {
            logger.info("cat-printer: Too many jobs. Discarding image.")
            return
        }
        printJobs.append(PrintJob(image: image))
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
        guard let image = process(image: printJob.image) else {
            return
        }
        let data = catPrinterPackPrintImageCommands(image: image)
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
            catPrinterDispatchQueue.asyncAfter(deadline: .now() + 0.1) {
                self.tryWriteNextChunk()
            }
        } else {
            currentJob = nil
            tryPrintNext()
        }
    }

    private func process(image: CIImage) -> [[Bool]]? {
        var image = image
        let filter = CIFilter.colorMonochrome()
        filter.inputImage = image
        filter.color = CIColor(red: 1, green: 1, blue: 1)
        filter.intensity = 1.0
        image = filter.outputImage ?? image
        let scale = 384 / image.extent.width
        image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cgImage = context.createCGImage(image, from: image.extent) else {
            logger.info("cat-printer: Failed to create core graphics image")
            return nil
        }
        guard let data = cgImage.dataProvider?.data else {
            logger.info("cat-printer: Failed to get data")
            return nil
        }
        let length = CFDataGetLength(data)
        guard let data = CFDataGetBytePtr(data) else {
            logger.info("cat-printer: Failed to get length")
            return nil
        }
        guard cgImage.bitsPerComponent == 8 else {
            logger.info("cat-printer: Expected 8 bits per component, but got \(cgImage.bitsPerComponent)")
            return nil
        }
        guard cgImage.bitsPerPixel == 32 else {
            logger.info("cat-printer: Expected 32 bits per pixel, but got \(cgImage.bitsPerPixel)")
            return nil
        }
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
        switch ditheringAlgorithm {
        case .floydSteinberg:
            pixels = FloydSteinbergDithering().apply(image: pixels)
        case .atkinson:
            pixels = AtkinsonDithering().apply(image: pixels)
        }
        return pixels.map { $0.map { $0 < 127 } }
    }

    private func reset() {
        centralManager = nil
        peripheral = nil
        printCharacteristic = nil
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
            case notifyId:
                peripheral?.setNotifyValue(true, for: characteristic)
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
}
