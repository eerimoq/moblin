import AVFoundation
import Collections
import Combine
import SwiftUI
import UIKit
import Vision
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

struct TextEffectStats {
    let timestamp: ContinuousClock.Instant
    let bitrate: String
    let bitrateAndTotal: String
    let resolution: String?
    let fps: Int?
    let date: Date
    let debugOverlayLines: [String]
    let speed: String
    let averageSpeed: String
    let altitude: String
    let distance: String
    let slope: String
    let conditions: String?
    let temperature: Measurement<UnitTemperature>?
    let country: String?
    let countryFlag: String?
    let state: String?
    let city: String?
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
    let browserTitle: String
    let gForce: GForce?
}

private enum PartData: Equatable {
    case text(String)
    case imageSystemName(String)
    case imageSystemNameTryFill(String)
    case rating(Int)
}

private struct Part: Equatable, Identifiable {
    var id: Int
    var data: PartData
}

private struct Line: Equatable, Identifiable {
    var id: Int
    var parts: [Part]
}

private class Formatter {
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
    var lines: [Line] = []
    var parts: [Part] = []
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

    func format(stats: TextEffectStats, now: ContinuousClock.Instant) -> [Line] {
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

private class TextViewState: ObservableObject {
    @Published var fontSize: CGFloat
    @Published var fontDesign: Font.Design
    @Published var fontWeight: Font.Weight
    @Published var fontMonospacedDigits: Bool
    @Published var horizontalAlignment: HorizontalAlignment
    @Published var minWidth: Double
    @Published var cornerRadius: Double
    @Published var foregroundColor: Color
    @Published var backgroundColor: Color
    @Published var size: CGSize?
    @Published var lines: [Line]

    init(fontSize: CGFloat,
         fontDesign: Font.Design,
         fontWeight: Font.Weight,
         fontMonospacedDigits: Bool,
         horizontalAlignment: HorizontalAlignment,
         minWidth: Double,
         cornerRadius: Double,
         foregroundColor: Color,
         backgroundColor: Color,
         lines: [Line])
    {
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.fontWeight = fontWeight
        self.fontMonospacedDigits = fontMonospacedDigits
        self.horizontalAlignment = horizontalAlignment
        self.minWidth = minWidth
        self.cornerRadius = cornerRadius
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.lines = lines
    }
}

private struct TextView: View {
    @ObservedObject var state: TextViewState

    private func scaledFontSize(size: CGSize) -> CGFloat {
        return state.fontSize * (size.maximum() / 1920)
    }

    var body: some View {
        if let size = state.size {
            let fontSize = scaledFontSize(size: size)
            let stack = VStack(alignment: state.horizontalAlignment, spacing: 2) {
                ForEach(state.lines) { line in
                    HStack(spacing: 0) {
                        if state.horizontalAlignment != .leading, state.minWidth != 0 {
                            Spacer(minLength: 0)
                        }
                        ForEach(line.parts) { part in
                            switch part.data {
                            case let .text(text):
                                Text(text)
                                    .foregroundStyle(state.foregroundColor)
                            case let .imageSystemName(name):
                                Image(systemName: name)
                                    .foregroundStyle(state.foregroundColor)
                            case let .imageSystemNameTryFill(name):
                                if UIImage(systemName: "\(name).fill") != nil {
                                    Image(systemName: "\(name).fill")
                                        .symbolRenderingMode(.multicolor)
                                } else {
                                    Image(systemName: name)
                                        .foregroundStyle(state.foregroundColor)
                                }
                            case let .rating(rating):
                                ForEach(0 ..< 5) { index in
                                    if index < rating {
                                        Text("★")
                                            .foregroundStyle(.yellow)
                                    } else {
                                        Text("☆")
                                            .foregroundStyle(state.foregroundColor)
                                    }
                                }
                            }
                        }
                        if state.horizontalAlignment != .trailing, state.minWidth != 0 {
                            Spacer(minLength: 0)
                        }
                    }
                    .padding(
                        [.leading, .trailing],
                        7 * fontSize / 30 + min(CGFloat(state.cornerRadius / 5), fontSize / 7.5)
                    )
                    .frame(minWidth: state.minWidth)
                    .background(state.backgroundColor)
                    .cornerRadius(state.cornerRadius)
                }
            }
            .font(.system(
                size: fontSize,
                weight: state.fontWeight,
                design: state.fontDesign
            ))
            if state.fontMonospacedDigits {
                stack.monospacedDigit()
            } else {
                stack
            }
        }
    }
}

final class TextEffect: VideoEffect {
    private let settingName: String
    private var stats: Deque<TextEffectStats> = []
    private var overlay: CIImage?
    private var nextUpdateTime = ContinuousClock.now
    private var delay: Double
    private let formatter: Formatter
    private var sceneWidget: SettingsSceneWidget
    private let state: TextViewState
    private var renderer: ImageRenderer<TextView>?
    private var cancellable: AnyCancellable?
    private var forceUpdate: Bool = false
    private var previousLines: [Line]?

    init(
        format: String,
        backgroundColor: RgbColor,
        foregroundColor: RgbColor,
        fontSize: CGFloat,
        fontDesign: Font.Design,
        fontWeight: Font.Weight,
        fontMonospacedDigits: Bool,
        horizontalAlignment: HorizontalAlignment,
        width: Int?,
        cornerRadius: Double,
        settingName: String,
        delay: Double,
        timersEndTime: [ContinuousClock.Instant],
        stopwatches: [SettingsWidgetTextStopwatch],
        checkboxes: [Bool],
        ratings: [Int],
        lapTimes: [[Double]]
    ) {
        formatter = Formatter(formatParts: loadTextFormat(format: format),
                              timersEndTime: timersEndTime,
                              stopwatches: stopwatches,
                              checkboxes: checkboxes,
                              ratings: ratings,
                              lapTimes: lapTimes)
        sceneWidget = SettingsSceneWidget(widgetId: .init())
        state = TextViewState(fontSize: fontSize,
                              fontDesign: fontDesign,
                              fontWeight: fontWeight,
                              fontMonospacedDigits: fontMonospacedDigits,
                              horizontalAlignment: horizontalAlignment,
                              minWidth: Double(width ?? 0),
                              cornerRadius: cornerRadius,
                              foregroundColor: foregroundColor.color(),
                              backgroundColor: backgroundColor.color(),
                              lines: [])
        self.settingName = settingName
        self.delay = delay
        super.init()
        DispatchQueue.main.async {
            self.renderer = ImageRenderer(content: TextView(state: self.state))
            self.cancellable = self.renderer?.objectWillChange.sink { [weak self] in
                guard let self else {
                    return
                }
                self.setOverlay(image: self.renderer?.ciImage())
            }
            self.setOverlay(image: self.renderer?.ciImage())
        }
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
            self.forceUpdate = true
        }
        previousLines = nil
    }

    func forceOverlayUpdate() {
        processorPipelineQueue.async {
            self.forceUpdate = true
        }
        previousLines = nil
    }

    func setFormat(format: String) {
        formatter.formatParts = loadTextFormat(format: format)
        forceOverlayUpdate()
    }

    func setBackgroundColor(color: RgbColor) {
        state.backgroundColor = color.color()
    }

    func setForegroundColor(color: RgbColor) {
        state.foregroundColor = color.color()
    }

    func setFontSize(size: CGFloat) {
        state.fontSize = size
    }

    func setFontDesign(design: Font.Design) {
        state.fontDesign = design
    }

    func setFontWeight(weight: Font.Weight) {
        state.fontWeight = weight
    }

    func setFontMonospacedDigits(enabled: Bool) {
        state.fontMonospacedDigits = enabled
    }

    func setLayout(alignment: HorizontalAlignment, width: Int?, cornerRadius: Double) {
        state.horizontalAlignment = alignment
        state.minWidth = Double(width ?? 0)
        state.cornerRadius = cornerRadius
    }

    func setTimersEndTime(endTimes: [ContinuousClock.Instant]) {
        formatter.timersEndTime = endTimes
        forceOverlayUpdate()
    }

    func setEndTime(index: Int, endTime: ContinuousClock.Instant) {
        guard index < formatter.timersEndTime.count else {
            return
        }
        formatter.timersEndTime[index] = endTime
        forceOverlayUpdate()
    }

    func setStopwatches(stopwatches: [SettingsWidgetTextStopwatch]) {
        formatter.stopwatches = stopwatches
        forceOverlayUpdate()
    }

    func setStopwatch(index: Int, stopwatch: SettingsWidgetTextStopwatch) {
        guard index < formatter.stopwatches.count else {
            return
        }
        formatter.stopwatches[index] = stopwatch
        forceOverlayUpdate()
    }

    func setCheckboxes(checkboxes: [Bool]) {
        formatter.checkboxes = checkboxes
        forceOverlayUpdate()
    }

    func setCheckbox(index: Int, checked: Bool) {
        guard index < formatter.checkboxes.count else {
            return
        }
        formatter.checkboxes[index] = checked
        forceOverlayUpdate()
    }

    func setRatings(ratings: [Int]) {
        formatter.ratings = ratings
        forceOverlayUpdate()
    }

    func setRating(index: Int, rating: Int) {
        guard index < formatter.ratings.count else {
            return
        }
        formatter.ratings[index] = rating
        forceOverlayUpdate()
    }

    func setLapTimes(lapTimes: [[Double]]) {
        formatter.lapTimes = lapTimes
        forceOverlayUpdate()
    }

    func setLapTimes(index: Int, lapTimes: [Double]) {
        guard index < formatter.lapTimes.count else {
            return
        }
        formatter.lapTimes[index] = lapTimes
        forceOverlayUpdate()
    }

    func clearSubtitles() {
        formatter.subtitles.removeAll()
        forceOverlayUpdate()
    }

    func updateSubtitles(position: Int, text: String, languageIdentifier: String?) {
        if let subtitles = formatter.subtitles[languageIdentifier] {
            subtitles.updateSubtitles(position: position, text: text)
        } else {
            let subtitles = Subtitles(languageIdentifier: languageIdentifier)
            subtitles.updateSubtitles(position: position, text: text)
            formatter.subtitles[languageIdentifier] = subtitles
        }
        forceOverlayUpdate()
    }

    func updateStats(stats: TextEffectStats) {
        self.stats.append(stats)
        if self.stats.count > 10 {
            self.stats.removeFirst()
        }
    }

    override func getName() -> String {
        return "\(settingName) text widget"
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        updateOverlayIfNeeded(size: image.extent.size)
        return overlay?
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image) ?? image
    }

    override func prepare(_ image: CIImage, _: VideoEffectInfo) {
        updateOverlayIfNeeded(size: image.extent.size)
    }

    private func formatted(now: ContinuousClock.Instant) -> [Line] {
        guard let stats = stats
            .last(where: { $0.timestamp.advanced(by: .seconds(delay - 1)) <= now }) ?? stats
            .first
        else {
            return []
        }
        return formatter.format(stats: stats, now: now)
    }

    private func updateOverlayIfNeeded(size: CGSize) {
        defer {
            self.forceUpdate = false
        }
        let now = ContinuousClock.now
        guard now >= nextUpdateTime || forceUpdate else {
            return
        }
        if !forceUpdate {
            nextUpdateTime += .seconds(1)
        }
        DispatchQueue.main.async {
            self.updateOverlayInternal(size: size, now: now)
        }
    }

    @MainActor
    private func updateOverlayInternal(size: CGSize, now: ContinuousClock.Instant) {
        let lines = formatted(now: now)
        guard lines != previousLines || size != state.size else {
            return
        }
        previousLines = lines
        state.size = size
        state.lines = lines
    }

    private func setOverlay(image: CIImage?) {
        processorPipelineQueue.async {
            self.overlay = image
        }
    }
}
