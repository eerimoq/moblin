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
    private var manager = CLLocationManager()
    private var latestLocation: CLLocation?
    private var backgroundActivity = BackgroundActivity()

    func start() {
        logger.debug("location: Start")
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        backgroundActivity.start()
    }

    func stop() {
        logger.debug("location: Stop")
        manager.stopUpdatingLocation()
        backgroundActivity.stop()
    }

    func status() -> String {
        guard let latestLocation else {
            return ""
        }
        return format(speed: latestLocation.speed)
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
        }
    }
}
