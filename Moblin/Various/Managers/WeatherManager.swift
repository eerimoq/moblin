import CoreLocation
import Foundation
import WeatherKit

struct MyWeatherData {
    let symbolName: String
    let temperature: Measurement<UnitTemperature>
    let apparentTemperature: Measurement<UnitTemperature>
    let windSpeed: Measurement<UnitSpeed>
    let windGust: Measurement<UnitSpeed>?
}

class WeatherManager: @unchecked Sendable {
    let weatherService = WeatherService()
    private var task: Task<Void, any Error>?
    private var location: CLLocation?
    private var weather: MyWeatherData?
    private var enabled = true

    func start() {
        guard task == nil else {
            return
        }
        task = Task { @MainActor in
            var delay = 5
            while true {
                do {
                    try await sleep(seconds: delay)
                    if !enabled {
                        print("DEBUG: weather-manager - disabled")
                    } else if location == nil {
                        print("DEBUG: weather-manager - location is nil")
                    }

                    if let location, enabled {
                        logger.debug("weather-manager: Updating weather data")
                        print(
                            "DEBUG: weather-manager - updating weather data for coordinates: \(location.coordinate.latitude), \(location.coordinate.longitude)"
                        )
                        do {
                            // Try WeatherKit first
                            let kitWeather = try await weatherService.weather(for: location)
                            let current = kitWeather.currentWeather
                            weather = MyWeatherData(
                                symbolName: current.symbolName,
                                temperature: current.temperature,
                                apparentTemperature: current.apparentTemperature,
                                windSpeed: current.wind.speed,
                                windGust: current.wind.gust
                            )
                            logger.info("weather-manager: Successfully updated weather using WeatherKit")
                            print("DEBUG: weather-manager - Successfully updated weather using WeatherKit")
                        } catch {
                            logger
                                .info(
                                    "weather-manager: WeatherKit failed with \(error), trying Open-Meteo fallback"
                                )
                            print(
                                "DEBUG: weather-manager - WeatherKit failed with \(error), trying Open-Meteo fallback"
                            )
                            // Fallback to Open-Meteo
                            if let fallbackWeather = await fetchOpenMeteoWeather(
                                latitude: location.coordinate.latitude,
                                longitude: location.coordinate.longitude
                            ) {
                                weather = fallbackWeather
                                logger.info("weather-manager: Successfully updated weather using Open-Meteo")
                                print(
                                    "DEBUG: weather-manager - Successfully updated weather using Open-Meteo"
                                )
                            }
                        }
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

    func getLatestWeather() -> MyWeatherData? {
        weather
    }

    func stop() {
        task?.cancel()
        task = nil
        location = nil
        weather = nil
    }

    private func fetchOpenMeteoWeather(latitude: Double, longitude: Double) async -> MyWeatherData? {
        let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(latitude)&longitude=\(longitude)&current=temperature_2m,apparent_temperature,wind_speed_10m,wind_gusts_10m,weather_code&wind_speed_unit=ms"
        print("DEBUG: weather-manager - calling Open-Meteo: \(urlString)")
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)

            struct OpenMeteoResponse: Codable {
                struct Current: Codable {
                    let temperature_2m: Double
                    let apparent_temperature: Double
                    let wind_speed_10m: Double
                    let wind_gusts_10m: Double
                    let weather_code: Int
                }

                let current: Current
            }

            let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let current = response.current

            let symbolName = switch current.weather_code {
            case 0:
                "sunny"
            case 1, 2, 3:
                "cloudy"
            case 45, 48:
                "fog"
            case 51, 53, 55:
                "drizzle"
            case 61, 63, 65:
                "rain"
            case 71, 73, 75:
                "snow"
            case 80, 81, 82:
                "heavyrain"
            case 95:
                "thunderstorm"
            default:
                "sunny"
            }

            print(
                "DEBUG: weather-manager - Open-Meteo success! Wind: \(current.wind_speed_10m) m/s, Temp: \(current.temperature_2m) C"
            )
            return MyWeatherData(
                symbolName: symbolName,
                temperature: Measurement(value: current.temperature_2m, unit: .celsius),
                apparentTemperature: Measurement(value: current.apparent_temperature, unit: .celsius),
                windSpeed: Measurement(value: current.wind_speed_10m, unit: .metersPerSecond),
                windGust: Measurement(value: current.wind_gusts_10m, unit: .metersPerSecond)
            )
        } catch {
            print("DEBUG: weather-manager - Open-Meteo failed with error: \(error)")
            return nil
        }
    }
}
