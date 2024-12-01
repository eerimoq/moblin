import Foundation

class TeslaVehicleKeyAdder: NSObject {
    private var vehicle: TeslaVehicle?
    private var privateKeyPem: String?
    private var onCompleted: (() -> Void)?

    func addKey(vin: String, privateKeyPem: String, onCompleted _: @escaping () -> Void) {
        self.privateKeyPem = privateKeyPem
        vehicle = TeslaVehicle(vin: vin, privateKeyPem: privateKeyPem)
        vehicle?.delegate = self
    }
}

extension TeslaVehicleKeyAdder: TeslaVehicleDelegate {
    func teslaVehicleState(_ vehicle: TeslaVehicle, state: TeslaVehicleState) {
        if state == .connected {
            guard let privateKeyPem, let onCompleted else {
                return
            }
            vehicle.addKeyRequestWithRole(privateKeyPem: privateKeyPem)
            onCompleted()
        }
    }
}
