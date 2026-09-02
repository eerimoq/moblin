import Foundation
import WeatherKit

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
    case imageSystemName(String, plainText: String)
    case imageSystemNameTryFill(String, plainText: String)
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

private func conditionToEmoji(_ condition: WeatherCondition?) -> String {
    switch condition {
    case .clear:
        "☀️"
    case .mostlyClear:
        "🌤️"
    case .partlyCloudy:
        "⛅"
    case .mostlyCloudy:
        "🌥️"
    case .cloudy:
        "☁️"
    case .foggy, .haze, .smoky, .blowingDust:
        "🌫️"
    case .breezy, .windy:
        "💨"
    case .drizzle, .sunShowers:
        "🌦️"
    case .rain, .heavyRain, .freezingRain, .freezingDrizzle:
        "🌧️"
    case .isolatedThunderstorms, .scatteredThunderstorms:
        "🌩️"
    case .thunderstorms, .strongStorms:
        "⛈️"
    case .flurries, .snow, .sunFlurries, .blowingSnow, .blizzard, .sleet, .wintryMix, .hail:
        "🌨️"
    case .heavySnow:
        "❄️"
    case .frigid:
        "🥶"
    case .hot:
        "🥵"
    case .hurricane, .tropicalStorm:
        "🌀"
    default:
        ""
    }
}

