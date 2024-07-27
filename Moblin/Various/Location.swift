import CoreLocation
import Foundation

private class BackgroundActivity {
    private var backgroundSession: Any?

    func start() {
        if #available(iOS 17.0, *) {
            backgroundSession = CLBackgroundActivitySession()
        }
    }

    func stop() {
        if #available(iOS 17.0, *) {
            if let session = backgroundSession as? CLBackgroundActivitySession {
                session.invalidate()
            }
        }
    }
}

class Location: NSObject {
    private var manager: CLLocationManager = .init()
    private var onUpdate: ((CLLocation) -> Void)?
    private var latestLocation: CLLocation?
    private var backgroundActivity = BackgroundActivity()

    func start(onUpdate: @escaping (CLLocation) -> Void) {
        logger.debug("location: Start")
        self.onUpdate = onUpdate
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        backgroundActivity.start()
    }

    func stop() {
        logger.debug("location: Stop")
        onUpdate = nil
        manager.stopUpdatingLocation()
        backgroundActivity.stop()
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

    func getLatestKnownLocation() -> CLLocation? {
        return latestLocation
    }
}

extension Location: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        logger.debug("location: Auth did change \(manager.authorizationStatus)")
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        logger.error("location: Error \(error)")
    }

    func locationManager(_: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            latestLocation = location
            onUpdate?(location)
        }
    }
}
