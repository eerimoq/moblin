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
    func loadFormatCyclingSpeed() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{cyclingspeed}")
        #expect(parts == [.cyclingSpeed(.system)])
        parts = loader.load(format: "{cyclingspeed:device:T1}")
        #expect(parts == [.cyclingSpeedDevice("t1")])
        #expect(loader.load(format: "{cyclingSpeed:km/h}") == [.cyclingSpeed(.kilometersPerHour)])
        #expect(loader.load(format: "{cyclingSpeed:mph}") == [.cyclingSpeed(.milesPerHour)])
        #expect(loader.load(format: "{cyclingSpeed:m/s}") == [.cyclingSpeed(.metersPerSecond)])
    }

    @Test
    func loadFormatCyclingDistance() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{cyclingdistance}")
        #expect(parts == [.cyclingDistance(.system)])
        parts = loader.load(format: "{cyclingdistance:device:C1}")
        #expect(parts == [.cyclingDistanceDevice("c1")])
        #expect(loader.load(format: "{cyclingDistance:km}") == [.cyclingDistance(.kilometers)])
        #expect(loader.load(format: "{cyclingDistance:mi}") == [.cyclingDistance(.miles)])
    }

    @Test(arguments: ["m/s", "km/h", "mph", "km", "mi", "m", "ft", "yd", "nmi", "ly", "My bike"])
    func explicitCyclingPrefixSelectsDevice(name: String) {
        let loader = TextFormatLoader()
        #expect(loader
            .load(format: "{cyclingSpeed:device:\(name)}") == [.cyclingSpeedDevice(name.lowercased())])
        #expect(loader
            .load(format: "{cyclingDistance:device:\(name)}") == [.cyclingDistanceDevice(name.lowercased())])
    }

    @Test
    func gpsSpeedUnitOverridesRemainAvailable() {
        let loader = TextFormatLoader()
        #expect(loader.load(format: "{speed:km/h}") == [.speed(.kilometersPerHour)])
        #expect(loader.load(format: "{speed:mph}") == [.speed(.milesPerHour)])
        #expect(loader.load(format: "{speed:m/s}") == [.speed(.metersPerSecond)])
    }

    @Test(arguments: ["m/s", "km/h", "mph", "km", "mi", "m", "ft", "yd", "nmi", "ly", "My bike"])
    func namedCyclingMetricsUseSystemUnits(name: String) {
        let variables = createVariables(cyclingSpeed: 5, cyclingDistance: 1500, cyclingMetrics: [
            name.lowercased(): .init(speed: 5, distance: 1500),
        ])
        let genericSpeed = format(format: "{cyclingSpeed}", variables: variables).toPlainText()
        let genericDistance = format(format: "{cyclingDistance}", variables: variables).toPlainText()
        #expect(genericSpeed == format(format: "{speed}", variables: variables).toPlainText())
        #expect(genericDistance == Moblin.format(distance: 1500))
        #expect(format(format: "{cyclingSpeed:device:\(name)}", variables: variables)
            .toPlainText() == genericSpeed)
        #expect(format(format: "{cyclingDistance:device:\(name)}", variables: variables).toPlainText()
            == genericDistance)
        let missing = createVariables(cyclingSpeed: 10, cyclingDistance: 1500)
        #expect(format(format: "{cyclingSpeed:device:\(name)}", variables: missing).toPlainText() == "-")
        #expect(format(format: "{cyclingDistance:device:\(name)}", variables: missing).toPlainText() == "-")
    }

    @Test
    func formatsIndependentCyclingDevices() {
        let variables = createVariables(cyclingMetrics: [
            "t1": .init(speed: 3, distance: 1000),
            "c1": .init(speed: 10, distance: 5000),
        ])
        let t1Speed = format(format: "{cyclingSpeed:device:t1}", variables: variables).toPlainText()
        let c1Speed = format(format: "{cyclingSpeed:device:C1}", variables: variables).toPlainText()
        let t1Distance = format(format: "{cyclingDistance:device:t1}", variables: variables).toPlainText()
        let c1Distance = format(format: "{cyclingDistance:device:C1}", variables: variables).toPlainText()
        #expect(t1Speed != "-")
        #expect(t1Speed != c1Speed)
        #expect(t1Distance != "-")
        #expect(t1Distance != c1Distance)
        #expect(format(format: "{cyclingSpeed:device:missing}", variables: variables).toPlainText() == "-")
    }

    @Test(arguments: ["en_US", "sv_SE"])
    func cyclingSpeedUsesLocaleUnits(localeIdentifier: String) {
        let variables = createVariables(cyclingSpeed: 5, cyclingMetrics: ["km/h": .init(speed: 5)])
        let formatter = TextEffectFormatter(
            formatParts: loadTextFormat(format: "{cyclingSpeed} / {cyclingSpeed:device:km/h}"),
            timersEndTime: [], stopwatches: [], checkboxes: [], ratings: [], lapTimes: []
        )
        formatter.speedFormatter.locale = Locale(identifier: localeIdentifier)
        formatter.speedFormatter.numberFormatter.maximumFractionDigits = 0
        let reference = MeasurementFormatter()
        reference.locale = Locale(identifier: localeIdentifier)
        reference.numberFormatter.maximumFractionDigits = 0
        reference.unitOptions = []
        let expected = reference.string(from: Measurement(value: 5, unit: UnitSpeed.metersPerSecond))
        #expect(formatter.format(variables: variables, now: .now)
            .toPlainText() == "\(expected) / \(expected)")
    }

    @Test(arguments: ["km/h", "mph", "m/s"])
    func cyclingUnitOverridesDoNotSelectDevices(unit: String) {
        let variables = createVariables(cyclingSpeed: 5, cyclingMetrics: [unit: .init(speed: 15)])
        let generic = format(format: "{cyclingSpeed:\(unit)}", variables: variables).toPlainText()
        #expect(generic == format(format: "{speed:\(unit)}", variables: variables).toPlainText())
        let named = format(format: "{cyclingSpeed:device:\(unit)}", variables: variables).toPlainText()
        #expect(generic != named)
        let combined = format(
            format: "{cyclingSpeed:\(unit)}|{cyclingSpeed:device:\(unit)}|{cyclingSpeed:\(unit)}",
            variables: variables
        ).toPlainText()
        #expect(combined == "\(generic)|\(named)|\(generic)")
    }

    @Test(arguments: ["{cyclingSpeed:device:}", "{cyclingDistance:device:}", "{cyclingSpeed:T1}"])
    func invalidCyclingOptionsRemainText(value: String) {
        #expect(TextFormatLoader().load(format: value) == [.text(value)])
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
    func systemMonitor() {
        var lines = format(format: "{systemMonitor}", variables: createVariables(systemMonitor: "-% - MB"))
        #expect(lines == createLine(data: .text("-% - MB")))
        lines = format(format: "{systemMonitor}", variables: createVariables(systemMonitor: "12% 300 MB"))
        #expect(lines == createLine(data: .text("12% 300 MB")))
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
                                 cyclingSpeed: Double = 0,
                                 cyclingDistance: Double = 0,
                                 cyclingMetrics: [String: WorkoutDeviceCyclingMetrics] = [:],
                                 gForce: GForce? = nil,
                                 systemMonitor: String = "") -> Variables
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
                  cyclingSpeed: cyclingSpeed,
                  cyclingDistance: cyclingDistance,
                  cyclingMetrics: cyclingMetrics,
                  runningMetrics: [:],
                  browserTitle: "",
                  gForce: gForce,
                  latestSubscriber: "",
                  latestFollower: "",
                  systemMonitor: systemMonitor)
    }

    private func createLine(data: TextEffectPartData) -> [TextEffectLine] {
        [TextEffectLine(id: 0, parts: [.init(id: 0, data: data)])]
    }
}
