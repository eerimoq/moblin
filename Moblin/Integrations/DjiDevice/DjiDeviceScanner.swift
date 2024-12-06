//
// Created by Spillmaker on 17/07/2024.
//

import CoreBluetooth

struct DjiDiscoveredDevice {
    let peripheral: CBPeripheral
    let model: SettingsDjiDeviceModel
}

class DjiDeviceScanner: NSObject {
    static let shared = DjiDeviceScanner()
    @Published var discoveredDevices: [DjiDiscoveredDevice] = []
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
        guard isDjiDevice(manufacturerData: manufacturerData) else {
            return
        }
        guard !discoveredDevices.contains(where: { $0.peripheral == peripheral }) else {
            return
        }
        let model = djiModelFromManufacturerData(data: manufacturerData)
        logger.info("""
        dji-scanner: Manufacturer data \(manufacturerData.hexString()) for \
        peripheral id \(peripheral.identifier) and model \(model)
        """)
        discoveredDevices.append(.init(peripheral: peripheral, model: model))
    }
}
