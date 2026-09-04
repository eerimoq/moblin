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
        discoveredDevices = []
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopScanningForDevices() {
        centralManager?.stopScan()
        centralManager = nil
    }
}

extension GoProDeviceScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard central.state == .poweredOn else {
            return
        }
        central.scanForPeripherals(withServices: [goProControlServiceId])
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        guard !discoveredDevices.contains(where: { $0.peripheral.identifier == peripheral.identifier }) else {
            return
        }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
            ?? peripheral.name
            ?? String(localized: "Unknown")
        discoveredDevices.append(.init(peripheral: peripheral, name: name))
    }
}
