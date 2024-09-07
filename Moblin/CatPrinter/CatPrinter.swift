// Based on https://github.com/rbaron/catprinter
// MIT License

import Collections
import CoreBluetooth
import CoreImage
import Foundation

enum CatPrinterState {
    case idle
    case discovering
}

let catPrinterServices = [
    CBUUID(string: "0000ae30-0000-1000-8000-00805f9b34fb"),
    CBUUID(string: "0000af30-0000-1000-8000-00805f9b34fb"),
]

private struct PrintJob {
    let image: CIImage
}

class CatPrinter: NSObject {
    private var state: CatPrinterState = .idle
    private var centralManager: CBCentralManager?
    private let context = CIContext()
    private var printJobs: Deque<PrintJob> = []
    private var currentPrintJob: PrintJob?

    func start(deviceId _: UUID) {
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
        guard currentPrintJob == nil else {
            return
        }
        currentPrintJob = printJobs.popFirst()
        guard let currentPrintJob else {
            return
        }
        logger.info("cat-printer: Printing...")
        let _image = process(image: currentPrintJob.image)
        let commands = packPrintImageCommands(image: [
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
        send(data: commands)
    }

    private func send(data: Data) {
        logger.info("cat-printer: Sending \(data)...")
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
        setState(state: .idle)
        printJobs.removeAll()
        currentPrintJob = nil
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
        logger.info("cat-printer: peripheral didDiscoverServices \(peripheral.services)")
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
        _: CBPeripheral,
        didUpdateNotificationStateFor characteristic: CBCharacteristic,
        error _: Error?
    ) {
        logger.info("cat-printer: peripheral didUpdateNotificationStateFor characteristic \(characteristic)")
    }

    func peripheralIsReady(toSendWriteWithoutResponse _: CBPeripheral) {
        logger.info("cat-printer: peripheral toSendWriteWithoutResponse")
    }
}
