import CoreLocation
import Foundation

class Location: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager = .init()
    private var onUpdate: ((CLLocation) -> Void)?
    private var latestLocation: CLLocation?

    func start(onUpdate: @escaping (CLLocation) -> Void) {
        logger.info("location: Start")
        self.onUpdate = onUpdate
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        manager.desiredAccuracy = 1
        manager.distanceFilter = 10
    }

    func stop() {
        logger.info("location: Stop")
        onUpdate = nil
        manager.stopUpdatingLocation()
    }

    func status() -> String {
        guard let latestLocation else {
            return ""
        }
        let latitude = formatOneDecimal(value: Float(latestLocation.coordinate.latitude))
        let longitude = formatOneDecimal(value: Float(latestLocation.coordinate.longitude))
        var speed: String
        if latestLocation.speed != -1 {
            speed = formatOneDecimal(value: Float(latestLocation.speed))
        } else {
            speed = "-"
        }
        return "\(latitude) N \(longitude) W, \(speed) m/s"
    }

    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        logger.debug("location: Auth did change \(manager.authorizationStatus)")
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        logger.error("location: Error \(error)")
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        logger.debug("location: New location")
        for location in locations {
            latestLocation = location
            onUpdate?(location)
        }
    }
}
