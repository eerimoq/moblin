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
    let speedFormatter = MeasurementFormatter()
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
        speedFormatter.numberFormatter.maximumFractionDigits = 0
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
            case .altitude:
                formatAltitude(stats: stats)
            case .distance:
                formatDistance(stats: stats)
            case .splitDistance:
                formatSplitDistance(stats: stats)
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
            case .workoutDistance:
                formatWorkoutDistance(stats: stats)
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
            case let .runningPace(deviceName, _):
                formatRunningPace(stats: stats, deviceName: deviceName)
            case let .runningCadence(deviceName):
                formatRunningCadence(stats: stats, deviceName: deviceName)
            case let .runningDistance(deviceName, _):
                formatRunningDistance(stats: stats, deviceName: deviceName)
            case .lapTimes:
                formatLapTimes()
            case .browserTitle:
                formatBrowserTitle(stats: stats)
            case .gForce:
                formatGForce(stats: stats)
            case .gForceRecentMax:
                formatGForceRecentMax(stats: stats)
            case .gForceMax:
                formatGForceMax(stats: stats)
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

    private func formatSpeed(stats: TextEffectStats, unit: TextFormatSpeedUnit) {
        appendTextPart(value: formatSpeed(speed: stats.speed, unit: unit))
    }

    private func formatAverageSpeed(stats: TextEffectStats, unit: TextFormatSpeedUnit) {
        appendTextPart(value: formatSpeed(speed: stats.averageSpeed, unit: unit))
    }

    private func formatAltitude(stats: TextEffectStats) {
        appendTextPart(value: stats.altitude)
    }

    private func formatDistance(stats: TextEffectStats) {
        appendTextPart(value: stats.distance)
    }

    private func formatSplitDistance(stats: TextEffectStats) {
        appendTextPart(value: stats.splitDistance)
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

    private func formatTemperature(stats: TextEffectStats, unit: TextFormatTemperatureUnit) {
        appendTextPart(value: formatTemperature(temperature: stats.temperature, unit: unit))
    }

    private func formatFeelsLikeTemperature(stats: TextEffectStats, unit: TextFormatTemperatureUnit) {
        appendTextPart(value: formatTemperature(temperature: stats.feelsLikeTemperature, unit: unit))
    }

    private func formatWind(stats: TextEffectStats, unit: TextFormatSpeedUnit) {
        if let windSpeed = stats.windSpeed {
            if let windGust = stats.windGust {
                appendTextPart(value: formatWindAndGustSpeed(speed: windSpeed,
                                                             gust: windGust,
                                                             unit: unit.toSystem()))
            } else {
                appendTextPart(value: formatWindSpeed(speed: windSpeed, unit: unit.toSystem()))
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

    private func formatWorkoutDistance(stats: TextEffectStats) {
        appendTextPart(value: formatOptional(value: stats.workoutDistance))
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

    private func formatRunningPace(stats: TextEffectStats, deviceName: String) {
        if let speed = stats.runningMetrics[deviceName]?.speed {
            appendTextPart(value: Moblin.formatPace(speed: speed))
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

    private func formatRunningDistance(stats: TextEffectStats, deviceName: String) {
        if let distance = stats.runningMetrics[deviceName]?.distance {
            appendTextPart(value: Moblin.format(distance: distance))
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

    private func formatGForce(stats: TextEffectStats) {
        appendTextPart(value: formatOptionalOneDecimal(value: stats.gForce?.now))
    }

    private func formatGForceRecentMax(stats: TextEffectStats) {
        appendTextPart(value: formatOptionalOneDecimal(value: stats.gForce?.recentMax))
    }

    private func formatGForceMax(stats: TextEffectStats) {
        appendTextPart(value: formatOptionalOneDecimal(value: stats.gForce?.max))
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

    private func formatSpeed(speed: Double, unit: TextFormatSpeedUnit) -> String {
        var measurement = Measurement(value: max(speed, 0), unit: UnitSpeed.metersPerSecond)
        switch unit {
        case .system:
            speedFormatter.unitOptions = []
        case .metersPerSecond:
            speedFormatter.unitOptions = .providedUnit
        case .kilometersPerHour:
            speedFormatter.unitOptions = .providedUnit
            measurement = measurement.converted(to: .kilometersPerHour)
        case .milesPerHour:
            speedFormatter.unitOptions = .providedUnit
            measurement = measurement.converted(to: .milesPerHour)
        }
        return speedFormatter.string(from: measurement)
    }

    private func formatTemperature(temperature: Measurement<UnitTemperature>?,
                                   unit: TextFormatTemperatureUnit) -> String
    {
        if var temperature {
            switch unit {
            case .system:
                temperatureFormatter.unitOptions = []
            case .kelvin:
                temperatureFormatter.unitOptions = .providedUnit
                temperature = temperature.converted(to: .kelvin)
            case .celsius:
                temperatureFormatter.unitOptions = .providedUnit
                temperature = temperature.converted(to: .celsius)
            case .fahrenheit:
                temperatureFormatter.unitOptions = .providedUnit
                temperature = temperature.converted(to: .fahrenheit)
            }
            return temperatureFormatter.string(from: temperature)
        } else {
            return "-"
        }
    }

    private func appendTextPart(value: String) {
        parts.append(.init(id: partId, data: .text(value)))
    }
}
