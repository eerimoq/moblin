// Based on https://github.com/rbaron/catprinter
// MIT License

import Collections
import CoreBluetooth
import CoreImage
import Foundation

enum CatPrinterState {
    case disconnected
    case discovering
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

class CatPrinter: NSObject {
    private var state: CatPrinterState = .disconnected
    private var centralManager: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private let context = CIContext()
    private var printJobs: Deque<PrintJob> = []
    private var currentJob: CurrentJob?

    func start(deviceId _: UUID) {
        reset()
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stop() {
        reset()
    }

    func print(image: CIImage) {
        guard state == .connected else {
            logger.info("cat-printer: Not connected. Discarding image.")
            return
        }
        guard printJobs.count < 10 else {
            logger.info("cat-printer: Too many jobs. Discarding image.")
            return
        }
        printJobs.append(PrintJob(image: image))
        tryPrintNext()
    }

    private func reconnect() {}

    private func tryPrintNext() {
        guard currentJob == nil else {
            return
        }
        let printJob = printJobs.popFirst()
        guard let printJob else {
            return
        }
        logger.info("cat-printer: Printing...")
        let _image = process(image: printJob.image)
        let data = packPrintImageCommands(image: [
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
        guard let peripheral else {
            reconnect()
            return
        }
        currentJob = CurrentJob(data: data, mtu: peripheral.maximumWriteValueLength(for: .withResponse))
        guard let chunk = currentJob?.nextChunk(), let characteristic else {
            reconnect()
            return
        }
        peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
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

    func centralManager(_: CBCentralManager,
                        didDiscover _: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi _: NSNumber)
    {
        logger.info("cat-printer: centralManager didDiscover \(advertisementData)")
    }

    func centralManager(_: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error _: Error?) {
        logger.info("cat-printer: centralManager didFailToConnect \(peripheral)")
    }

    func centralManager(_: CBCentralManager, didConnect peripheral: CBPeripheral) {
        logger.info("cat-printer: centralManager didConnect \(peripheral)")
        self.peripheral = peripheral
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
        logger.info("cat-printer: Got \(value.hexString())")
        if value.hexString() == "5178ae0101001070ff" {
            logger.info("Busy, cannot write.")
        } else if value.hexString() == "5178ae0101000000ff" {
            logger.info("Idle, can write.")
        } else if value[2] == 0xA3 {
            logger.info("Printer status.")
        }
    }

    func peripheral(
        _ peripheral: CBPeripheral,
        didWriteValueFor characteristic: CBCharacteristic,
        error _: (any Error)?
    ) {
        if let chunk = currentJob?.nextChunk() {
            peripheral.writeValue(chunk, for: characteristic, type: .withResponse)
        } else {
            currentJob = nil
            tryPrintNext()
        }
    }
}
