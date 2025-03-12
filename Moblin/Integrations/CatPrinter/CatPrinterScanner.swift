import CoreBluetooth

struct CatPrinterDiscovedDevice {
    let peripheral: CBPeripheral
}

class CatPrinterScanner: NSObject, ObservableObject {
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
        guard !discoveredDevices.contains(where: { $0.peripheral == peripheral }) else {
            return
        }
        discoveredDevices.append(.init(peripheral: peripheral))
    }
}
