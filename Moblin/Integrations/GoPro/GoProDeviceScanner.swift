@preconcurrency import CoreBluetooth
import Foundation

struct GoProDiscoveredDevice {
    let peripheral: CBPeripheral
    let name: String
}

final class GoProDeviceScanner: NSObject, ObservableObject {
    nonisolated(unsafe) static let shared = GoProDeviceScanner()
    @Published var discoveredDevices: [GoProDiscoveredDevice] = []
    private var centralManager: CBCentralManager?

    func startScanningForDevices() {
        logger.info("gopro-scanner: Starting scan")
        discoveredDevices = []
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopScanningForDevices() {
        logger.info("gopro-scanner: Stopping scan; found \(discoveredDevices.count) camera(s)")
        centralManager?.stopScan()
        centralManager = nil
    }
}

extension GoProDeviceScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        logger.info("gopro-scanner: Bluetooth state \(central.state.rawValue)")
        guard central.state == .poweredOn else {
            return
        }
        logger.info("gopro-scanner: Scanning for OpenGoPro service \(GoProBleUuid.controlService)")
        central.scanForPeripherals(withServices: [GoProBleUuid.controlService])
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi: NSNumber
    ) {
        guard !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) else {
            return
        }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
            ?? String(localized: "Unknown")
        logger.info(
            "gopro-scanner: Found \(name) with peripheral id \(peripheral.identifier), RSSI \(rssi) dBm"
        )
        discoveredDevices.append(.init(peripheral: peripheral, name: name))
    }
}
