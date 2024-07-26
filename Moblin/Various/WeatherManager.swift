import CoreLocation
import Foundation
import WeatherKit

class WeatherManager {
    let weatherService = WeatherService()
    private var task: Task<Void, Error>?
    private var location: CLLocation?
    private var weather: Weather?
    private var enabled = true

    func start() {
        guard task == nil else {
            return
        }
        task = Task.init { @MainActor in
            var delay = 5
            while true {
                do {
                    try await sleep(seconds: delay)
                    if let location, enabled {
                        logger.debug("weather-manager: Updating weather data")
                        weather = try await weatherService.weather(for: location)
                    }
                } catch {}
                if Task.isCancelled {
                    break
                }
                if weather != nil {
                    delay = 10 * 60
                }
            }
        }
    }

    func setEnabled(value: Bool) {
        enabled = value
    }

    func setLocation(location: CLLocation?) {
        self.location = location
    }

    func getLatestWeather() -> Weather? {
        return weather
    }

    func stop() {
        task?.cancel()
        task = nil
        weather = nil
    }
}
