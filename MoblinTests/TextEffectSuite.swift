import AVFoundation
@testable import Moblin
import Testing
import WeatherKit

@MainActor
struct TextEffectSuite {
    @Test(.enabled(if: Locale.current.identifier == "en_SE"))
    func time() {
        let lines = format(format: "{time}", variables: createVariables())
        #expect(lines == createLine(data: .text("06:26:06")))
    }

    @Test(.enabled(if: Locale.current.identifier == "en_SE"))
    func date() {
        let lines = format(format: "{date}", variables: createVariables())
        #expect(lines == createLine(data: .text("2024-08-11")))
    }

    @Test
    func conditions() {
        var lines = format(format: "{conditions}", variables: createVariables())
        #expect(lines == createLine(data: .text("-")))
        lines = format(format: "{conditions}",
                       variables: createVariables(conditions: "sun.max", condition: .clear))
        #expect(lines == createLine(data: .imageSystemNameTryFill("sun.max", plainText: "☀️")))
    }

    @Test
    func gForce() {
        var lines = format(format: "{gForce}", variables: createVariables())
        #expect(lines == createLine(data: .text("-")))
        let variables = createVariables(gForce: GForce(now: 3, recentMax: 4, max: 5))
        lines = format(format: "{gForce}", variables: variables)
        #expect(lines == createLine(data: .text("3.0")))
    }

    @Test
    func gForceRecentMax() {
        var lines = format(format: "{gForceRecentMax}", variables: createVariables())
        #expect(lines == createLine(data: .text("-")))
        let variables = createVariables(gForce: GForce(now: 3, recentMax: 4, max: 5))
        lines = format(format: "{gForceRecentMax}", variables: variables)
        #expect(lines == createLine(data: .text("4.0")))
    }

    @Test
    func gForceMax() {
        var lines = format(format: "{gForceMax}", variables: createVariables())
        #expect(lines == createLine(data: .text("-")))
        let variables = createVariables(gForce: GForce(now: 3, recentMax: 4, max: 5))
        lines = format(format: "{gForceMax}", variables: variables)
        #expect(lines == createLine(data: .text("5.0")))
    }

    @Test
    func heartRate() {
        var lines = format(format: "{heartRate}", variables: createVariables())
        #expect(lines == createLine(data: .text("-")))
        var variables = createVariables(heartRates: ["": 132])
        lines = format(format: "{heartRate}", variables: variables)
        #expect(lines == createLine(data: .text("132")))
        variables = createVariables(heartRates: ["polar": 133])
        lines = format(format: "{heartRate:Polar}", variables: variables)
        #expect(lines == createLine(data: .text("133")))
        variables = createVariables(heartRates: ["polar": 134])
        lines = format(format: "{heartRate:polar}", variables: variables)
        #expect(lines == createLine(data: .text("134")))
    }

    @Test
    func speed() {
        var lines = format(format: "{speed:m/s}", variables: createVariables())
        #expect(lines == createLine(data: .text("5 m/s")))
        lines = format(format: "{speed:km/h}", variables: createVariables())
        #expect(lines == createLine(data: .text("18 km/h")))
        lines = format(format: "{speed:mph}", variables: createVariables())
        #expect(lines == createLine(data: .text("11 mph")))
        let systemPart = format(format: "{speed}", variables: createVariables())
        lines = format(format: "{speed:mph} {speed} {speed:m/s}", variables: createVariables())
        #expect(lines[0].parts[0] == createLine(data: .text("11 mph"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("5 m/s"))[0].parts[0].data)
    }

