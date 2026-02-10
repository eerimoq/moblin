import CoreBluetooth

class BluetoothScanner: NSObject, ObservableObject {
    @Published var discoveredPeripherals: [CBPeripheral] = []
    private var centralManager: CBCentralManager?
    private let serviceIds: [CBUUID]

    init(serviceIds: [CBUUID]) {
        self.serviceIds = serviceIds
    }

    func startScanningForDevices() {
        discoveredPeripherals = []
        centralManager = CBCentralManager(delegate: self, queue: .main)
    }

    func stopScanningForDevices() {
        centralManager?.stopScan()
        centralManager = nil
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: serviceIds)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi _: NSNumber
    ) {
        guard !discoveredPeripherals.contains(where: { $0 == peripheral }) else {
            return
        }
        discoveredPeripherals.append(peripheral)
    }
}
