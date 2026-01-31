import Collections
import Combine
import SwiftUI
import WeatherKit

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
    let feelsLikeTemperature: Measurement<UnitTemperature>?
    let windSpeed: Measurement<UnitSpeed>?
    let windGust: Measurement<UnitSpeed>?
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
    let garminHeartRate: Int?
    let garminPace: String
    let garminCadence: String
    let garminDistance: String
    let browserTitle: String
    let gForce: GForce?
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
    @Published var lines: [TextEffectLine]

    init(fontSize: CGFloat,
         fontDesign: Font.Design,
         fontWeight: Font.Weight,
         fontMonospacedDigits: Bool,
         horizontalAlignment: HorizontalAlignment,
         minWidth: Double,
         cornerRadius: Double,
         foregroundColor: Color,
         backgroundColor: Color,
         lines: [TextEffectLine])
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
    private var stats: Deque<TextEffectStats> = []
    private var overlay: CIImage?
    private var nextUpdateTime = ContinuousClock.now
    private var delay: Double
    private let formatter: TextEffectFormatter
    private var sceneWidget: SettingsSceneWidget
    private let state: TextViewState
    private var renderer: ImageRenderer<TextView>?
    private var cancellable: AnyCancellable?
    private var forceUpdate: Bool = false
    private var previousLines: [TextEffectLine]?

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
        delay: Double,
        timersEndTime: [ContinuousClock.Instant],
        stopwatches: [SettingsWidgetTextStopwatch],
        checkboxes: [Bool],
        ratings: [Int],
        lapTimes: [[Double]]
    ) {
        formatter = TextEffectFormatter(formatParts: loadTextFormat(format: format),
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

    private func formatted(now: ContinuousClock.Instant) -> [TextEffectLine] {
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
