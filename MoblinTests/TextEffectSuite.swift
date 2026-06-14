import AVFoundation
@testable import Moblin
import Testing

@MainActor
struct TextEffectSuite {
    @Test(.enabled(if: Locale.current.identifier == "en_SE"))
    func time() {
        let lines = format(format: "{time}", stats: createStats())
        #expect(lines == createLine(data: .text("06:26:06")))
    }

    @Test(.enabled(if: Locale.current.identifier == "en_SE"))
    func date() {
        let lines = format(format: "{date}", stats: createStats())
        #expect(lines == createLine(data: .text("2024-08-11")))
    }

    @Test
    func conditions() {
        var lines = format(format: "{conditions}", stats: createStats())
        #expect(lines == createLine(data: .text("-")))
        lines = format(format: "{conditions}", stats: createStats(conditions: "sun.max"))
        #expect(lines == createLine(data: .imageSystemNameTryFill("sun.max")))
    }

    @Test
    func gForce() {
        var lines = format(format: "{gForce}", stats: createStats())
        #expect(lines == createLine(data: .text("-")))
        let stats = createStats(gForce: GForce(now: 3, recentMax: 4, max: 5))
        lines = format(format: "{gForce}", stats: stats)
        #expect(lines == createLine(data: .text("3.0")))
    }

    @Test
    func gForceRecentMax() {
        var lines = format(format: "{gForceRecentMax}", stats: createStats())
        #expect(lines == createLine(data: .text("-")))
        let stats = createStats(gForce: GForce(now: 3, recentMax: 4, max: 5))
        lines = format(format: "{gForceRecentMax}", stats: stats)
        #expect(lines == createLine(data: .text("4.0")))
    }

    @Test
    func gForceMax() {
        var lines = format(format: "{gForceMax}", stats: createStats())
        #expect(lines == createLine(data: .text("-")))
        let stats = createStats(gForce: GForce(now: 3, recentMax: 4, max: 5))
        lines = format(format: "{gForceMax}", stats: stats)
        #expect(lines == createLine(data: .text("5.0")))
    }

    @Test
    func heartRate() {
        var lines = format(format: "{heartRate}", stats: createStats())
        #expect(lines == createLine(data: .text("-")))
        var stats = createStats(heartRates: ["": 132])
        lines = format(format: "{heartRate}", stats: stats)
        #expect(lines == createLine(data: .text("132")))
        stats = createStats(heartRates: ["polar": 133])
        lines = format(format: "{heartRate:Polar}", stats: stats)
        #expect(lines == createLine(data: .text("133")))
        stats = createStats(heartRates: ["polar": 134])
        lines = format(format: "{heartRate:polar}", stats: stats)
        #expect(lines == createLine(data: .text("134")))
    }

    @Test
    func speed() {
        var lines = format(format: "{speed:m/s}", stats: createStats())
        #expect(lines == createLine(data: .text("5 m/s")))
        lines = format(format: "{speed:km/h}", stats: createStats())
        #expect(lines == createLine(data: .text("18 km/h")))
        lines = format(format: "{speed:mph}", stats: createStats())
        #expect(lines == createLine(data: .text("11 mph")))
        let systemPart = format(format: "{speed}", stats: createStats())
        lines = format(format: "{speed:mph} {speed} {speed:m/s}", stats: createStats())
        #expect(lines[0].parts[0] == createLine(data: .text("11 mph"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("5 m/s"))[0].parts[0].data)
    }

    @Test
    func averageSpeed() {
        var lines = format(format: "{averageSpeed:m/s}", stats: createStats())
        #expect(lines == createLine(data: .text("7 m/s")))
        lines = format(format: "{averageSpeed:km/h}", stats: createStats())
        #expect(lines == createLine(data: .text("25 km/h")))
        lines = format(format: "{averageSpeed:mph}", stats: createStats())
        #expect(lines == createLine(data: .text("16 mph")))
        let systemPart = format(format: "{averageSpeed}", stats: createStats())
        lines = format(format: "{averageSpeed:mph} {averageSpeed} {averageSpeed:m/s}", stats: createStats())
        #expect(lines[0].parts[0] == createLine(data: .text("16 mph"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("7 m/s"))[0].parts[0].data)
    }

    @Test
    func wind() {
        var lines = format(format: "{wind:m/s}", stats: createStats())
        #expect(lines == createLine(data: .text("3 m/s")))
        lines = format(format: "{wind:km/h}", stats: createStats())
        #expect(lines == createLine(data: .text("11 km/h")))
        lines = format(format: "{wind:mph}", stats: createStats())
        #expect(lines == createLine(data: .text("7 mph")))
        let systemPart = format(format: "{wind}", stats: createStats())
        lines = format(format: "{wind:mph} {wind} {wind:m/s}", stats: createStats())
        #expect(lines[0].parts[0] == createLine(data: .text("7 mph"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("3 m/s"))[0].parts[0].data)
    }