    @Test
    func averageSpeed() {
        var lines = format(format: "{averageSpeed:m/s}", variables: createVariables())
        #expect(lines == createLine(data: .text("7 m/s")))
        lines = format(format: "{averageSpeed:km/h}", variables: createVariables())
        #expect(lines == createLine(data: .text("25 km/h")))
        lines = format(format: "{averageSpeed:mph}", variables: createVariables())
        #expect(lines == createLine(data: .text("16 mph")))
        let systemPart = format(format: "{averageSpeed}", variables: createVariables())
        lines = format(
            format: "{averageSpeed:mph} {averageSpeed} {averageSpeed:m/s}",
            variables: createVariables()
        )
        #expect(lines[0].parts[0] == createLine(data: .text("16 mph"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("7 m/s"))[0].parts[0].data)
    }

    @Test
    func wind() {
        var lines = format(format: "{wind:m/s}", variables: createVariables())
        #expect(lines == createLine(data: .text("3 m/s")))
        lines = format(format: "{wind:km/h}", variables: createVariables())
        #expect(lines == createLine(data: .text("11 km/h")))
        lines = format(format: "{wind:mph}", variables: createVariables())
        #expect(lines == createLine(data: .text("7 mph")))
        let systemPart = format(format: "{wind}", variables: createVariables())
        lines = format(format: "{wind:mph} {wind} {wind:m/s}", variables: createVariables())
        #expect(lines[0].parts[0] == createLine(data: .text("7 mph"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("3 m/s"))[0].parts[0].data)
    }

    @Test
    func temperature() {
        var lines = format(format: "{temperature:c}", variables: createVariables())
        #expect(lines == createLine(data: .text("22°C")))
        lines = format(format: "{temperature:f}", variables: createVariables())
        #expect(lines == createLine(data: .text("72°F")))
        lines = format(format: "{temperature:k}", variables: createVariables())
        #expect(lines == createLine(data: .text("295 K")))
        let systemPart = format(format: "{temperature}", variables: createVariables())
        lines = format(format: "{temperature:f} {temperature} {temperature:c}", variables: createVariables())
        #expect(lines[0].parts[0] == createLine(data: .text("72°F"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("22°C"))[0].parts[0].data)
    }

    @Test
    func feelsLikeTemperature() {
        var lines = format(format: "{feelsLikeTemperature:c}", variables: createVariables())
        #expect(lines == createLine(data: .text("17°C")))
        lines = format(format: "{feelsLikeTemperature:f}", variables: createVariables())
        #expect(lines == createLine(data: .text("63°F")))
        lines = format(format: "{feelsLikeTemperature:k}", variables: createVariables())
        #expect(lines == createLine(data: .text("290 K")))
        let systemPart = format(format: "{feelsLikeTemperature}", variables: createVariables())
        lines = format(format: "{feelsLikeTemperature:f} {feelsLikeTemperature} {feelsLikeTemperature:c}",
                       variables: createVariables())
        #expect(lines[0].parts[0] == createLine(data: .text("63°F"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("17°C"))[0].parts[0].data)
    }

    @Test
    func altitude() {
        var lines = format(format: "{altitude:m}", variables: createVariables())
        #expect(lines == createLine(data: .text("243 m")))
        lines = format(format: "{altitude:ft}", variables: createVariables())
        #expect(lines == createLine(data: .text("797 ft")))
        let systemPart = format(format: "{altitude}", variables: createVariables())
        lines = format(format: "{altitude:ft} {altitude} {altitude:m}",
                       variables: createVariables())
        #expect(lines[0].parts[0] == createLine(data: .text("797 ft"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("243 m"))[0].parts[0].data)
    }

    @Test
    func distance() {
        var lines = format(format: "{distance:m}", variables: createVariables())
        #expect(lines == createLine(data: .text("1 700 m")))
        lines = format(format: "{distance:km}", variables: createVariables())
        #expect(lines == createLine(data: .text("2 km")))
        lines = format(format: "{distance:yd}", variables: createVariables())
        #expect(lines == createLine(data: .text("1 859 yd")))
        lines = format(format: "{distance:ft}", variables: createVariables())
        #expect(lines == createLine(data: .text("5 577 ft")))
        lines = format(format: "{distance:mi}", variables: createVariables())
        #expect(lines == createLine(data: .text("1 mi")))
        lines = format(format: "{distance:nmi}", variables: createVariables())
        #expect(lines == createLine(data: .text("1 nmi")))
        lines = format(format: "{distance:ly}", variables: createVariables())
        #expect(lines == createLine(data: .text("0 ly")))
        let systemPart = format(format: "{distance}", variables: createVariables())
        lines = format(format: "{distance:mi} {distance} {distance:m}", variables: createVariables())
        #expect(lines[0].parts[0] == createLine(data: .text("1 mi"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("1 700 m"))[0].parts[0].data)
    }

