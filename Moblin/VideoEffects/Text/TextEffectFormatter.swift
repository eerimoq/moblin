import Foundation

private func createDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}

private func createFullDateFormatter() -> DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter
}

let textEffectDateFormatter = createDateFormatter()
let textEffectFullDateFormatter = createFullDateFormatter()
let textEffectTimeFormat: Date.FormatStyle = .dateTime.hour().minute().second()
let textEffectShortTimeFormat: Date.FormatStyle = .dateTime.hour().minute()

enum TextEffectPartData: Equatable {
    case text(String)
    case imageSystemName(String)
    case imageSystemNameTryFill(String)
    case rating(Int)
}

struct TextEffectPart: Equatable, Identifiable {
    var id: Int
    var data: TextEffectPartData
}

struct TextEffectLine: Equatable, Identifiable {
    var id: Int
    var parts: [TextEffectPart]
}

class TextEffectFormatter {
    var formatParts: [TextFormatPart]
    var timersEndTime: [ContinuousClock.Instant]
    var stopwatches: [SettingsWidgetTextStopwatch]
    var temperatureFormatter = MeasurementFormatter()
    var checkboxes: [Bool]
    var ratings: [Int]
    var subtitles: [String?: Subtitles] = [:]
    var lapTimes: [[Double]]
    var timerIndex = 0
    var stopwatchIndex = 0
    var checkboxIndex = 0
    var ratingIndex = 0
    var lapTimesIndex = 0
    var lines: [TextEffectLine] = []
    var parts: [TextEffectPart] = []
    var lineId = 0
    var partId = 0

    init(formatParts: [TextFormatPart],
         timersEndTime: [ContinuousClock.Instant],
         stopwatches: [SettingsWidgetTextStopwatch],
         checkboxes: [Bool],
         ratings: [Int],
         lapTimes: [[Double]])
    {
        self.formatParts = formatParts
        self.timersEndTime = timersEndTime
        self.stopwatches = stopwatches
        self.checkboxes = checkboxes
        self.ratings = ratings
        self.lapTimes = lapTimes
        temperatureFormatter.numberFormatter.maximumFractionDigits = 0
    }

