import CoreLocation
import Foundation

class Location: NSObject, CLLocationManagerDelegate {
    private var manager: CLLocationManager = .init()

    func start() {
        manager.delegate = self
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_: CLLocationManager) {
        logger.info("location: did change")
    }

    func locationManager(_: CLLocationManager, didFailWithError error: Error) {
        logger.error("location: \(error)")
    }

    func locationManager(
        _: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        for location in locations {
            logger.info("location: \(location)")
        }
    }
}
