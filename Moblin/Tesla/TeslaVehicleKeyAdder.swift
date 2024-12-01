import Foundation

class TeslaVehicleKeyAdder: NSObject {
    private var vehicle: TeslaVehicle?
    private var privateKeyPem: String?
    private var onCompleted: ((Bool) -> Void)?

    func start(vin: String, privateKeyPem: String, onCompleted _: @escaping (Bool) -> Void) {
        self.privateKeyPem = privateKeyPem
        vehicle = TeslaVehicle(vin: vin, privateKeyPem: privateKeyPem)
        vehicle?.delegate = self
    }

    func stop() {
        vehicle?.stop()
    }
}

extension TeslaVehicleKeyAdder: TeslaVehicleDelegate {
    func teslaVehicleState(_ vehicle: TeslaVehicle, state: TeslaVehicleState) {
        guard let privateKeyPem, let onCompleted else {
            return
        }
        switch state {
        case .idle:
            onCompleted(false)
        case .connected:
            vehicle.addKeyRequestWithRole(privateKeyPem: privateKeyPem)
            onCompleted(true)
        default:
            break
        }
    }
}
