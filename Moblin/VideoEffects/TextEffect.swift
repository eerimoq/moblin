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

final class TextEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    private var backgroundColor: RgbColor?
    private var foregroundColor: RgbColor?
    private var fontSize: CGFloat
    private var fontDesign: Font.Design
    private var fontWeight: Font.Weight
    private var horizontalAlignment: HorizontalAlignment
    private var verticalAlignment: VerticalAlignment
    private var x: Double
    private var y: Double
    private let settingName: String
    private var stats: Deque<TextEffectStats> = []
    private var formatParts: [TextFormatPart]
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
    private var timersEndTime: [ContinuousClock.Instant]
    private var checkboxes: [Bool]
    private var ratings: [Int]
    private let temperatureFormatter = MeasurementFormatter()
    private var subtitlesLines: [String] = []
    private var lapTimes: [[Double]] = []

    init(
        format: String,
        backgroundColor: RgbColor,
        foregroundColor: RgbColor,
        fontSize: CGFloat,
        fontDesign: Font.Design,
        fontWeight: Font.Weight,
        horizontalAlignment: HorizontalAlignment,
        verticalAlignment: VerticalAlignment,
        settingName: String,
        delay: Double,
        timersEndTime: [ContinuousClock.Instant],
        checkboxes: [Bool],
        ratings: [Int],
        lapTimes: [[Double]]
    ) {
        formatParts = loadTextFormat(format: format)
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.fontSize = fontSize
        self.fontDesign = fontDesign
        self.fontWeight = fontWeight
        self.horizontalAlignment = horizontalAlignment
        self.verticalAlignment = verticalAlignment
        self.settingName = settingName
        self.delay = delay
        x = 0
        y = 0
        self.timersEndTime = timersEndTime
        self.checkboxes = checkboxes
        self.ratings = ratings
        self.lapTimes = lapTimes
        temperatureFormatter.numberFormatter.maximumFractionDigits = 0
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
        formatParts = loadTextFormat(format: format)
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
        timersEndTime = endTimes
        forceImageUpdate()
    }

    func setEndTime(index: Int, endTime: ContinuousClock.Instant) {
        guard index < timersEndTime.count else {
            return
        }
        timersEndTime[index] = endTime
        forceImageUpdate()
    }

    func setCheckboxes(checkboxes: [Bool]) {
        self.checkboxes = checkboxes
        forceImageUpdate()
    }

    func setCheckbox(index: Int, checked: Bool) {
        guard index < checkboxes.count else {
            return
        }
        checkboxes[index] = checked
        forceImageUpdate()
    }

    func setRatings(ratings: [Int]) {
        self.ratings = ratings
        forceImageUpdate()
    }

    func setRating(index: Int, rating: Int) {
        guard index < ratings.count else {
            return
        }
        ratings[index] = rating
        forceImageUpdate()
    }

    func setLapTimes(lapTimes: [[Double]]) {
        self.lapTimes = lapTimes
        forceImageUpdate()
    }

    func setLapTimes(index: Int, lapTimes: [Double]) {
        guard index < self.lapTimes.count else {
            return
        }
        self.lapTimes[index] = lapTimes
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
        subtitlesLines = []
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
            subtitlesLines = [firstLine.trim(), lastLine.trim()]
        } else {
            subtitlesLines = [lastLine.trim()]
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
        var timerIndex = 0
        var checkboxIndex = 0
        var ratingIndex = 0
        var lapTimesIndex = 0
        var lines: [Line] = []
        var parts: [Part] = []
        var lineId = 0
        var partId = 0
        for formatPart in formatParts {
            switch formatPart {
            case let .text(text):
                parts.append(.init(id: partId, data: .text(text)))
            case .newLine:
                lines.append(.init(id: lineId, parts: parts))
                lineId += 1
                parts = []
            case .clock:
                parts.append(.init(
                    id: partId,
                    data: .text(stats.date.formatted(.dateTime.hour().minute().second()))
                ))
            case .shortClock:
                parts.append(.init(
                    id: partId,
                    data: .text(stats.date.formatted(.dateTime.hour().minute()))
                ))
            case .date:
                parts.append(.init(
                    id: partId,
                    data: .text(dateFormatter.string(from: stats.date))
                ))
            case .fullDate:
                parts.append(.init(
                    id: partId,
                    data: .text(fullDateFormatter.string(from: stats.date))
                ))
            case .bitrateAndTotal:
                parts.append(.init(id: partId, data: .text(stats.bitrateAndTotal)))
            case .debugOverlay:
                parts.append(.init(
                    id: partId,
                    data: .text(stats.debugOverlayLines.joined(separator: "\n"))
                ))
            case .speed:
                parts.append(.init(id: partId, data: .text(stats.speed)))
            case .averageSpeed:
                parts.append(.init(id: partId, data: .text(stats.averageSpeed)))
            case .altitude:
                parts.append(.init(id: partId, data: .text(stats.altitude)))
            case .distance:
                parts.append(.init(id: partId, data: .text(stats.distance)))
            case .slope:
                parts.append(.init(id: partId, data: .text(stats.slope)))
            case .timer:
                if timerIndex < timersEndTime.count {
                    let timeLeft = max(now.duration(to: timersEndTime[timerIndex]).seconds, 0)
                    parts.append(.init(
                        id: partId,
                        data: .text(uptimeFormatter.string(from: Double(timeLeft)) ?? "")
                    ))
                }
                timerIndex += 1
            case .conditions:
                if let conditions = stats.conditions {
                    parts.append(.init(id: partId, data: .imageSystemNameTryFill(conditions)))
                } else {
                    parts.append(.init(id: partId, data: .text("-")))
                }
            case .temperature:
                if let temperature = stats.temperature {
                    parts.append(.init(
                        id: partId,
                        data: .text(temperatureFormatter.string(from: temperature))
                    ))
                } else {
                    parts.append(.init(id: partId, data: .text("-")))
                }
            case .country:
                parts.append(.init(id: partId, data: .text(stats.country ?? "")))
            case .countryFlag:
                parts.append(.init(id: partId, data: .text(stats.countryFlag ?? "-")))
            case .city:
                parts.append(.init(id: partId, data: .text(stats.city ?? "-")))
            case .checkbox:
                if checkboxIndex < checkboxes.count {
                    parts.append(.init(
                        id: partId,
                        data: .imageSystemName(checkboxes[checkboxIndex] ? "checkmark.square" : "square")
                    ))
                }
                checkboxIndex += 1
            case .rating:
                if ratingIndex < ratings.count {
                    parts.append(.init(id: partId, data: .rating(ratings[ratingIndex])))
                }
                ratingIndex += 1
            case .subtitles:
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
            case .muted:
                if stats.muted {
                    parts.append(.init(id: partId, data: .imageSystemName("mic.slash")))
                }
            case let .heartRate(deviceName):
                let text: String
                if let heartRate = stats.heartRates[deviceName], let heartRate {
                    text = String(heartRate)
                } else {
                    text = "-"
                }
                parts.append(.init(id: partId, data: .text(text)))
            case .activeEnergyBurned:
                let text: String
                if let activeEnergyBurned = stats.activeEnergyBurned {
                    text = String(activeEnergyBurned)
                } else {
                    text = "-"
                }
                parts.append(.init(id: partId, data: .text(text)))
            case .power:
                let text: String
                if let power = stats.power {
                    text = String(power)
                } else {
                    text = "-"
                }
                parts.append(.init(id: partId, data: .text(text)))
            case .stepCount:
                let text: String
                if let stepCount = stats.stepCount {
                    text = String(stepCount)
                } else {
                    text = "-"
                }
                parts.append(.init(id: partId, data: .text(text)))
            case .workoutDistance:
                let text: String
                if let workoutDistance = stats.workoutDistance {
                    text = String(workoutDistance)
                } else {
                    text = "-"
                }
                parts.append(.init(id: partId, data: .text(text)))
            case .teslaBatteryLevel:
                parts.append(.init(id: partId, data: .text(stats.teslaBatteryLevel)))
            case .teslaDrive:
                parts.append(.init(id: partId, data: .text(stats.teslaDrive)))
            case .teslaMedia:
                parts.append(.init(id: partId, data: .text(stats.teslaMedia)))
            case .cyclingPower:
                parts.append(.init(id: partId, data: .text(stats.cyclingPower)))
            case .cyclingCadence:
                parts.append(.init(id: partId, data: .text(stats.cyclingCadence)))
            case .lapTimes:
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
            partId += 1
        }
        if !parts.isEmpty {
            lines.append(.init(id: lineId, parts: parts))
        }
        return lines
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
            let renderer = ImageRenderer(content: text)
            let image = renderer.uiImage
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
