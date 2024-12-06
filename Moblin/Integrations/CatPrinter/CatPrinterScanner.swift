import CoreBluetooth

struct CatPrinterDiscovedDevice {
    let peripheral: CBPeripheral
}

class CatPrinterScanner: NSObject {
    static let shared = CatPrinterScanner()
    @Published var discoveredDevices: [CatPrinterDiscovedDevice] = []
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

extension CatPrinterScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            central.scanForPeripherals(withServices: catPrinterServices, options: nil)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi _: NSNumber
    ) {
        discoveredDevices.append(.init(peripheral: peripheral))
    }
}
