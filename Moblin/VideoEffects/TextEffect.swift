import AVFoundation
import Collections
import MetalPetal
import SwiftUI
import UIKit
import Vision
import WeatherKit

private let textQueue = DispatchQueue(label: "com.eerimoq.widget.text")

private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    return formatter
}

private var fullDateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .full
    return formatter
}

struct TextEffectStats {
    let timestamp: ContinuousClock.Instant
    let bitrateAndTotal: String
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
    var formatParts: [TextFormatPart] = []
    var timersEndTime: [ContinuousClock.Instant] = []
    var temperatureFormatter = MeasurementFormatter()
    var checkboxes: [Bool] = []
    var ratings: [Int] = []
    var subtitlesLines: [String] = []
    var lapTimes: [[Double]] = []
    var timerIndex = 0
    var checkboxIndex = 0
    var ratingIndex = 0
    var lapTimesIndex = 0
    var lines: [Line] = []
    var parts: [Part] = []
    var lineId = 0
    var partId = 0

    func format(stats: TextEffectStats, now: ContinuousClock.Instant) -> [Line] {
        timerIndex = 0
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
            case .bitrateAndTotal:
                formatBitrateAndTotal(stats: stats)
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
            case .conditions:
                formatConditions(stats: stats)
            case .temperature:
                formatTemperature(stats: stats)
            case .country:
                formatCountry(stats: stats)
            case .countryFlag:
                formatCountryFlag(stats: stats)
            case .city:
                formatCity(stats: stats)
            case .checkbox:
                formatCheckbox()
            case .rating:
                formatRating()
            case .subtitles:
                formatSubtitles()
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
            data: .text(stats.date.formatted(.dateTime.hour().minute().second()))
        ))
    }

    private func formatShortClock(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(stats.date.formatted(.dateTime.hour().minute()))
        ))
    }

    private func formatDate(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(dateFormatter.string(from: stats.date))
        ))
    }

    private func formatFullDate(stats: TextEffectStats) {
        parts.append(.init(
            id: partId,
            data: .text(fullDateFormatter.string(from: stats.date))
        ))
    }

    private func formatBitrateAndTotal(stats: TextEffectStats) {
        parts.append(.init(id: partId, data: .text(stats.bitrateAndTotal)))
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

    private func formatSubtitles() {
        for line in subtitlesLines {
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
                    let time = ContinuousClock.Duration(secondsComponent: Int64(time), attosecondsComponent: 0)
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
}

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var backgroundColor: RgbColor?
    private var foregroundColor: RgbColor?
    private var fontSize: CGFloat
    private var fontDesign: Font.Design
    private var fontWeight: Font.Weight
    private var fontMonospacedDigits: Bool
    private var horizontalAlignment: HorizontalAlignment
    private var verticalAlignment: VerticalAlignment
    private var x: Double
    private var y: Double
    private let settingName: String
    private var stats: Deque<TextEffectStats> = []
    private var overlay: CIImage?
    private var overlayMetalPetal: MTIImage?
    private var image: UIImage?
    private var imageMetalPetal: UIImage?
    private var newImagePresent: Bool = false
    private var newImageMetalPetalPresent: Bool = false
    private var nextUpdateTime = ContinuousClock.now
    private var nextUpdateTimeMetalPetal = ContinuousClock.now
    private var previousLines: [Line]?
    private var previousLinesMetalPetal: [Line]?
    private var delay: Double
    private var forceUpdate = true
    private var forceUpdateMetalPetal = true
    private let formatter = Formatter()

    init(
        format: String,
        backgroundColor: RgbColor,
        foregroundColor: RgbColor,
        fontSize: CGFloat,
        fontDesign: Font.Design,
        fontWeight: Font.Weight,
        fontMonospacedDigits: Bool,
        horizontalAlignment: HorizontalAlignment,
        verticalAlignment: VerticalAlignment,
        settingName: String,
        delay: Double,
        timersEndTime: [ContinuousClock.Instant],
        checkboxes: [Bool],
        ratings: [Int],
        lapTimes: [[Double]]
    ) {
        formatter.formatParts = loadTextFormat(format: format)
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.fontWeight = fontWeight
        self.fontMonospacedDigits = fontMonospacedDigits
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.settingName = settingName
        self.delay = delay
        x = 0
        y = 0
        formatter.timersEndTime = timersEndTime
        formatter.checkboxes = checkboxes
        formatter.ratings = ratings
        formatter.lapTimes = lapTimes
        formatter.temperatureFormatter.numberFormatter.maximumFractionDigits = 0
        super.init()
    }

    func forceImageUpdate() {
        textQueue.sync {
            forceUpdate = true
            forceUpdateMetalPetal = true
        }
        previousLines = nil
        previousLinesMetalPetal = nil
    }

    func setFormat(format: String) {
        formatter.formatParts = loadTextFormat(format: format)
        forceImageUpdate()
    }

    func setBackgroundColor(color: RgbColor) {
        backgroundColor = color
        forceImageUpdate()
    }

    func setForegroundColor(color: RgbColor) {
        foregroundColor = color
        forceImageUpdate()
    }

    func setFontSize(size: CGFloat) {
        fontSize = size
        forceImageUpdate()
    }

    func setFontDesign(design: Font.Design) {
        fontDesign = design
        forceImageUpdate()
    }

    func setFontWeight(weight: Font.Weight) {
        fontWeight = weight
        forceImageUpdate()
    }

    func setFontMonospacedDigits(enabled: Bool) {
        fontMonospacedDigits = enabled
        forceImageUpdate()
    }

    func setHorizontalAlignment(alignment: HorizontalAlignment) {
        textQueue.sync {
            self.horizontalAlignment = alignment
        }
        forceImageUpdate()
    }

    func setVerticalAlignment(alignment: VerticalAlignment) {
        textQueue.sync {
            self.verticalAlignment = alignment
        }
        forceImageUpdate()
    }

    func setTimersEndTime(endTimes: [ContinuousClock.Instant]) {
        formatter.timersEndTime = endTimes
        forceImageUpdate()
    }

    func setEndTime(index: Int, endTime: ContinuousClock.Instant) {
        guard index < formatter.timersEndTime.count else {
            return
        }
        formatter.timersEndTime[index] = endTime
        forceImageUpdate()
    }

    func setCheckboxes(checkboxes: [Bool]) {
        formatter.checkboxes = checkboxes
        forceImageUpdate()
    }

    func setCheckbox(index: Int, checked: Bool) {
        guard index < formatter.checkboxes.count else {
            return
        }
        formatter.checkboxes[index] = checked
        forceImageUpdate()
    }

    func setRatings(ratings: [Int]) {
        formatter.ratings = ratings
        forceImageUpdate()
    }

    func setRating(index: Int, rating: Int) {
        guard index < formatter.ratings.count else {
            return
        }
        formatter.ratings[index] = rating
        forceImageUpdate()
    }

    func setLapTimes(lapTimes: [[Double]]) {
        formatter.lapTimes = lapTimes
        forceImageUpdate()
    }

    func setLapTimes(index: Int, lapTimes: [Double]) {
        guard index < formatter.lapTimes.count else {
            return
        }
        formatter.lapTimes[index] = lapTimes
        forceImageUpdate()
    }

    func setPosition(x: Double, y: Double) {
        textQueue.sync {
            self.x = x
            self.y = y
            forceUpdate = true
            forceUpdateMetalPetal = true
        }
        previousLines = nil
        previousLinesMetalPetal = nil
    }

    func updateStats(stats: TextEffectStats) {
        self.stats.append(stats)
        if self.stats.count > 10 {
            self.stats.removeFirst()
        }
    }

    private var lastLinePosition = 0

    func clearSubtitles() {
        lastLinePosition = 0
        formatter.subtitlesLines = []
        forceImageUpdate()
    }

    // Something is wrong with subtitles.
    func updateSubtitles(position: Int, text: String) {
        let endPosition = position + text.count
        let length = 50
        while lastLinePosition + length < endPosition {
            lastLinePosition += length
        }
        while lastLinePosition >= endPosition {
            lastLinePosition -= length
            lastLinePosition = max(lastLinePosition, 0)
        }
        let firstLinePosition = lastLinePosition - length
        let lastLineIndex = text.index(text.startIndex, offsetBy: lastLinePosition - position)
        let spaceBeforeLastLineIndex = text[...lastLineIndex].lastIndex(of: " ")
        let lastLine: Substring
        if let spaceBeforeLastLineIndex {
            lastLine = text[spaceBeforeLastLineIndex...]
        } else {
            lastLine = text[lastLineIndex...]
        }
        if firstLinePosition >= position {
            let firstLineIndex = text.index(text.startIndex, offsetBy: firstLinePosition - position)
            let spaceBeforeFirstLineIndex = text[...firstLineIndex].lastIndex(of: " ")
            let firstLine: Substring
            if let spaceBeforeLastLineIndex {
                if let spaceBeforeFirstLineIndex {
                    firstLine = text[spaceBeforeFirstLineIndex ..< spaceBeforeLastLineIndex]
                } else {
                    firstLine = text[firstLineIndex ..< spaceBeforeLastLineIndex]
                }
            } else {
                firstLine = text[firstLineIndex ..< lastLineIndex]
            }
            formatter.subtitlesLines = [firstLine.trim(), lastLine.trim()]
        } else {
            formatter.subtitlesLines = [lastLine.trim()]
        }
        forceImageUpdate()
    }

    override func getName() -> String {
        return "\(settingName) text widget"
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

    private func scaledFontSize(size: CGSize) -> CGFloat {
        return fontSize * (size.maximum() / 1920)
    }

    private func updateOverlay(size: CGSize) {
        let now = ContinuousClock.now
        var newImage: UIImage?
        let (x, y, horizontalAlignment, verticalAlignment, forceUpdate, newImagePresent) = textQueue.sync {
            if self.image != nil {
                newImage = self.image
                self.image = nil
            }
            defer {
                self.forceUpdate = false
                self.newImagePresent = false
            }
            return (
                self.x,
                self.y,
                self.horizontalAlignment,
                self.verticalAlignment,
                self.forceUpdate,
                self.newImagePresent
            )
        }
        if newImagePresent {
            if let newImage {
                var x = toPixels(x, size.width)
                var y = toPixels(y, size.height)
                if horizontalAlignment == .trailing {
                    x -= newImage.size.width
                }
                y = size.height - y
                if verticalAlignment == .top {
                    y -= newImage.size.height
                }
                overlay = CIImage(image: newImage)?
                    .transformed(by: CGAffineTransform(
                        translationX: x,
                        y: y
                    ))
                    .cropped(to: CGRect(x: 0, y: 0, width: size.width, height: size.height))
            } else {
                overlay = nil
            }
        }
        guard now >= nextUpdateTime || forceUpdate else {
            return
        }
        if !forceUpdate {
            nextUpdateTime += .seconds(1)
        }
        DispatchQueue.main.async {
            let lines = self.formatted(now: now)
            guard lines != self.previousLines else {
                return
            }
            self.previousLines = lines
            let text = VStack(alignment: horizontalAlignment, spacing: 2) {
                ForEach(lines) { line in
                    HStack(spacing: 0) {
                        ForEach(line.parts) { part in
                            switch part.data {
                            case let .text(text):
                                Text(text)
                                    .foregroundColor(self.foregroundColor?.color() ?? .clear)
                            case let .imageSystemName(name):
                                Image(systemName: name)
                                    .foregroundColor(self.foregroundColor?.color() ?? .clear)
                            case let .imageSystemNameTryFill(name):
                                if UIImage(systemName: "\(name).fill") != nil {
                                    Image(systemName: "\(name).fill")
                                        .symbolRenderingMode(.multicolor)
                                } else {
                                    Image(systemName: name)
                                        .foregroundColor(self.foregroundColor?.color() ?? .clear)
                                }
                            case let .rating(rating):
                                ForEach(0 ..< 5) { index in
                                    if index < rating {
                                        Text("★")
                                            .foregroundColor(.yellow)
                                    } else {
                                        Text("☆")
                                            .foregroundColor(self.foregroundColor?.color() ?? .white)
                                    }
                                }
                            }
                        }
                    }
                    .padding([.leading, .trailing], 7)
                    .background(self.backgroundColor?.color() ?? .clear)
                    .cornerRadius(10)
                }
            }
            .font(.system(
                size: self.scaledFontSize(size: size),
                weight: self.fontWeight,
                design: self.fontDesign
            ))
            let image: UIImage?
            if self.fontMonospacedDigits {
                let renderer = ImageRenderer(content: text.monospacedDigit())
                image = renderer.uiImage
            } else {
                let renderer = ImageRenderer(content: text)
                image = renderer.uiImage
            }
            textQueue.sync {
                self.image = image
                self.newImagePresent = true
            }
        }
    }

    private func updateOverlayMetalPetal(size: CGSize) -> (Double, Double) {
        let now = ContinuousClock.now
        var newImage: UIImage?
        let (x, y, forceUpdate, newImagePresent) = textQueue.sync {
            if self.imageMetalPetal != nil {
                newImage = self.imageMetalPetal
                self.imageMetalPetal = nil
            }
            defer {
                self.forceUpdateMetalPetal = false
                self.newImageMetalPetalPresent = false
            }
            return (self.x, self.y, self.forceUpdateMetalPetal, self.newImageMetalPetalPresent)
        }
        if newImagePresent {
            if let image = newImage?.cgImage {
                overlayMetalPetal = MTIImage(cgImage: image, isOpaque: true)
            } else {
                overlayMetalPetal = nil
            }
        }
        guard now >= nextUpdateTimeMetalPetal || forceUpdate else {
            return (x, y)
        }
        if !forceUpdate {
            nextUpdateTimeMetalPetal += .seconds(1)
        }
        DispatchQueue.main.async {
            let lines = self.formatted(now: now)
            guard lines != self.previousLinesMetalPetal else {
                return
            }
            self.previousLinesMetalPetal = lines
            let text = VStack(alignment: .leading, spacing: 2) {
                ForEach(lines) { line in
                    HStack(spacing: 0) {
                        ForEach(line.parts) { part in
                            switch part.data {
                            case let .text(text):
                                Text(text)
                                    .foregroundColor(self.foregroundColor?.color() ?? .clear)
                            case let .imageSystemName(name):
                                Image(systemName: name)
                                    .foregroundColor(self.foregroundColor?.color() ?? .clear)
                            case let .imageSystemNameTryFill(name):
                                if UIImage(systemName: "\(name).fill") != nil {
                                    Image(systemName: "\(name).fill")
                                        .symbolRenderingMode(.multicolor)
                                } else {
                                    Image(systemName: name)
                                        .foregroundColor(self.foregroundColor?.color() ?? .clear)
                                }
                            case let .rating(rating):
                                ForEach(0 ..< 5) { index in
                                    if index < rating {
                                        Text("★")
                                            .foregroundColor(.yellow)
                                    } else {
                                        Text("☆")
                                            .foregroundColor(self.foregroundColor?.color() ?? .white)
                                    }
                                }
                            }
                        }
                    }
                    .padding([.leading, .trailing], 7)
                    .background(self.backgroundColor?.color() ?? .clear)
                    .cornerRadius(10)
                }
            }
            .font(.system(
                size: self.scaledFontSize(size: size),
                weight: self.fontWeight,
                design: self.fontDesign
            ))
            let renderer = ImageRenderer(content: text)
            let image = renderer.uiImage
            textQueue.sync {
                self.imageMetalPetal = image
                self.newImageMetalPetalPresent = true
            }
        }
        return (x, y)
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        updateOverlay(size: image.extent.size)
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        guard let image else {
            return image
        }
        var (x, y) = updateOverlayMetalPetal(size: image.size)
        guard let overlayMetalPetal else {
            return image
        }
        x = toPixels(x, image.size.width) + overlayMetalPetal.size.width / 2
        y = toPixels(y, image.size.height) + overlayMetalPetal.size.height / 2
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = [
            .init(content: overlayMetalPetal, position: .init(x: x, y: y)),
        ]
        return filter.outputImage ?? image
    }
}
