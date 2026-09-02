import Foundation
import WeatherKit

struct Variables {
    let timestamp: ContinuousClock.Instant
    let bitrate: String
    let bitrateAndTotal: String
    let bonding: String
    let resolution: String?
    let fps: Int?
    let date: Date
    let debugOverlayLines: [String]
    let speed: Double
    let averageSpeed: Double
    let altitude: Double
    let distance: Double
    let splitDistance: Double
    let altitudeAscent: Double
    let altitudeDescent: Double
    let splitAltitudeAscent: Double
    let splitAltitudeDescent: Double
    let slope: String
    let conditions: String?
    let condition: WeatherCondition?
    let temperature: Measurement<UnitTemperature>?
    let feelsLikeTemperature: Measurement<UnitTemperature>?
    let windSpeed: Measurement<UnitSpeed>?
    let windGust: Measurement<UnitSpeed>?
    let country: String?
    let countryFlag: String?
    let state: String?
    let area: String?
    let city: String?
    let neighborhood: String?
    let muted: Bool
    let heartRates: [String: Int?]
    let activeEnergyBurned: Int?
    let workoutDistance: Int?
    let power: Int?
    let stepCount: Int?
    let teslaBatteryLevel: String
    let teslaDrive: String
    let teslaMedia: String
    let cyclingPower: String
    let cyclingCadence: String
    let runningMetrics: [String: WorkoutDeviceRunningMetrics]
    let browserTitle: String
    let gForce: GForce?
    let latestSubscriber: String
    let latestFollower: String
    let systemMonitor: String
}
