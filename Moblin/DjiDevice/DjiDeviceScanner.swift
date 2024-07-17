//
// Created by Spillmaker on 17/07/2024.
//

import CoreBluetooth
import Foundation

class DjiDeviceScanner: NSObject {
    static let shared = DjiDeviceScanner()
    @Published var discoveredDevices: [CBPeripheral] = []
    private var centralManager: CBCentralManager?

    private override init() {
        super.init()
    }

    func startScanningForDevices() {
        print("Starting to scan for devices...")
        discoveredDevices = []
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stopScanningForDevices() {
        print("Stopping to scan for devices...")
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

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {

            let manufacturerDataString = manufacturerData.map { String(format: "%02hhx", $0) }.joined()
            let manufacturerIdData = manufacturerData.prefix(2)

            let desiredManufacturerIdData = Data([0xAA, 0x08])
            if manufacturerIdData == desiredManufacturerIdData {

                // Check if device is already in list, if its not, add it.
                if !discoveredDevices.contains(peripheral) {
                    discoveredDevices.append(peripheral)
                }
            }

        }

    }
}