    @Test
    func splitDistance() {
        var lines = format(format: "{splitDistance:m}", variables: createVariables())
        #expect(lines == createLine(data: .text("5 400 m")))
        lines = format(format: "{splitDistance:km}", variables: createVariables())
        #expect(lines == createLine(data: .text("5 km")))
        lines = format(format: "{splitDistance:yd}", variables: createVariables())
        #expect(lines == createLine(data: .text("5 906 yd")))
        lines = format(format: "{splitDistance:ft}", variables: createVariables())
        #expect(lines == createLine(data: .text("17 717 ft")))
        lines = format(format: "{splitDistance:mi}", variables: createVariables())
        #expect(lines == createLine(data: .text("3 mi")))
        lines = format(format: "{splitDistance:nmi}", variables: createVariables())
        #expect(lines == createLine(data: .text("3 nmi")))
        lines = format(format: "{splitDistance:ly}", variables: createVariables())
        #expect(lines == createLine(data: .text("0 ly")))
        let systemPart = format(format: "{splitDistance}", variables: createVariables())
        lines = format(
            format: "{splitDistance:mi} {splitDistance} {splitDistance:m}",
            variables: createVariables()
        )
        #expect(lines[0].parts[0] == createLine(data: .text("3 mi"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("5 400 m"))[0].parts[0].data)
    }

