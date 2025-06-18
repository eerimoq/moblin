import CoreLocation
import Foundation

class GeographyManager {
    private var task: Task<Void, Error>?
    private var newLocation: CLLocation?
    private var location: CLLocation?
    private var placemark: CLPlacemark?
    private var enabled = true
    private let geocoder = CLGeocoder()

    func start() {
        guard task == nil else {
            return
        }
        task = Task.init { @MainActor in
            var delay = 5
            while true {
                do {
                    try await sleep(seconds: delay)
                    if let newLocation, enabled, (location?.distance(from: newLocation) ?? 1001) > 1000 {
                        logger.debug("geography-manager: Updating geography data")
                        placemark = try await geocoder.reverseGeocodeLocation(newLocation).first
                        self.location = newLocation
                    }
                } catch {}
                if Task.isCancelled {
                    break
                }
                if placemark != nil {
                    delay = 5 * 60
                }
            }
        }
    }

    func setEnabled(value: Bool) {
        enabled = value
    }

    func setLocation(location: CLLocation?) {
        newLocation = location
    }

    func getLatestPlacemark() -> CLPlacemark? {
        return placemark
    }

    func stop() {
        task?.cancel()
        task = nil
        location = nil
        placemark = nil
    }
}
