import CoreBluetooth

let bluetoothNotAllowedMessage = "⚠️ Moblin is not allowed to use Bluetooth"

extension Model: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_: CBCentralManager) {
        MainActor.assumeIsolated {
            bluetoothAllowed = CBCentralManager.authorization == .allowedAlways
        }
    }
}
