import CoreBluetooth

let bluetoothNotAllowedMessage = "⚠️ Moblin is not allowed to use Bluetooth"

extension Model: @MainActor CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_: CBCentralManager) {
        bluetoothAllowed = CBCentralManager.authorization == .allowedAlways
    }
}
