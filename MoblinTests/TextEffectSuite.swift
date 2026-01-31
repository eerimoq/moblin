import AVFoundation
@testable import Moblin
import Testing

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
        return TextEffectStats(timestamp: .now,
                               bitrate: "",
                               bitrateAndTotal: "",
                               resolution: nil,
                               fps: nil,
                               date: Date(timeIntervalSince1970: 1_723_350_366),
                               debugOverlayLines: [],
                               speed: "",
                               averageSpeed: "",
                               altitude: "",
                               distance: "",
                               slope: "",
                               conditions: conditions,
                               temperature: nil,
                               feelsLikeTemperature: nil,
                               windSpeed: nil,
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
                               browserTitle: "",
                               gForce: gForce)
    }

    private func createLine(data: TextEffectPartData) -> [TextEffectLine] {
        return [TextEffectLine(id: 0, parts: [.init(id: 0, data: data)])]
    }
}
