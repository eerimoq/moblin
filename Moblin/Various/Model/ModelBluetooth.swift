import CoreBluetooth

let bluetoothNotAllowedMessage = "⚠️ Moblin is not allowed to use Bluetooth"

extension Model: @preconcurrency CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_: CBCentralManager) {
        bluetoothAllowed = CBCentralManager.authorization == .allowedAlways
    }
}