class TextEffectFormatter {
    var formatParts: [TextFormatPart]
    var timersEndTime: [ContinuousClock.Instant]
    var stopwatches: [SettingsWidgetTextStopwatch]
    var temperatureFormatter = MeasurementFormatter()
    let speedFormatter = MeasurementFormatter()
    let altitudeFormatter = MeasurementFormatter()
    let lengthFormatter = MeasurementFormatter()
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
        altitudeFormatter.unitOptions = .providedUnit
        altitudeFormatter.numberFormatter.maximumFractionDigits = 0
        lengthFormatter.unitOptions = .providedUnit
        lengthFormatter.numberFormatter.maximumFractionDigits = 0
    }

    func format(variables: Variables, now: ContinuousClock.Instant) -> [TextEffectLine] {
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
                formatClock(variables: variables)
            case .shortClock:
                formatShortClock(variables: variables)
            case .date:
                formatDate(variables: variables)
            case .fullDate:
                formatFullDate(variables: variables)
            case .bitrate:
                formatBitrate(variables: variables)
            case .bitrateAndTotal:
                formatBitrateAndTotal(variables: variables)
            case .bonding:
                formatBonding(variables: variables)
            case .resolution:
                formatResolution(variables: variables)
            case .fps:
                formatFps(variables: variables)
            case .debugOverlay:
                formatDebugOverlay(variables: variables)
            case let .speed(unit):
                formatSpeed(variables: variables, unit: unit)
            case let .averageSpeed(unit):
                formatAverageSpeed(variables: variables, unit: unit)
            case let .altitude(unit):
                formatAltitude(variables: variables, unit: unit)
            case let .distance(unit):
                formatDistance(variables: variables, unit: unit)
            case let .splitDistance(unit):
                formatSplitDistance(variables: variables, unit: unit)
            case let .altitudeAscent(unit):
                formatAltitudeAscent(variables: variables, unit: unit)
            case let .altitudeDescent(unit):
                formatAltitudeDescent(variables: variables, unit: unit)
            case let .splitAltitudeAscent(unit):
                formatSplitAltitudeAscent(variables: variables, unit: unit)
            case let .splitAltitudeDescent(unit):
                formatSplitAltitudeDescent(variables: variables, unit: unit)
            case .slope:
                formatSlope(variables: variables)
            case .timer:
                formatTimer(variables: variables, now: now)
            case .stopwatch:
                formatStopwatch(variables: variables, now: now)
            case .conditions:
                formatConditions(variables: variables)
            case let .temperature(unit):
                formatTemperature(variables: variables, unit: unit)
            case let .feelsLikeTemperature(unit):
                formatFeelsLikeTemperature(variables: variables, unit: unit)
            case let .wind(unit):
                formatWind(variables: variables, unit: unit)
            case .country:
                formatCountry(variables: variables)
            case .countryFlag:
                formatCountryFlag(variables: variables)
            case .state:
                formatState(variables: variables)
            case .area:
                formatArea(variables: variables)
            case .city:
                formatCity(variables: variables)
            case .neighborhood:
                formatNeighborhood(variables: variables)
            case .checkbox:
                formatCheckbox()
            case .rating:
                formatRating()
            case let .subtitles(identifier):
                formatSubtitles(identifier: identifier)
            case .muted:
                formatMuted(variables: variables)
            case let .heartRate(deviceName):
                formatHeartRate(variables: variables, deviceName: deviceName)
            case .activeEnergyBurned:
                formatActiveEnergyBurned(variables: variables)
            case .power:
                formatPower(variables: variables)
            case .stepCount:
                formatStepCount(variables: variables)
            case .workoutDistance:
                formatWorkoutDistance(variables: variables)
            case .teslaBatteryLevel:
                formatTeslaBatteryLevel(variables: variables)
            case .teslaDrive:
                formatTeslaDrive(variables: variables)
            case .teslaMedia:
                formatTeslaMedia(variables: variables)
            case .cyclingPower:
                formatCyclingPower(variables: variables)
            case .cyclingCadence:
                formatCyclingCadence(variables: variables)
            case let .runningPace(deviceName):
                formatRunningPace(variables: variables, deviceName: deviceName)
            case let .runningCadence(deviceName):
                formatRunningCadence(variables: variables, deviceName: deviceName)
            case let .runningDistance(deviceName):
                formatRunningDistance(variables: variables, deviceName: deviceName)
            case .lapTimes:
                formatLapTimes()
            case .browserTitle:
                formatBrowserTitle(variables: variables)
            case .gForce:
                formatGForce(variables: variables)
            case .gForceRecentMax:
                formatGForceRecentMax(variables: variables)
            case .gForceMax:
                formatGForceMax(variables: variables)
            case .latestSubscriber:
                formatLatestSubscriber(variables: variables)
            case .latestFollower:
                formatLatestFollower(variables: variables)
            case .systemMonitor:
                formatSystemMonitor(variables: variables)
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

    private func formatClock(variables: Variables) {
        appendTextPart(value: variables.date.formatted(textEffectTimeFormat))
    }

    private func formatShortClock(variables: Variables) {
        appendTextPart(value: variables.date.formatted(textEffectShortTimeFormat))
    }

    private func formatDate(variables: Variables) {
        appendTextPart(value: textEffectDateFormatter.string(from: variables.date))
    }

    private func formatFullDate(variables: Variables) {
        appendTextPart(value: textEffectFullDateFormatter.string(from: variables.date))
    }

    private func formatBitrate(variables: Variables) {
        let bitrate = variables.bitrate.isEmpty ? "-" : variables.bitrate
        appendTextPart(value: "\(bitrate) Mbps")
    }

    private func formatBitrateAndTotal(variables: Variables) {
        appendTextPart(value: variables.bitrateAndTotal)
    }

    private func formatBonding(variables: Variables) {
        appendTextPart(value: variables.bonding)
    }

    private func formatResolution(variables: Variables) {
        appendTextPart(value: variables.resolution ?? "")
    }

    private func formatFps(variables: Variables) {
        if let fps = variables.fps {
            appendTextPart(value: String(fps))
        } else {
            appendTextPart(value: "")
        }
    }

    private func formatDebugOverlay(variables: Variables) {
        appendTextPart(value: variables.debugOverlayLines.joined(separator: "\n"))
    }

    private func formatSpeed(variables: Variables, unit: TextFormatSpeedUnit) {
        appendTextPart(value: formatSpeed(speed: variables.speed, unit: unit))
    }

    private func formatAverageSpeed(variables: Variables, unit: TextFormatSpeedUnit) {
        appendTextPart(value: formatSpeed(speed: variables.averageSpeed, unit: unit))
    }

    private func formatAltitude(variables: Variables, unit: TextFormatLengthUnit) {
        formatAltitude(altitude: variables.altitude, unit: unit)
    }

    private func formatAltitudeAscent(variables: Variables, unit: TextFormatLengthUnit) {
        formatAltitude(altitude: variables.altitudeAscent, unit: unit)
    }

    private func formatAltitudeDescent(variables: Variables, unit: TextFormatLengthUnit) {
        formatAltitude(altitude: variables.altitudeDescent, unit: unit)
    }

    private func formatSplitAltitudeAscent(variables: Variables, unit: TextFormatLengthUnit) {
        formatAltitude(altitude: variables.splitAltitudeAscent, unit: unit)
    }

    private func formatSplitAltitudeDescent(variables: Variables, unit: TextFormatLengthUnit) {
        formatAltitude(altitude: variables.splitAltitudeDescent, unit: unit)
    }

    private func formatAltitude(altitude: Double, unit: TextFormatLengthUnit) {
        var measurement = Measurement(value: altitude, unit: UnitLength.meters)
        switch unit {
        case .system:
            if UnitLength(forLocale: .current) == .feet {
                measurement = measurement.converted(to: .feet)
            }
        case .meters:
            break
        case .kilometers:
            measurement = measurement.converted(to: .kilometers)
        case .feet:
            measurement = measurement.converted(to: .feet)
        case .yards:
            measurement = measurement.converted(to: .yards)
        case .miles:
            measurement = measurement.converted(to: .miles)
        case .nauticalMiles:
            measurement = measurement.converted(to: .nauticalMiles)
        case .lightYears:
            measurement = measurement.converted(to: .lightyears)
        }
        appendTextPart(value: altitudeFormatter.string(from: measurement))
    }

    private func formatDistance(variables: Variables, unit: TextFormatLengthUnit) {
        formatDistance(distance: variables.distance, unit: unit)
    }

    private func formatSplitDistance(variables: Variables, unit: TextFormatLengthUnit) {
        formatDistance(distance: variables.splitDistance, unit: unit)
    }

    private func formatSlope(variables: Variables) {
        appendTextPart(value: variables.slope)
    }

    private func formatTimer(variables _: Variables, now: ContinuousClock.Instant) {
        if timerIndex < timersEndTime.count {
            let timeLeft = max(now.duration(to: timersEndTime[timerIndex]).seconds, 0)
            appendTextPart(value: uptimeFormatter.string(from: Double(timeLeft)) ?? "")
        }
        timerIndex += 1
    }

    private func formatStopwatch(variables _: Variables, now: ContinuousClock.Instant) {
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

    private func formatConditions(variables: Variables) {
        if let conditions = variables.conditions {
            parts.append(.init(id: partId,
                               data: .imageSystemNameTryFill(conditions,
                                                             plainText: conditionToEmoji(variables
                                                                 .condition))))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatTemperature(variables: Variables, unit: TextFormatTemperatureUnit) {
        appendTextPart(value: formatTemperature(temperature: variables.temperature, unit: unit))
    }

    private func formatFeelsLikeTemperature(variables: Variables, unit: TextFormatTemperatureUnit) {
        appendTextPart(value: formatTemperature(temperature: variables.feelsLikeTemperature, unit: unit))
    }

    private func formatWind(variables: Variables, unit: TextFormatSpeedUnit) {
        if let windSpeed = variables.windSpeed {
            if let windGust = variables.windGust {
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

    private func formatCountry(variables: Variables) {
        appendTextPart(value: variables.country ?? "")
    }

    private func formatCountryFlag(variables: Variables) {
        appendTextPart(value: variables.countryFlag ?? "-")
    }

    private func formatState(variables: Variables) {
        appendTextPart(value: variables.state ?? "-")
    }

    private func formatArea(variables: Variables) {
        appendTextPart(value: variables.area ?? "-")
    }

    private func formatCity(variables: Variables) {
        appendTextPart(value: variables.city ?? "-")
    }

    private func formatNeighborhood(variables: Variables) {
        appendTextPart(value: variables.neighborhood ?? "-")
    }

    private func formatCheckbox() {
        if checkboxIndex < checkboxes.count {
            let checked = checkboxes[checkboxIndex]
            parts.append(.init(
                id: partId,
                data: .imageSystemName(checked ? "checkmark.square" : "square",
                                       plainText: checked ? "☑️" : "⬜")
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

    private func formatMuted(variables: Variables) {
        if variables.muted {
            parts.append(.init(id: partId, data: .imageSystemName("mic.slash", plainText: "🔇")))
        }
    }

    private func formatHeartRate(variables: Variables, deviceName: String) {
        appendTextPart(value: formatOptional(value: variables.heartRates[deviceName] ?? nil))
    }

    private func formatActiveEnergyBurned(variables: Variables) {
        appendTextPart(value: formatOptional(value: variables.activeEnergyBurned))
    }

    private func formatPower(variables: Variables) {
        appendTextPart(value: formatOptional(value: variables.power))
    }

    private func formatStepCount(variables: Variables) {
        appendTextPart(value: formatOptional(value: variables.stepCount))
    }

    private func formatWorkoutDistance(variables: Variables) {
        appendTextPart(value: formatOptional(value: variables.workoutDistance))
    }

    private func formatTeslaBatteryLevel(variables: Variables) {
        appendTextPart(value: variables.teslaBatteryLevel)
    }

    private func formatTeslaDrive(variables: Variables) {
        appendTextPart(value: variables.teslaDrive)
    }

    private func formatTeslaMedia(variables: Variables) {
        appendTextPart(value: variables.teslaMedia)
    }

    private func formatCyclingPower(variables: Variables) {
        appendTextPart(value: variables.cyclingPower)
    }

    private func formatCyclingCadence(variables: Variables) {
        appendTextPart(value: variables.cyclingCadence)
    }

    private func formatRunningPace(variables: Variables, deviceName: String) {
        if let speed = variables.runningMetrics[deviceName]?.speed {
            appendTextPart(value: Moblin.formatPace(speed: speed))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatRunningCadence(variables: Variables, deviceName: String) {
        if let cadence = variables.runningMetrics[deviceName]?.cadence {
            appendTextPart(value: String(cadence))
        } else {
            appendTextPart(value: "-")
        }
    }

    private func formatRunningDistance(variables: Variables, deviceName: String) {
        if let distance = variables.runningMetrics[deviceName]?.distance {
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

    private func formatBrowserTitle(variables: Variables) {
        appendTextPart(value: variables.browserTitle)
    }

    private func formatGForce(variables: Variables) {
        appendTextPart(value: formatOptionalOneDecimal(value: variables.gForce?.now))
    }

    private func formatGForceRecentMax(variables: Variables) {
        appendTextPart(value: formatOptionalOneDecimal(value: variables.gForce?.recentMax))
    }

    private func formatGForceMax(variables: Variables) {
        appendTextPart(value: formatOptionalOneDecimal(value: variables.gForce?.max))
    }

    private func formatLatestSubscriber(variables: Variables) {
        appendTextPart(value: variables.latestSubscriber)
    }

    private func formatLatestFollower(variables: Variables) {
        appendTextPart(value: variables.latestFollower)
    }

    private func formatSystemMonitor(variables: Variables) {
        appendTextPart(value: variables.systemMonitor)
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

    private func formatDistance(distance: Double, unit: TextFormatLengthUnit) {
        var measurement = Measurement(value: distance, unit: UnitLength.meters)
        switch unit {
        case .system:
            appendTextPart(value: Moblin.format(distance: distance))
            return
        case .meters:
            break
        case .kilometers:
            measurement = measurement.converted(to: .kilometers)
        case .feet:
            measurement = measurement.converted(to: .feet)
        case .yards:
            measurement = measurement.converted(to: .yards)
        case .miles:
            measurement = measurement.converted(to: .miles)
        case .nauticalMiles:
            measurement = measurement.converted(to: .nauticalMiles)
        case .lightYears:
            measurement = measurement.converted(to: .lightyears)
        }
        appendTextPart(value: lengthFormatter.string(from: measurement))
    }

    private func appendTextPart(value: String) {
        parts.append(.init(id: partId, data: .text(value)))
    }
}

extension [TextEffectLine] {
    func toPlainText() -> String {
        map { line in
            line.parts.map { part in
                switch part.data {
                case let .text(text):
                    text
                case let .imageSystemName(_, plainText), let .imageSystemNameTryFill(_, plainText):
                    plainText
                case let .rating(rating):
                    String(repeating: "⭐", count: rating)
                }
            }
            .joined()
        }
        .joined(separator: " ")
    }
}