    @Test
    func multiple() {
        let lines = format(format: "time: {time}, date: {date}\nsecond line", variables: createVariables())
        #expect(lines == [
            TextEffectLine(id: 0, parts: [
                .init(id: 0, data: .text("time: ")),
                .init(id: 1, data: .text("06:26:06")),
                .init(id: 2, data: .text(", date: ")),
                .init(id: 3, data: .text("2024-08-11")),
            ]),
            TextEffectLine(id: 1, parts: [
                .init(id: 5, data: .text("second line")),
            ]),
        ])
    }

    @Test
    func loadFormatSpeed() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{speed}")
        #expect(parts == [.speed(.system)])
        parts = loader.load(format: "{speed:m/s}")
        #expect(parts == [.speed(.metersPerSecond)])
        parts = loader.load(format: "{speed:km/h}")
        #expect(parts == [.speed(.kilometersPerHour)])
        parts = loader.load(format: "{speed:mph}")
        #expect(parts == [.speed(.milesPerHour)])
        parts = loader.load(format: "{speed:foo}")
        #expect(parts == [.text("{speed:foo}")])
    }

    @Test
    func loadFormatAverageSpeed() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{averagespeed}")
        #expect(parts == [.averageSpeed(.system)])
        parts = loader.load(format: "{averagespeed:m/s}")
        #expect(parts == [.averageSpeed(.metersPerSecond)])
        parts = loader.load(format: "{averagespeed:km/h}")
        #expect(parts == [.averageSpeed(.kilometersPerHour)])
        parts = loader.load(format: "{averagespeed:mph}")
        #expect(parts == [.averageSpeed(.milesPerHour)])
        parts = loader.load(format: "{averagespeed:foo}")
        #expect(parts == [.text("{averagespeed:foo}")])
    }

    @Test
    func loadFormatHeartrate() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{heartrate}")
        #expect(parts == [.heartRate("")])
        parts = loader.load(format: "{heartrate:My device}")
        #expect(parts == [.heartRate("my device")])
    }

    @Test
    func loadFormatRunningPace() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{runningpace}")
        #expect(parts == [.runningPace("")])
        parts = loader.load(format: "{runningpace:My device}")
        #expect(parts == [.runningPace("my device")])
    }

    @Test
    func loadFormatRunningCadence() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{runningcadence}")
        #expect(parts == [.runningCadence("")])
        parts = loader.load(format: "{runningcadence:My device}")
        #expect(parts == [.runningCadence("my device")])
    }

    @Test
    func loadFormatRunningDistance() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{runningdistance}")
        #expect(parts == [.runningDistance("")])
        parts = loader.load(format: "{runningdistance:My device}")
        #expect(parts == [.runningDistance("my device")])
    }

    @Test
    func loadFormatSubtitles() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{subtitles}")
        #expect(parts == [.subtitles(nil)])
        parts = loader.load(format: "{subtitles:dk}")
        #expect(parts == [.subtitles("dk")])
    }

    @Test
    func plainText() {
        var lines = format(format: "Speed {speed:km/h}\\nGravity {gForce}", variables: createVariables())
        #expect(lines.toPlainText() == "Speed 18 km/h Gravity -")
        lines = format(format: "{conditions} {speed:m/s}",
                       variables: createVariables(conditions: "sun.max", condition: .clear))
        #expect(lines.toPlainText() == "☀️ 5 m/s")
        lines = format(format: "Speed {speed:m/s} {conditions} today",
                       variables: createVariables(conditions: "cloud.rain", condition: .rain))
        #expect(lines.toPlainText() == "Speed 5 m/s 🌧️ today")
    }

    private func format(format: String, variables: Variables) -> [TextEffectLine] {
        let formatter = TextEffectFormatter(formatParts: loadTextFormat(format: format),
                                            timersEndTime: [],
                                            stopwatches: [],
                                            checkboxes: [],
                                            ratings: [],
                                            lapTimes: [])
        return formatter.format(variables: variables, now: .now)
    }

    private func createVariables(conditions: String? = nil,
                                 condition: WeatherCondition? = nil,
                                 heartRates: [String: Int?] = [:],
                                 gForce: GForce? = nil) -> Variables
    {
        Variables(timestamp: .now,
                  bitrate: "",
                  bitrateAndTotal: "",
                  bonding: "",
                  resolution: nil,
                  fps: nil,
                  date: Date(timeIntervalSince1970: 1_723_350_366),
                  debugOverlayLines: [],
                  speed: 5,
                  averageSpeed: 7,
                  altitude: 243,
                  distance: 1700,
                  splitDistance: 5400,
                  altitudeAscent: 120,
                  altitudeDescent: 80,
                  splitAltitudeAscent: 40,
                  splitAltitudeDescent: 30,
                  slope: "",
                  conditions: conditions,
                  condition: condition,
                  temperature: Measurement(value: 22, unit: UnitTemperature.celsius),
                  feelsLikeTemperature: Measurement(value: 17, unit: UnitTemperature.celsius),
                  windSpeed: Measurement(value: 3, unit: UnitSpeed.metersPerSecond),
                  windGust: nil,
                  country: nil,
                  countryFlag: nil,
                  state: nil,
                  area: nil,
                  city: nil,
                  neighborhood: nil,
                  muted: false,
                  heartRates: heartRates,
                  activeEnergyBurned: nil,
                  workoutDistance: nil,
                  power: nil,
                  stepCount: nil,
                  teslaBatteryLevel: "",
                  teslaDrive: "",
                  teslaMedia: "",
                  cyclingPower: "",
                  cyclingCadence: "",
                  runningMetrics: [:],
                  browserTitle: "",
                  gForce: gForce,
                  latestSubscriber: "",
                  latestFollower: "")
    }

    private func createLine(data: TextEffectPartData) -> [TextEffectLine] {
        [TextEffectLine(id: 0, parts: [.init(id: 0, data: data)])]
    }
}