    @Test
    func temperature() {
        var lines = format(format: "{temperature:c}", stats: createStats())
        #expect(lines == createLine(data: .text("22°C")))
        lines = format(format: "{temperature:f}", stats: createStats())
        #expect(lines == createLine(data: .text("72°F")))
        lines = format(format: "{temperature:k}", stats: createStats())
        #expect(lines == createLine(data: .text("295 K")))
        let systemPart = format(format: "{temperature}", stats: createStats())
        lines = format(format: "{temperature:f} {temperature} {temperature:c}", stats: createStats())
        #expect(lines[0].parts[0] == createLine(data: .text("72°F"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("22°C"))[0].parts[0].data)
    }

    @Test
    func feelsLikeTemperature() {
        var lines = format(format: "{feelsLikeTemperature:c}", stats: createStats())
        #expect(lines == createLine(data: .text("17°C")))
        lines = format(format: "{feelsLikeTemperature:f}", stats: createStats())
        #expect(lines == createLine(data: .text("63°F")))
        lines = format(format: "{feelsLikeTemperature:k}", stats: createStats())
        #expect(lines == createLine(data: .text("290 K")))
        let systemPart = format(format: "{feelsLikeTemperature}", stats: createStats())
        lines = format(format: "{feelsLikeTemperature:f} {feelsLikeTemperature} {feelsLikeTemperature:c}",
                       stats: createStats())
        #expect(lines[0].parts[0] == createLine(data: .text("63°F"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("17°C"))[0].parts[0].data)
    }

    @Test
    func altitude() {
        var lines = format(format: "{altitude:m}", stats: createStats())
        #expect(lines == createLine(data: .text("243 m")))
        lines = format(format: "{altitude:ft}", stats: createStats())
        #expect(lines == createLine(data: .text("797 ft")))
        let systemPart = format(format: "{altitude}", stats: createStats())
        lines = format(format: "{altitude:ft} {altitude} {altitude:m}",
                       stats: createStats())
        #expect(lines[0].parts[0] == createLine(data: .text("797 ft"))[0].parts[0])
        #expect(lines[0].parts[2].data == systemPart[0].parts[0].data)
        #expect(lines[0].parts[4].data == createLine(data: .text("243 m"))[0].parts[0].data)
    }

    @Test
    func multiple() {
        let lines = format(format: "time: {time}, date: {date}\nsecond line", stats: createStats())
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
        #expect(parts == [.runningPace("", nil)])
        parts = loader.load(format: "{runningpace:My device}")
        #expect(parts == [.runningPace("my device", nil)])
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
        #expect(parts == [.runningDistance("", nil)])
        parts = loader.load(format: "{runningdistance:My device}")
        #expect(parts == [.runningDistance("my device", nil)])
    }

    @Test
    func loadFormatSubtitles() {
        let loader = TextFormatLoader()
        var parts = loader.load(format: "{subtitles}")
        #expect(parts == [.subtitles(nil)])
        parts = loader.load(format: "{subtitles:dk}")
        #expect(parts == [.subtitles("dk")])
    }

    private func format(format: String, stats: TextEffectStats) -> [TextEffectLine] {
        let formatter = TextEffectFormatter(formatParts: loadTextFormat(format: format),
                                            timersEndTime: [],
                                            stopwatches: [],
                                            checkboxes: [],
                                            ratings: [],
                                            lapTimes: [])
        return formatter.format(stats: stats, now: .now)
    }

    private func createStats(conditions: String? = nil,
                             heartRates: [String: Int?] = [:],
                             gForce: GForce? = nil) -> TextEffectStats
    {
        TextEffectStats(timestamp: .now,
                        bitrate: "",
                        bitrateAndTotal: "",
                        resolution: nil,
                        fps: nil,
                        date: Date(timeIntervalSince1970: 1_723_350_366),
                        debugOverlayLines: [],
                        speed: 5,
                        averageSpeed: 7,
                        altitude: 243,
                        distance: "",
                        splitDistance: "",
                        slope: "",
                        conditions: conditions,
                        temperature: Measurement(value: 22, unit: UnitTemperature.celsius),
                        feelsLikeTemperature: Measurement(value: 17, unit: UnitTemperature.celsius),
                        windSpeed: Measurement(value: 3, unit: UnitSpeed.metersPerSecond),
                        windGust: nil,
                        country: nil,
                        countryFlag: nil,
                        state: nil,
                        city: nil,
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