    func format(stats: TextEffectStats, now: ContinuousClock.Instant) -> [TextEffectLine] {
        timerIndex = 0
        stopwatchIndex = 0
        checkboxIndex = 0
        ratingIndex = 0
        lapTimesIndex = 0
        lines = []
        parts = []
        lineId = 0
        partId = 0
        for formatPart in formatParts {
            switch formatPart {
            case let .text(text):
                formatText(text: text)
            case .newLine:
                formatNewLine()
            case .clock:
                formatClock(stats: stats)
            case .shortClock:
                formatShortClock(stats: stats)
            case .date:
                formatDate(stats: stats)
            case .fullDate:
                formatFullDate(stats: stats)
            case .bitrate:
                formatBitrate(stats: stats)
            case .bitrateAndTotal:
                formatBitrateAndTotal(stats: stats)
            case .resolution:
                formatResolution(stats: stats)
            case .fps:
                formatFps(stats: stats)
            case .debugOverlay:
                formatDebugOverlay(stats: stats)
            case let .speed(unit):
                formatSpeed(stats: stats, unit: unit)
            case let .averageSpeed(unit):
                formatAverageSpeed(stats: stats, unit: unit)
            case let .altitude(unit):
                formatAltitude(stats: stats, unit: unit)
            case let .distance(unit):
                formatDistance(stats: stats, unit: unit)
            case let .splitDistance(unit):
                formatSplitDistance(stats: stats, unit: unit)
            case .slope:
                formatSlope(stats: stats)
            case .timer:
                formatTimer(stats: stats, now: now)
            case .stopwatch:
                formatStopwatch(stats: stats, now: now)
            case .conditions:
                formatConditions(stats: stats)
            case let .temperature(unit):
                formatTemperature(stats: stats, unit: unit)
            case let .feelsLikeTemperature(unit):
                formatFeelsLikeTemperature(stats: stats, unit: unit)
            case let .wind(unit):
                formatWind(stats: stats, unit: unit)
            case .windKmh:
                formatWindKmh(stats: stats)
            case .country:
                formatCountry(stats: stats)
            case .countryFlag:
                formatCountryFlag(stats: stats)
            case .state:
                formatState(stats: stats)
            case .city:
                formatCity(stats: stats)
            case .checkbox:
                formatCheckbox()
            case .rating:
                formatRating()
            case let .subtitles(identifier):
                formatSubtitles(identifier: identifier)
            case .muted:
                formatMuted(stats: stats)
            case let .heartRate(deviceName):
                formatHeartRate(stats: stats, deviceName: deviceName)
            case .activeEnergyBurned:
                formatActiveEnergyBurned(stats: stats)
            case .power:
                formatPower(stats: stats)
            case .stepCount:
                formatStepCount(stats: stats)
            case let .workoutDistance(unit):
                formatWorkoutDistance(stats: stats, unit: unit)
            case .teslaBatteryLevel:
                formatTeslaBatteryLevel(stats: stats)
            case .teslaDrive:
                formatTeslaDrive(stats: stats)
            case .teslaMedia:
                formatTeslaMedia(stats: stats)
            case .cyclingPower:
                formatCyclingPower(stats: stats)
            case .cyclingCadence:
                formatCyclingCadence(stats: stats)
            case let .runningPace(deviceName, unit):
                formatRunningPace(stats: stats, deviceName: deviceName, unit: unit)
            case let .runningCadence(deviceName):
                formatRunningCadence(stats: stats, deviceName: deviceName)
            case let .runningDistance(deviceName, unit):
                formatRunningDistance(stats: stats, deviceName: deviceName, unit: unit)
            case .lapTimes:
                formatLapTimes()
            case .browserTitle:
                formatBrowserTitle(stats: stats)
            case let .gForce(unit):
                formatGForce(stats: stats, unit: unit)
            case let .gForceRecentMax(unit):
                formatGForceRecentMax(stats: stats, unit: unit)
            case let .gForceMax(unit):
                formatGForceMax(stats: stats, unit: unit)
            case .latestSubscriber:
                formatLatestSubscriber(stats: stats)
            case .latestFollower:
                formatLatestFollower(stats: stats)
            }
            partId += 1
        }
        if !parts.isEmpty {
            lines.append(.init(id: lineId, parts: parts))
        }
        return lines
    }

    private func formatText(text: String) {
        appendTextPart(value: text)
    }

    private func formatNewLine() {
        lines.append(.init(id: lineId, parts: parts))
        lineId += 1
        parts = []
    }

    private func formatClock(stats: TextEffectStats) {
        appendTextPart(value: stats.date.formatted(textEffectTimeFormat))
    }

    private func formatShortClock(stats: TextEffectStats) {
        appendTextPart(value: stats.date.formatted(textEffectShortTimeFormat))
    }

    private func formatDate(stats: TextEffectStats) {
        appendTextPart(value: textEffectDateFormatter.string(from: stats.date))
    }

    private func formatFullDate(stats: TextEffectStats) {
        appendTextPart(value: textEffectFullDateFormatter.string(from: stats.date))
    }

    private func formatBitrate(stats: TextEffectStats) {
        let bitrate = stats.bitrate.isEmpty ? "-" : stats.bitrate
        appendTextPart(value: "\(bitrate) Mbps")
    }

    private func formatBitrateAndTotal(stats: TextEffectStats) {
        appendTextPart(value: stats.bitrateAndTotal)
    }

    private func formatResolution(stats: TextEffectStats) {
        appendTextPart(value: stats.resolution ?? "")
    }

    private func formatFps(stats: TextEffectStats) {
        if let fps = stats.fps {
            appendTextPart(value: String(fps))
        } else {
            appendTextPart(value: "")
        }
    }

    private func formatDebugOverlay(stats: TextEffectStats) {
        appendTextPart(value: stats.debugOverlayLines.joined(separator: "\n"))
    }

