import CoreBluetooth

struct HeartRateDeviceDiscoved {
    let peripheral: CBPeripheral
}

class HeartRateDeviceScanner: NSObject, ObservableObject {
    static let shared = HeartRateDeviceScanner()
    @Published var discoveredDevices: [HeartRateDeviceDiscoved] = []
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

extension HeartRateDeviceScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [heartRateServiceId])
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi _: NSNumber
    ) {
        guard !discoveredDevices.contains(where: { $0.peripheral == peripheral }) else {
            return
        }
        discoveredDevices.append(.init(peripheral: peripheral))
    }
}
