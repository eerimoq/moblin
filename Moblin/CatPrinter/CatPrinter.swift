// Based on https://github.com/rbaron/catprinter
// MIT License

import CoreBluetooth
import CoreImage
import Foundation

private enum State {
    case idle
    case discovering
}

private let services = [
    CBUUID(string: "0000ae30-0000-1000-8000-00805f9b34fb"),
    CBUUID(string: "0000af30-0000-1000-8000-00805f9b34fb"),
]

class CatPrinter: NSObject {
    private var state: State = .idle
    private var centralManager: CBCentralManager?
    private let context = CIContext()

    func start(deviceId _: UUID) {
        reset()
        setState(state: .discovering)
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stop() {
        reset()
    }

    func print(image: CIImage) {
        let image = process(image: image)
        let command = createPrintImageCommand(image: [[true, false]])
        logger.info("cat-printer: Command \(command)")
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
    }

    private func setState(state: State) {
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
            centralManager?.scanForPeripherals(withServices: services)
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
        guard let peripheralServices = peripheral.services else {
            return
        }
        for service in peripheralServices {
            logger.info("cat-printer: service \(service)")
        }
    }

    func peripheral(
        _: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error _: Error?
    ) {
        logger.info("cat-printer: didDiscoverCharacteristicsFor \(service)")
    }

    func peripheral(_: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error _: Error?) {
        logger.info("cat-printer: peripheral didUpdateValueFor characteristic \(characteristic)")
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