    private func formatSpeed(stats: TextEffectStats, unit: String?) {
        if let speed = stats.speed {
            appendTextPart(value: Moblin.formatSpeed(speed: speed, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatAverageSpeed(stats: TextEffectStats, unit: String?) {
        if let averageSpeed = stats.averageSpeed {
            appendTextPart(value: Moblin.formatSpeed(speed: averageSpeed, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatAltitude(stats: TextEffectStats, unit: String?) {
        if let altitude = stats.altitude {
            appendTextPart(value: Moblin.formatAltitude(altitude: altitude, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatDistance(stats: TextEffectStats, unit: String?) {
        if let distance = stats.distance {
            appendTextPart(value: Moblin.formatDistance(meters: distance, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatSplitDistance(stats: TextEffectStats, unit: String?) {
        if let splitDistance = stats.splitDistance {
            appendTextPart(value: Moblin.formatDistance(meters: splitDistance, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatSlope(stats: TextEffectStats) {
        appendTextPart(value: stats.slope)
    }

    private func formatTimer(stats _: TextEffectStats, now: ContinuousClock.Instant) {
        if timerIndex < timersEndTime.count {
            let timeLeft = max(now.duration(to: timersEndTime[timerIndex]).seconds, 0)
            appendTextPart(value: uptimeFormatter.string(from: Double(timeLeft)) ?? "")
        }
        timerIndex += 1
    }

    private func formatStopwatch(stats _: TextEffectStats, now: ContinuousClock.Instant) {
        if stopwatchIndex < stopwatches.count {
            let stopwatch = stopwatches[stopwatchIndex]
            var elapsed = stopwatch.totalElapsed
            if stopwatch.running {
                elapsed += stopwatch.playPressedTime.duration(to: now).seconds
            }
            appendTextPart(value: uptimeFormatter.string(from: elapsed) ?? "")
        }
        stopwatchIndex += 1
    }

    private func formatConditions(stats: TextEffectStats) {
        if let conditions = stats.conditions {
            parts.append(.init(id: partId, data: .imageSystemNameTryFill(conditions)))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatTemperature(stats: TextEffectStats, unit: String?) {
        if let temperature = stats.temperature {
            appendTextPart(value: Moblin.formatTemperature(measurement: temperature, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatFeelsLikeTemperature(stats: TextEffectStats, unit: String?) {
        if let temperature = stats.feelsLikeTemperature {
            appendTextPart(value: Moblin.formatTemperature(measurement: temperature, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatWind(stats: TextEffectStats, unit: String?) {
        if let windSpeed = stats.windSpeed {
            appendTextPart(value: Moblin.formatWind(speed: windSpeed, gust: stats.windGust, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatWindKmh(stats: TextEffectStats) {
        if let windSpeed = stats.windSpeed {
            if let windGust = stats.windGust {
                appendTextPart(value: formatWindAndGustSpeedKmh(speed: windSpeed, gust: windGust))
            } else {
                appendTextPart(value: formatWindSpeedKmh(speed: windSpeed))
            }
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatCountry(stats: TextEffectStats) {
        appendTextPart(value: stats.country ?? "")
    }

    private func formatCountryFlag(stats: TextEffectStats) {
        appendTextPart(value: stats.countryFlag ?? "-")
    }

    private func formatState(stats: TextEffectStats) {
        appendTextPart(value: stats.state ?? "-")
    }

    private func formatCity(stats: TextEffectStats) {
        appendTextPart(value: stats.city ?? "-")
    }

    private func formatCheckbox() {
        if checkboxIndex < checkboxes.count {
            parts.append(.init(
                id: partId,
                data: .imageSystemName(checkboxes[checkboxIndex] ? "checkmark.square" : "square")
            ))
        }
        checkboxIndex += 1
    }

    private func formatRating() {
        if ratingIndex < ratings.count {
            parts.append(.init(id: partId, data: .rating(ratings[ratingIndex])))
        }
        ratingIndex += 1
    }

    private func formatSubtitles(identifier: String?) {
        guard let subtitles = subtitles[identifier] else {
            return
        }
        for line in subtitles.lines {
            if !parts.isEmpty {
                lines.append(.init(id: lineId, parts: parts))
                lineId += 1
                parts = []
            }
            appendTextPart(value: line)
            partId += 1
        }
        if !parts.isEmpty {
            lines.append(.init(id: lineId, parts: parts))
            lineId += 1
            parts = []
        }
    }

    private func formatMuted(stats: TextEffectStats) {
        if stats.muted {
            parts.append(.init(id: partId, data: .imageSystemName("mic.slash")))
        }
    }

    private func formatHeartRate(stats: TextEffectStats, deviceName: String) {
        appendTextPart(value: formatOptional(value: stats.heartRates[deviceName] ?? nil))
    }

    private func formatActiveEnergyBurned(stats: TextEffectStats) {
        appendTextPart(value: formatOptional(value: stats.activeEnergyBurned))
    }

    private func formatPower(stats: TextEffectStats) {
        appendTextPart(value: formatOptional(value: stats.power))
    }

    private func formatStepCount(stats: TextEffectStats) {
        appendTextPart(value: formatOptional(value: stats.stepCount))
    }

    private func formatWorkoutDistance(stats: TextEffectStats, unit: String?) {
        if let workoutDistance = stats.workoutDistance {
            appendTextPart(value: Moblin.formatDistance(meters: Double(workoutDistance), unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatTeslaBatteryLevel(stats: TextEffectStats) {
        appendTextPart(value: stats.teslaBatteryLevel)
    }

    private func formatTeslaDrive(stats: TextEffectStats) {
        appendTextPart(value: stats.teslaDrive)
    }

    private func formatTeslaMedia(stats: TextEffectStats) {
        appendTextPart(value: stats.teslaMedia)
    }

    private func formatCyclingPower(stats: TextEffectStats) {
        appendTextPart(value: stats.cyclingPower)
    }

    private func formatCyclingCadence(stats: TextEffectStats) {
        appendTextPart(value: stats.cyclingCadence)
    }

    private func formatRunningPace(stats: TextEffectStats, deviceName: String, unit: String?) {
        if let speed = stats.runningMetrics[deviceName]?.speed {
            appendTextPart(value: Moblin.formatRunningPace(speed: speed, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatRunningCadence(stats: TextEffectStats, deviceName: String) {
        if let cadence = stats.runningMetrics[deviceName]?.cadence {
            appendTextPart(value: String(cadence))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatRunningDistance(stats: TextEffectStats, deviceName: String, unit: String?) {
        if let distance = stats.runningMetrics[deviceName]?.distance {
            appendTextPart(value: Moblin.formatDistance(meters: distance, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatLapTimes() {
        if lapTimesIndex < lapTimes.count {
            var lap = 1
            for time in lapTimes[lapTimesIndex] {
                if !parts.isEmpty {
                    lines.append(.init(id: lineId, parts: parts))
                    lineId += 1
                    parts = []
                }
                let text: String
                if time.isInfinite {
                    text = "🏁 Finished 🏁"
                    lap = 1
                } else {
                    let time = ContinuousClock.Duration(
                        secondsComponent: Int64(time),
                        attosecondsComponent: 0
                    )
                    text = "Lap \(lap) \(time.formatWithSeconds())"
                    lap += 1
                }
                appendTextPart(value: text)
                partId += 1
            }
            if !parts.isEmpty {
                lines.append(.init(id: lineId, parts: parts))
                lineId += 1
                parts = []
            }
        }
        lapTimesIndex += 1
    }

    private func formatBrowserTitle(stats: TextEffectStats) {
        appendTextPart(value: stats.browserTitle)
    }

    private func formatGForce(stats: TextEffectStats, unit: String?) {
        if let gForce = stats.gForce?.now {
            appendTextPart(value: Moblin.formatGForce(value: gForce, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatGForceRecentMax(stats: TextEffectStats, unit: String?) {
        if let gForce = stats.gForce?.recentMax {
            appendTextPart(value: Moblin.formatGForce(value: gForce, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatGForceMax(stats: TextEffectStats, unit: String?) {
        if let gForce = stats.gForce?.max {
            appendTextPart(value: Moblin.formatGForce(value: gForce, unit: unit))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatLatestSubscriber(stats: TextEffectStats) {
        appendTextPart(value: stats.latestSubscriber)
    }

    private func formatLatestFollower(stats: TextEffectStats) {
        appendTextPart(value: stats.latestFollower)
    }

    private func formatOptional(value: Int?) -> String {
        if let value {
            String(value)
        } else {
            "-"
        }
    }

    private func formatOptionalOneDecimal(value: Double?) -> String {
        if let value {
            formatOneDecimal(Float(value))
        } else {
            "-"
        }
    }

    private func appendTextPart(value: String) {
        parts.append(.init(id: partId, data: .text(value)))
    }
}
