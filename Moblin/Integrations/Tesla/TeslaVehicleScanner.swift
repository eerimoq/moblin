import CoreBluetooth

class TeslaVehicleScanner: NSObject, ObservableObject {
    nonisolated(unsafe) static let shared = TeslaVehicleScanner()
    @Published var discoveredPeripherals: [CBPeripheral] = []
    private var centralManager: CBCentralManager?

    func startScanningForDevices() {
        discoveredPeripherals = []
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopScanningForDevices() {
        centralManager?.stopScan()
        centralManager = nil
    }
}

extension TeslaVehicleScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: nil)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi _: NSNumber
    ) {
        guard let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
            return
        }
        guard localName.wholeMatch(of: /S[0-9a-f]{16}C/) != nil else {
            return
        }
        guard !discoveredPeripherals.contains(where: { $0 == peripheral }) else {
            return
        }
        discoveredPeripherals.append(peripheral)
    }
}
