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
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 1
        let speed = formatter.string(from: NSMeasurement(
            doubleValue: max(latestLocation.speed, 0),
            unit: UnitSpeed.metersPerSecond
        ) as Measurement<Unit>)
        return "\(latitude) N \(longitude) W, \(speed)"
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
