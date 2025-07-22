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
    private var onUpdate: ((CLLocation) -> Void)?
    private var latestLocation: CLLocation?
    private var backgroundActivity = BackgroundActivity()

    func start(accuracy: SettingsLocationDesiredAccuracy,
               distanceFilter: SettingsLocationDistanceFilter,
               onUpdate: @escaping (CLLocation) -> Void)
    {
        logger.debug("location: Start with accuracy \(accuracy) and distance filter \(distanceFilter)")
        self.onUpdate = onUpdate
        manager.delegate = self
        switch accuracy {
        case .best:
            manager.desiredAccuracy = kCLLocationAccuracyBest
        case .nearestTenMeters:
            manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        case .hundredMeters:
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        }
        switch distanceFilter {
        case .none:
            manager.distanceFilter = kCLDistanceFilterNone
        case .oneMeter:
            manager.distanceFilter = 1
        case .threeMeters:
            manager.distanceFilter = 3
        case .fiveMeters:
            manager.distanceFilter = 5
        case .tenMeters:
            manager.distanceFilter = 10
        case .twentyMeters:
            manager.distanceFilter = 20
        case .fiftyMeters:
            manager.distanceFilter = 50
        case .hundredMeters:
            manager.distanceFilter = 100
        case .twoHundredMeters:
            manager.distanceFilter = 200
        }
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
            onUpdate?(location)
        }
    }
}
