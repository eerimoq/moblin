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

    private func appendPeripheral(_ peripheral: CBPeripheral) {
        guard !discoveredPeripherals.contains(where: { $0.identifier == peripheral.identifier }) else {
            return
        }
        discoveredPeripherals.append(peripheral)
    }
}

extension BluetoothScanner: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            if !serviceIds.isEmpty {
                let connected = central.retrieveConnectedPeripherals(withServices: serviceIds)
                for peripheral in connected {
                    appendPeripheral(peripheral)
                }
            }
            let scanServices: [CBUUID]? = serviceIds.isEmpty ? nil : serviceIds
            central.scanForPeripherals(withServices: scanServices)
        }
    }

    func centralManager(
        _: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData _: [String: Any],
        rssi _: NSNumber
    ) {
        appendPeripheral(peripheral)
    }
}
