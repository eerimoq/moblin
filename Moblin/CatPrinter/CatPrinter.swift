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

private class CurrentJob {
    let data: Data
    var offset: Int = 0
    let mtu: Int

    init(data: Data, mtu: Int) {
        self.data = data
        self.mtu = mtu
    }

    func nextChunk() -> Data? {
        logger.info("cat-printer: At offset \(offset) of \(data.count)")
        let chunk = data[offset ..< offset + mtu]
        guard !chunk.isEmpty else {
            return nil
        }
        offset += mtu
        return chunk
    }
}

let catPrinterServices = [
    CBUUID(string: "0000ae30-0000-1000-8000-00805f9b34fb"),
    CBUUID(string: "0000af30-0000-1000-8000-00805f9b34fb"),
]

private struct PrintJob {
    let image: CIImage
}

struct PrinterStatus {
    var readyForWrite = false
    var readyToStartPrinting = false
    var noPaper = false
    var coverIsOpen = false
    var isOverheated = false
    var batteryIsLow = false
}

class CatPrinter: NSObject {
    private var state: CatPrinterState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private let context = CIContext()
    private var printJobs: Deque<PrintJob> = []
    private var currentJob: CurrentJob?
    private var deviceId: UUID?
    private var printerStatus = PrinterStatus()
    private var waitingForWriteResponse = false

    func start(deviceId: UUID) {
        self.deviceId = deviceId
        reset()
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stop() {
        reset()
    }

    func print(image: CIImage) {
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
        guard currentJob == nil, printerStatus.readyToStartPrinting else {
            return
        }
        guard let printJob = printJobs.popFirst() else {
            return
        }
        logger.info("cat-printer: Printing...")
        _ = process(image: printJob.image)
        let data = catPrinterPackPrintImageCommands(image: [
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
            [true, true, true, true, true, true, true, true],
        ])
        currentJob = CurrentJob(data: data, mtu: peripheral.maximumWriteValueLength(for: .withResponse))
        tryWriteNextChunk()
    }

    private func tryWriteNextChunk() {
        guard !waitingForWriteResponse, printerStatus.readyForWrite, let peripheral, let characteristic else {
            return
        }
        if let chunk = currentJob?.nextChunk() {
            waitingForWriteResponse = true
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
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
                        advertisementData: [String: Any],
                        rssi _: NSNumber)
    {
        logger.info("cat-printer: centralManager didDiscover \(advertisementData)")
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
        logger.info("cat-printer: peripheral didDiscoverServices \(peripheral.services ?? [])")
        for service in peripheral.services ?? [] {
            logger.info("cat-printer: service \(service)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        logger.info("cat-printer: didDiscoverCharacteristicsFor \(service)")
        for characteristic in service.characteristics ?? [] {
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        logger.info("cat-printer: peripheral didUpdateValueFor characteristic \(characteristic)")
        guard let value = characteristic.value else {
            return
        }
        guard let (command, data) = try? catPrinterUnpackCommand(data: value) else {
            return
        }
        switch command {
        case .writePacing:
            if data.count == 1 {
                if data[0] == 0x01 {
                    logger.info("Busy, cannot write.")
                    printerStatus.readyForWrite = false
                } else if data[0] == 0x00 {
                    logger.info("Idle, can write.")
                    printerStatus.readyForWrite = true
                    tryWriteNextChunk()
                }
            }
        case .getDeviceState:
            logger.info("Got printer status.")
            if data.count == 1 {
                printerStatus.noPaper = (data[0] & 0b0000_0001) == 0b0000_0001
                printerStatus.coverIsOpen = (data[0] & 0b0000_0010) == 0b0000_0010
                printerStatus.isOverheated = (data[0] & 0b0000_0100) == 0b0000_0100
                printerStatus.batteryIsLow = (data[0] & 0b0000_1000) == 0b0000_1000
                printerStatus.readyToStartPrinting = data[0] == 0
                tryPrintNext()
            }
        default:
            break
        }
        logger.info("cat-printer: Status \(printerStatus)")
    }

    func peripheral(
        _: CBPeripheral,
        didWriteValueFor _: CBCharacteristic,
        error _: (any Error)?
    ) {
        logger.info("cat-printer: Write response.")
        waitingForWriteResponse = false
        tryWriteNextChunk()
    }
}
