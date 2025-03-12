import CoreBluetooth

struct CyclingPowerDeviceDiscoved {
    let peripheral: CBPeripheral
}

class CyclingPowerDeviceScanner: NSObject, ObservableObject {
    static let shared = CyclingPowerDeviceScanner()
    @Published var discoveredDevices: [CyclingPowerDeviceDiscoved] = []
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

extension CyclingPowerDeviceScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: [cyclingPowerServiceId])
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
