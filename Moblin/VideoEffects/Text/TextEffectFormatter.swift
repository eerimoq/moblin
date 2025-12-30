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
            case .speed:
                formatSpeed(stats: stats)
            case .averageSpeed:
                formatAverageSpeed(stats: stats)
            case .altitude:
                formatAltitude(stats: stats)
            case .distance:
                formatDistance(stats: stats)
            case .slope:
                formatSlope(stats: stats)
            case .timer:
                formatTimer(stats: stats, now: now)
            case .stopwatch:
                formatStopwatch(stats: stats, now: now)
            case .conditions:
                formatConditions(stats: stats)
            case .temperature:
                formatTemperature(stats: stats)
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
            }
            partId += 1
        }
        if !parts.isEmpty {
            lines.append(.init(id: lineId, parts: parts))
        }
        return lines
    }

    private func formatText(text: String) {
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatNewLine() {
        lines.append(.init(id: lineId, parts: parts))
        lineId += 1
        parts = []
    }

    private func formatClock(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(stats.date.formatted(textEffectTimeFormat))
        ))
    }

    private func formatShortClock(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(stats.date.formatted(textEffectShortTimeFormat))
        ))
    }

    private func formatDate(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(textEffectDateFormatter.string(from: stats.date))
        ))
    }

    private func formatFullDate(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(textEffectFullDateFormatter.string(from: stats.date))
        ))
    }

    private func formatBitrate(stats: TextEffectStats) {
        let bitrate = stats.bitrate.isEmpty ? "-" : stats.bitrate
        parts.append(.init(id: partId, data: .text("\(bitrate) Mbps")))
    }

    private func formatBitrateAndTotal(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.bitrateAndTotal)))
    }

    private func formatResolution(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.resolution ?? "")))
    }

    private func formatFps(stats: TextEffectStats) {
        if let fps = stats.fps {
            parts.append(.init(id: partId, data: .text(String(fps))))
        } else {
            parts.append(.init(id: partId, data: .text("")))
        }
    }

    private func formatDebugOverlay(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(stats.debugOverlayLines.joined(separator: "\n"))
        ))
    }

    private func formatSpeed(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.speed)))
    }

    private func formatAverageSpeed(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.averageSpeed)))
    }

    private func formatAltitude(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.altitude)))
    }

    private func formatDistance(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.distance)))
    }

    private func formatSlope(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.slope)))
    }

    private func formatTimer(stats _: TextEffectStats, now: ContinuousClock.Instant) {
        if timerIndex < timersEndTime.count {
            let timeLeft = max(now.duration(to: timersEndTime[timerIndex]).seconds, 0)
            parts.append(.init(
                id: partId,
                data: .text(uptimeFormatter.string(from: Double(timeLeft)) ?? "")
            ))
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
            parts.append(.init(
                id: partId,
                data: .text(uptimeFormatter.string(from: elapsed) ?? "")
            ))
        }
        stopwatchIndex += 1
    }

    private func formatConditions(stats: TextEffectStats) {
        if let conditions = stats.conditions {
            parts.append(.init(id: partId, data: .imageSystemNameTryFill(conditions)))
        } else {
            parts.append(.init(id: partId, data: .text("-")))
        }
    }

    private func formatTemperature(stats: TextEffectStats) {
        if let temperature = stats.temperature {
            parts.append(.init(
                id: partId,
                data: .text(temperatureFormatter.string(from: temperature))
            ))
        } else {
            parts.append(.init(id: partId, data: .text("-")))
        }
    }

    private func formatCountry(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.country ?? "")))
    }

    private func formatCountryFlag(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.countryFlag ?? "-")))
    }

    private func formatState(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.state ?? "-")))
    }

    private func formatCity(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.city ?? "-")))
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
            parts.append(.init(id: partId, data: .text(line)))
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
        let text: String
        if let heartRate = stats.heartRates[deviceName], let heartRate {
            text = String(heartRate)
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatActiveEnergyBurned(stats: TextEffectStats) {
        let text: String
        if let activeEnergyBurned = stats.activeEnergyBurned {
            text = String(activeEnergyBurned)
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatPower(stats: TextEffectStats) {
        let text: String
        if let power = stats.power {
            text = String(power)
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatStepCount(stats: TextEffectStats) {
        let text: String
        if let stepCount = stats.stepCount {
            text = String(stepCount)
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatWorkoutDistance(stats: TextEffectStats) {
        let text: String
        if let workoutDistance = stats.workoutDistance {
            text = String(workoutDistance)
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatTeslaBatteryLevel(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.teslaBatteryLevel)))
    }

    private func formatTeslaDrive(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.teslaDrive)))
    }

    private func formatTeslaMedia(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.teslaMedia)))
    }

    private func formatCyclingPower(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.cyclingPower)))
    }

    private func formatCyclingCadence(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.cyclingCadence)))
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
                parts.append(.init(id: partId, data: .text(text)))
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
        parts.append(.init(id: partId, data: .text(stats.browserTitle)))
    }

    private func formatGForce(stats: TextEffectStats) {
        let text: String
        if let now = stats.gForce?.now {
            text = formatOneDecimal(Float(now))
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatGForceRecentMax(stats: TextEffectStats) {
        let text: String
        if let peak = stats.gForce?.recentMax {
            text = formatOneDecimal(Float(peak))
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }

    private func formatGForceMax(stats: TextEffectStats) {
        let text: String
        if let max = stats.gForce?.max {
            text = formatOneDecimal(Float(max))
        } else {
            text = "-"
        }
        parts.append(.init(id: partId, data: .text(text)))
    }
}
