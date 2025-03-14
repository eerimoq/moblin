import CoreBluetooth

class CatPrinterScanner: NSObject, ObservableObject {
    static let shared = CatPrinterScanner()
    @Published var discoveredPeripherals: [CBPeripheral] = []
    private var centralManager: CBCentralManager?

    func startScanningForDevices() {
        discoveredPeripherals = []
        centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
    }

    func stopScanningForDevices() {
        centralManager?.stopScan()
        centralManager = nil
    }
}

extension CatPrinterScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: catPrinterServices)
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
