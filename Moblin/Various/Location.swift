import CoreLocation
import Foundation

class Location: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager = .init()
    private var onUpdate: ((CLLocation) -> Void)?

    func start(onUpdate: @escaping (CLLocation) -> Void) {
        logger.info("location: Start")
        self.onUpdate = onUpdate
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.desiredAccuracy = 1
    }

    func stop() {
        logger.info("location: Stop")
        onUpdate = nil
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        logger.info("location: Auth did change \(manager.authorizationStatus)")
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        logger.error("location: Error \(error)")
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            onUpdate?(location)
        }
    }
}
