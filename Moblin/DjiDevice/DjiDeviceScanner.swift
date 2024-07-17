//
// Created by Spillmaker on 17/07/2024.
//

import CoreBluetooth

class DjiDeviceScanner: NSObject {
    static let shared = DjiDeviceScanner()
    @Published var discoveredDevices: [CBPeripheral] = []
    private var centralManager: CBCentralManager?

    func startScanningForDevices() {
        discoveredDevices = []
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stopScanningForDevices() {
        centralManager?.stopScan()
        centralManager = nil
    }
}

extension DjiDeviceScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        guard let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data else {
            return
        }
        guard manufacturerData.prefix(2) == djiTechnologyCoLtd else {
            return
        }
        guard !discoveredDevices.contains(peripheral) else {
            return
        }
        discoveredDevices.append(peripheral)
    }
}
