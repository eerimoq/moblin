//
// Created by Spillmaker on 17/07/2024.
//

import CoreBluetooth

struct DjiGimbalDiscoveredDevice {
    let peripheral: CBPeripheral
    let model: SettingsDjiGimbalDeviceModel
}

class DjiGimbalDeviceScanner: NSObject, ObservableObject {
    static let shared = DjiGimbalDeviceScanner()
    @Published var discoveredDevices: [DjiGimbalDiscoveredDevice] = []
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

extension DjiGimbalDeviceScanner: CBCentralManagerDelegate {
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
        let model = djiGimbalModelFromManufacturerData(data: manufacturerData)
        logger.info("""
        dji-gimbal-scanner: Manufacturer data \(manufacturerData.hexString()) for \
        peripheral id \(peripheral.identifier) and model \(model)
        """)
        discoveredDevices.append(.init(peripheral: peripheral, model: model))
    }
}
