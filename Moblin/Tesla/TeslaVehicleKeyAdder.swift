import Foundation

class TeslaVehicleKeyAdder: NSObject {
    private var vehicle: TeslaVehicle?
    private var privateKeyPem: String?
    private var onCompleted: ((Bool) -> Void)?
    private let timer = SimpleTimer(queue: .main)

    func start(vin: String, privateKeyPem: String, onCompleted: @escaping (Bool) -> Void) {
        self.privateKeyPem = privateKeyPem
        self.onCompleted = onCompleted
        stop()
        vehicle = TeslaVehicle(vin: vin, privateKeyPem: privateKeyPem, handshake: false)
        vehicle?.delegate = self
        vehicle?.start()
        timer.startSingleShot(timeout: 10.0) { [weak self] in
            self?.onCompleted?(false)
        }
    }

    func stop() {
        timer.stop()
        vehicle?.stop()
    }
}

extension TeslaVehicleKeyAdder: TeslaVehicleDelegate {
    func teslaVehicleState(_ vehicle: TeslaVehicle, state: TeslaVehicleState) {
        guard let privateKeyPem, let onCompleted else {
            return
        }
        if state == .connected {
            vehicle.addKeyRequestWithRole(privateKeyPem: privateKeyPem)
            timer.stop()
            onCompleted(true)
        }
    }
}
