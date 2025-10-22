import AVFoundation
import SwiftUI

private func decodeCameraId<T>(_ container: KeyedDecodingContainer<T>,
                               _ key: KeyedDecodingContainer<T>.Key,
                               _ defaultValue: String) -> String
{
    var cameraId = container.decode(key, String.self, defaultValue)
    if AVCaptureDevice(uniqueID: cameraId) == nil {
        cameraId = defaultValue
    }
    return cameraId
}

private func decodeCameraPosition<T>(_ container: KeyedDecodingContainer<T>,
                                     _ key: KeyedDecodingContainer<T>.Key,
                                     _ defaultValue: SettingsSceneCameraPosition) -> SettingsSceneCameraPosition
{
    var position = container.decode(key, SettingsSceneCameraPosition.self, defaultValue)
    if (position == .backTripleLowEnergy && !hasTripleBackCamera)
        || (position == .backDualLowEnergy && !hasDualBackCamera)
        || (position == .backWideDualLowEnergy && !hasWideDualBackCamera)
    {
        position = defaultValue
    }
    return position
}

enum SettingsVideoEffectType: String, Codable, CaseIterable {
    case shape
    case grayScale
    case sepia
    case whirlpool
    case pinch
    case removeBackground
    case dewarp360
    case anamorphicLens

    init(from decoder: Decoder) throws {
        do {
            self = try SettingsVideoEffectType(rawValue: decoder.singleValueContainer()
                .decode(RawValue.self)) ?? .shape
        } catch {
            self = .shape
        }
    }

    func toString() -> String {
        switch self {
        case .shape:
            return String(localized: "Shape")
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .whirlpool:
            return String(localized: "Whirlpool")
        case .pinch:
            return String(localized: "Pinch")
        case .removeBackground:
            return String(localized: "Remove background")
        case .dewarp360:
            return String(localized: "Dewarp 360")
        case .anamorphicLens:
            return String(localized: "Anamorphic lens")
        }
    }
}

private let defaultFromColor = RgbColor(red: 220, green: 235, blue: 92)
private let defaultToColor = RgbColor(red: 82, green: 180, blue: 203)

class SettingsVideoEffectRemoveBackground: Codable, ObservableObject {
    var from: RgbColor = defaultFromColor
    @Published var fromColor: Color
    var to: RgbColor = defaultToColor
    @Published var toColor: Color

    enum CodingKeys: CodingKey {
        case from,
             to
    }

    init() {
        fromColor = from.color()
        toColor = to.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.from, from)
        try container.encode(.to, to)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        from = container.decode(.from, RgbColor.self, defaultFromColor)
        fromColor = from.color()
        to = container.decode(.to, RgbColor.self, defaultToColor)
        toColor = to.color()
    }
}

class SettingsVideoEffectShape: Codable, ObservableObject {
    @Published var cornerRadius: Float = 0.1
    @Published var borderWidth: Double = 0
    var borderColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var borderColorColor: Color
    @Published var cropEnabled: Bool = false
    var cropX: Double = 0.25
    var cropY: Double = 0.0
    var cropWidth: Double = 0.5
    var cropHeight: Double = 1.0

    enum CodingKeys: CodingKey {
        case cornerRadius,
             borderWidth,
             borderColor,
             cropEnabled,
             cropX,
             cropY,
             cropWidth,
             cropHeight
    }

    init() {
        borderColorColor = borderColor.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.cornerRadius, cornerRadius)
        try container.encode(.borderWidth, borderWidth)
        try container.encode(.borderColor, borderColor)
        try container.encode(.cropEnabled, cropEnabled)
        try container.encode(.cropX, cropX)
        try container.encode(.cropY, cropY)
        try container.encode(.cropWidth, cropWidth)
        try container.encode(.cropHeight, cropHeight)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cornerRadius = container.decode(.cornerRadius, Float.self, 0.1)
        borderWidth = container.decode(.borderWidth, Double.self, 0)
        borderColor = container.decode(.borderColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        borderColorColor = borderColor.color()
        cropEnabled = container.decode(.cropEnabled, Bool.self, false)
        cropX = container.decode(.cropX, Double.self, 0.25)
        cropY = container.decode(.cropY, Double.self, 0.0)
        cropWidth = container.decode(.cropWidth, Double.self, 0.5)
        cropHeight = container.decode(.cropHeight, Double.self, 1.0)
    }

    func toSettings() -> ShapeEffectSettings {
        return .init(cornerRadius: cornerRadius,
                     borderWidth: borderWidth,
                     borderColor: CIColor(
                         red: Double(borderColor.red) / 255,
                         green: Double(borderColor.green) / 255,
                         blue: Double(borderColor.blue) / 255
                     ),
                     cropEnabled: cropEnabled,
                     cropX: cropX,
                     cropY: cropY,
                     cropWidth: cropWidth,
                     cropHeight: cropHeight)
    }
}

class SettingsVideoEffectDewarp360: Codable, ObservableObject {
    @Published var pan: Float = 0
    @Published var tilt: Float = 0
    var zoom: Float = 1
    @Published var inverseFieldOfView: Float = 90

    init() {}

    enum CodingKeys: CodingKey {
        case pan,
             tilt,
             zoom
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.pan, pan)
        try container.encode(.tilt, tilt)
        try container.encode(.zoom, zoom)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        pan = container.decode(.pan, Float.self, 0)
        tilt = container.decode(.tilt, Float.self, 0)
        zoom = container.decode(.zoom, Float.self, 1)
        inverseFieldOfView = 180 - zoomToFieldOfView(zoom: zoom).toDegrees()
    }

    func updateZoomFromInverseFieldOfView() {
        zoom = fieldOfViewToZoom(fieldOfView: (180 - inverseFieldOfView).toRadians())
    }

    func toSettings() -> Dewarp360EffectSettings {
        return .direct(pan: -pan.toRadians(),
                       tilt: tilt.toRadians(),
                       fieldOfView: zoomToFieldOfView(zoom: zoom))
    }
}

class SettingsVideoEffectAnamorphicLens: Codable, ObservableObject {
    @Published var scale: Double = 1.33

    init() {}

    enum CodingKeys: CodingKey {
        case scale
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.scale, scale)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        scale = container.decode(.scale, Double.self, 1.33)
    }

    func clone() -> SettingsVideoEffectAnamorphicLens {
        let new = SettingsVideoEffectAnamorphicLens()
        new.scale = scale
        return new
    }
}

class SettingsVideoEffect: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var enabled: Bool = true
    @Published var type: SettingsVideoEffectType = .shape
    var removeBackground: SettingsVideoEffectRemoveBackground = .init()
    var shape: SettingsVideoEffectShape = .init()
    var dewarp360: SettingsVideoEffectDewarp360 = .init()
    var anamorphicLens: SettingsVideoEffectAnamorphicLens = .init()

    enum CodingKeys: CodingKey {
        case id,
             enabled,
             type,
             removeBackground,
             shape,
             dewarp360,
             anamorphicLens
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.type, type)
        try container.encode(.removeBackground, removeBackground)
        try container.encode(.shape, shape)
        try container.encode(.dewarp360, dewarp360)
        try container.encode(.anamorphicLens, anamorphicLens)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        type = container.decode(.type, SettingsVideoEffectType.self, .shape)
        removeBackground = container.decode(.removeBackground, SettingsVideoEffectRemoveBackground.self, .init())
        shape = container.decode(.shape, SettingsVideoEffectShape.self, .init())
        dewarp360 = container.decode(.dewarp360, SettingsVideoEffectDewarp360.self, .init())
        anamorphicLens = container.decode(
            .anamorphicLens,
            SettingsVideoEffectAnamorphicLens.self,
            .init()
        )
    }

    func getEffect() -> VideoEffect {
        switch type {
        case .grayScale:
            return GrayScaleEffect()
        case .sepia:
            return SepiaEffect()
        case .whirlpool:
            return WhirlpoolEffect(angle: .pi / 2)
        case .pinch:
            return PinchEffect(scale: 0.5)
        case .removeBackground:
            let effect = RemoveBackgroundEffect()
            effect.setColorRange(from: removeBackground.from, to: removeBackground.to)
            return effect
        case .shape:
            let effect = ShapeEffect()
            effect.setSettings(settings: shape.toSettings())
            return effect
        case .dewarp360:
            let effect = Dewarp360Effect()
            effect.setSettings(settings: dewarp360.toSettings())
            return effect
        case .anamorphicLens:
            return AnamorphicLensEffect(settings: anamorphicLens.clone())
        }
    }
}

enum SettingsFontDesign: String, Codable, CaseIterable {
    case `default` = "Default"
    case serif = "Serif"
    case rounded = "Rounded"
    case monospaced = "Monospaced"

    init(from decoder: Decoder) throws {
        self = try SettingsFontDesign(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .default
    }

    func toString() -> String {
        switch self {
        case .default:
            return String(localized: "Default")
        case .serif:
            return String(localized: "Serif")
        case .rounded:
            return String(localized: "Rounded")
        case .monospaced:
            return String(localized: "Monospaced")
        }
    }

    func toSystem() -> Font.Design {
        switch self {
        case .default:
            return .default
        case .serif:
            return .serif
        case .rounded:
            return .rounded
        case .monospaced:
            return .monospaced
        }
    }
}

enum SettingsFontWeight: String, Codable, CaseIterable {
    case regular = "Regular"
    case light = "Light"
    case bold = "Bold"

    init(from decoder: Decoder) throws {
        self = try SettingsFontWeight(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .regular
    }

    func toString() -> String {
        switch self {
        case .regular:
            return String(localized: "Regular")
        case .light:
            return String(localized: "Light")
        case .bold:
            return String(localized: "Bold")
        }
    }

    func toSystem() -> Font.Weight {
        switch self {
        case .regular:
            return .regular
        case .light:
            return .light
        case .bold:
            return .bold
        }
    }
}

enum SettingsHorizontalAlignment: String, Codable, CaseIterable {
    case leading = "Leading"
    case trailing = "Trailing"

    init(from decoder: Decoder) throws {
        self = try SettingsHorizontalAlignment(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .leading
    }

    func toString() -> String {
        switch self {
        case .leading:
            return String(localized: "Leading")
        case .trailing:
            return String(localized: "Trailing")
        }
    }

    func toSystem() -> HorizontalAlignment {
        switch self {
        case .leading:
            return .leading
        case .trailing:
            return .trailing
        }
    }
}

enum SettingsVerticalAlignment: String, Codable, CaseIterable {
    case top = "Top"
    case bottom = "Bottom"

    init(from decoder: Decoder) throws {
        self = try SettingsVerticalAlignment(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .top
    }

    func toString() -> String {
        switch self {
        case .top:
            return String(localized: "Top")
        case .bottom:
            return String(localized: "Bottom")
        }
    }

    func toSystem() -> VerticalAlignment {
        switch self {
        case .top:
            return .top
        case .bottom:
            return .bottom
        }
    }
}

enum SettingsAlignment: String, Codable, CaseIterable {
    case topLeft = "TopLeft"
    case topRight = "TopRight"
    case bottomLeft = "BottomLeft"
    case bottomRight = "BottomRight"

    init(from decoder: Decoder) throws {
        self = try SettingsAlignment(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .topLeft
    }

    func isLeft() -> Bool {
        return self == .topLeft || self == .bottomLeft
    }

    func isTop() -> Bool {
        return self == .topLeft || self == .topRight
    }

    func toString() -> String {
        switch self {
        case .topLeft:
            return String(localized: "Top left")
        case .topRight:
            return String(localized: "Top right")
        case .bottomLeft:
            return String(localized: "Bottom left")
        case .bottomRight:
            return String(localized: "Bottom right")
        }
    }
}

class SettingsWidgetTextTimer: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var delta: Int = 5
    @Published var endTime: Double = 0

    enum CodingKeys: CodingKey {
        case id,
             delta,
             endTime
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.delta, delta)
        try container.encode(.endTime, endTime)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        delta = container.decode(.delta, Int.self, 5)
        endTime = container.decode(.endTime, Double.self, 0)
    }

    func add(delta: Double) {
        if timeLeft() < 0 {
            endTime = Date().timeIntervalSince1970
        }
        endTime += delta
    }

    func format() -> String {
        return Duration(secondsComponent: Int64(max(timeLeft(), 0)), attosecondsComponent: 0).formatWithSeconds()
    }

    func textEffectEndTime() -> ContinuousClock.Instant {
        return .now.advanced(by: .seconds(max(timeLeft(), 0)))
    }

    private func timeLeft() -> Double {
        return utcTimeDeltaFromNow(to: endTime)
    }
}

class SettingsWidgetTextStopwatch: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var totalElapsed: Double = 0.0
    var playPressedTime: ContinuousClock.Instant = .now
    @Published var running: Bool = false

    enum CodingKeys: CodingKey {
        case id
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
    }

    func clone() -> SettingsWidgetTextStopwatch {
        let new = SettingsWidgetTextStopwatch()
        new.id = id
        new.playPressedTime = playPressedTime
        new.totalElapsed = totalElapsed
        new.running = running
        return new
    }
}

class SettingsWidgetTextSubtitles: Codable {
    var identifier: String?
}

class SettingsWidgetTextCheckbox: Codable, Identifiable {
    var id: UUID = .init()
    var checked: Bool = false
}

class SettingsWidgetTextRating: Codable, Identifiable {
    var id: UUID = .init()
    var rating: Int = 0
}

class SettingsWidgetTextLapTimes: Codable, Identifiable {
    var id: UUID = .init()
    var currentLapStartTime: Double?
    var lapTimes: [Double] = []
}

class SettingsWidgetText: Codable, ObservableObject {
    @Published var formatString: String = "{shortTime}"
    var backgroundColor: RgbColor = .init(red: 0, green: 0, blue: 0, opacity: 0.75)
    @Published var backgroundColorColor: Color
    var clearBackgroundColor: Bool = false
    var foregroundColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    @Published var foregroundColorColor: Color
    var clearForegroundColor: Bool = false
    var fontSize: Int = 30
    @Published var fontSizeFloat: Float
    @Published var fontDesign: SettingsFontDesign = .default
    @Published var fontWeight: SettingsFontWeight = .regular
    @Published var fontMonospacedDigits: Bool = false
    @Published var alignment: SettingsHorizontalAlignment = .leading
    @Published var horizontalAlignment: SettingsHorizontalAlignment = .leading
    @Published var verticalAlignment: SettingsVerticalAlignment = .top
    @Published var delay: Double = 0.0
    var timers: [SettingsWidgetTextTimer] = []
    var stopwatches: [SettingsWidgetTextStopwatch] = []
    var needsWeather: Bool = false
    var needsGeography: Bool = false
    var needsSubtitles: Bool = false
    var subtitles: [SettingsWidgetTextSubtitles] = []
    var checkboxes: [SettingsWidgetTextCheckbox] = []
    var ratings: [SettingsWidgetTextRating] = []
    var lapTimes: [SettingsWidgetTextLapTimes] = []
    var needsGForce: Bool = false

    enum CodingKeys: CodingKey {
        case formatString,
             backgroundColor,
             clearBackgroundColor,
             foregroundColor,
             clearForegroundColor,
             fontSize,
             fontDesign,
             fontWeight,
             fontMonospacedDigits,
             alignment,
             horizontalAlignment,
             verticalAlignment,
             delay,
             timers,
             stopwatches,
             needsWeather,
             needsGeography,
             needsSubtitles,
             subtitles,
             checkboxes,
             ratings,
             lapTimes,
             needsGForce
    }

    init() {
        backgroundColorColor = backgroundColor.color()
        foregroundColorColor = foregroundColor.color()
        fontSizeFloat = Float(fontSize)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.formatString, formatString)
        try container.encode(.backgroundColor, backgroundColor)
        try container.encode(.clearBackgroundColor, clearBackgroundColor)
        try container.encode(.foregroundColor, foregroundColor)
        try container.encode(.clearForegroundColor, clearForegroundColor)
        try container.encode(.fontSize, fontSize)
        try container.encode(.fontDesign, fontDesign)
        try container.encode(.fontWeight, fontWeight)
        try container.encode(.fontMonospacedDigits, fontMonospacedDigits)
        try container.encode(.alignment, alignment)
        try container.encode(.horizontalAlignment, horizontalAlignment)
        try container.encode(.verticalAlignment, verticalAlignment)
        try container.encode(.delay, delay)
        try container.encode(.timers, timers)
        try container.encode(.stopwatches, stopwatches)
        try container.encode(.needsWeather, needsWeather)
        try container.encode(.needsGeography, needsGeography)
        try container.encode(.needsSubtitles, needsSubtitles)
        try container.encode(.subtitles, subtitles)
        try container.encode(.checkboxes, checkboxes)
        try container.encode(.ratings, ratings)
        try container.encode(.lapTimes, lapTimes)
        try container.encode(.needsGForce, needsGForce)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formatString = container.decode(.formatString, String.self, "{shortTime}")
        backgroundColor = container.decode(
            .backgroundColor,
            RgbColor.self,
            .init(red: 0, green: 0, blue: 0, opacity: 0.75)
        )
        backgroundColorColor = backgroundColor.color()
        clearBackgroundColor = container.decode(.clearBackgroundColor, Bool.self, false)
        foregroundColor = container.decode(.foregroundColor, RgbColor.self, .init(red: 255, green: 255, blue: 255))
        foregroundColorColor = foregroundColor.color()
        clearForegroundColor = container.decode(.clearForegroundColor, Bool.self, false)
        fontSize = container.decode(.fontSize, Int.self, 30)
        fontSizeFloat = Float(fontSize)
        fontDesign = container.decode(.fontDesign, SettingsFontDesign.self, .default)
        fontWeight = container.decode(.fontWeight, SettingsFontWeight.self, .regular)
        fontMonospacedDigits = container.decode(.fontMonospacedDigits, Bool.self, false)
        alignment = container.decode(.alignment, SettingsHorizontalAlignment.self, .leading)
        horizontalAlignment = container.decode(.horizontalAlignment, SettingsHorizontalAlignment.self, .leading)
        verticalAlignment = container.decode(.verticalAlignment, SettingsVerticalAlignment.self, .top)
        delay = container.decode(.delay, Double.self, 0.0)
        timers = container.decode(.timers, [SettingsWidgetTextTimer].self, [])
        stopwatches = container.decode(.stopwatches, [SettingsWidgetTextStopwatch].self, [])
        needsWeather = container.decode(.needsWeather, Bool.self, false)
        needsGeography = container.decode(.needsGeography, Bool.self, false)
        needsSubtitles = container.decode(.needsSubtitles, Bool.self, false)
        subtitles = container.decode(.subtitles, [SettingsWidgetTextSubtitles].self, [])
        checkboxes = container.decode(.checkboxes, [SettingsWidgetTextCheckbox].self, [])
        ratings = container.decode(.ratings, [SettingsWidgetTextRating].self, [])
        lapTimes = container.decode(.lapTimes, [SettingsWidgetTextLapTimes].self, [])
        needsGForce = container.decode(.needsGForce, Bool.self, false)
    }
}

class SettingsWidgetCrop: Codable {
    var sourceWidgetId: UUID = .init()
    var x: Int = 0
    var y: Int = 0
    var width: Int = 200
    var height: Int = 200

    func clone() -> SettingsWidgetCrop {
        let new = SettingsWidgetCrop()
        new.sourceWidgetId = sourceWidgetId
        new.x = x
        new.y = y
        new.width = width
        new.height = height
        return new
    }
}

class SettingsWidgetBrowser: Codable, ObservableObject {
    @Published var url: String = ""
    @Published var width: Int = 500
    @Published var height: Int = 500
    @Published var audioOnly: Bool = false
    @Published var scaleToFitVideo: Bool = false
    @Published var fps: Float = 5.0
    @Published var styleSheet: String = ""
    @Published var moblinAccess: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case url,
             width,
             height,
             audioOnly,
             scaleToFitVideo,
             fps,
             styleSheet,
             moblinAccess
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.url, url)
        try container.encode(.width, width)
        try container.encode(.height, height)
        try container.encode(.audioOnly, audioOnly)
        try container.encode(.scaleToFitVideo, scaleToFitVideo)
        try container.encode(.fps, fps)
        try container.encode(.styleSheet, styleSheet)
        try container.encode(.moblinAccess, moblinAccess)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        url = container.decode(.url, String.self, "")
        width = container.decode(.width, Int.self, 500)
        height = container.decode(.height, Int.self, 500)
        audioOnly = container.decode(.audioOnly, Bool.self, false)
        scaleToFitVideo = container.decode(.scaleToFitVideo, Bool.self, false)
        fps = container.decode(.fps, Float.self, 5.0)
        styleSheet = container.decode(.styleSheet, String.self, "")
        moblinAccess = container.decode(.moblinAccess, Bool.self, false)
    }
}

class SettingsWidgetMap: Codable {
    var northUp: Bool = false
    var delay: Double = 0.0

    init() {}

    enum CodingKeys: CodingKey {
        case northUp,
             delay
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.northUp, northUp)
        try container.encode(.delay, delay)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        northUp = container.decode(.northUp, Bool.self, false)
        delay = container.decode(.delay, Double.self, 0.0)
    }

    func clone() -> SettingsWidgetMap {
        let new = SettingsWidgetMap()
        new.northUp = northUp
        new.delay = delay
        return new
    }
}

class SettingsWidgetScene: Codable {
    var sceneId: UUID = .init()
}

class SettingsWidgetQrCode: Codable {
    var message = ""

    func clone() -> SettingsWidgetQrCode {
        let new = SettingsWidgetQrCode()
        new.message = message
        return new
    }
}

enum SettingsWidgetAlertPositionType: String, Codable, CaseIterable {
    case scene = "Scene"
    case face = "Face"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetAlertPositionType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .scene
    }

    func toString() -> String {
        switch self {
        case .scene:
            return String(localized: "Scene")
        case .face:
            return String(localized: "Face")
        }
    }
}

class SettingsWidgetAlertFacePosition: Codable {
    var x: Double = 0.25
    var y: Double = 0.25
    var width: Double = 0.5
    var height: Double = 0.5
}

class SettingsWidgetAlertsAlert: Codable, ObservableObject {
    var enabled: Bool = true
    var imageId: UUID = .init()
    var imageLoopCount: Int = 1
    var soundId: UUID = .init()
    var textColor: RgbColor = .init(red: 255, green: 255, blue: 255)
    var accentColor: RgbColor = .init(red: 0xFD, green: 0xFB, blue: 0x67)
    var fontSize: Int = 45
    var fontDesign: SettingsFontDesign = .monospaced
    var fontWeight: SettingsFontWeight = .bold
    var textToSpeechEnabled: Bool = true
    var textToSpeechDelay: Double = 1.5
    @Published var textToSpeechLanguageVoices: [String: String] = .init()
    var positionType: SettingsWidgetAlertPositionType = .scene
    var facePosition: SettingsWidgetAlertFacePosition = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case enabled,
             imageId,
             imageLoopCount,
             soundId,
             textColor,
             accentColor,
             fontSize,
             fontDesign,
             fontWeight,
             textToSpeechEnabled,
             textToSpeechDelay,
             textToSpeechLanguageVoices,
             positionType,
             facePosition
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.enabled, enabled)
        try container.encode(.imageId, imageId)
        try container.encode(.imageLoopCount, imageLoopCount)
        try container.encode(.soundId, soundId)
        try container.encode(.textColor, textColor)
        try container.encode(.accentColor, accentColor)
        try container.encode(.fontSize, fontSize)
        try container.encode(.fontDesign, fontDesign)
        try container.encode(.fontWeight, fontWeight)
        try container.encode(.textToSpeechEnabled, textToSpeechEnabled)
        try container.encode(.textToSpeechDelay, textToSpeechDelay)
        try container.encode(.textToSpeechLanguageVoices, textToSpeechLanguageVoices)
        try container.encode(.positionType, positionType)
        try container.encode(.facePosition, facePosition)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = container.decode(.enabled, Bool.self, true)
        imageId = container.decode(.imageId, UUID.self, .init())
        imageLoopCount = container.decode(.imageLoopCount, Int.self, 1)
        soundId = container.decode(.soundId, UUID.self, .init())
        textColor = container.decode(.textColor, RgbColor.self, .init(red: 255, green: 255, blue: 255))
        accentColor = container.decode(.accentColor, RgbColor.self, .init(red: 0xFD, green: 0xFB, blue: 0x67))
        fontSize = container.decode(.fontSize, Int.self, 45)
        fontDesign = container.decode(.fontDesign, SettingsFontDesign.self, .monospaced)
        fontWeight = container.decode(.fontWeight, SettingsFontWeight.self, .bold)
        textToSpeechEnabled = container.decode(.textToSpeechEnabled, Bool.self, true)
        textToSpeechDelay = container.decode(.textToSpeechDelay, Double.self, 1.5)
        textToSpeechLanguageVoices = container.decode(.textToSpeechLanguageVoices, [String: String].self, .init())
        positionType = container.decode(.positionType, SettingsWidgetAlertPositionType.self, .scene)
        facePosition = container.decode(.facePosition, SettingsWidgetAlertFacePosition.self, .init())
    }

    func isTextToSpeechEnabled() -> Bool {
        return enabled && textToSpeechEnabled
    }

    func clone() -> SettingsWidgetAlertsAlert {
        let new = SettingsWidgetAlertsAlert()
        new.enabled = enabled
        new.imageId = imageId
        new.imageLoopCount = imageLoopCount
        new.soundId = soundId
        new.textColor = textColor
        new.accentColor = accentColor
        new.fontSize = fontSize
        new.fontDesign = fontDesign
        new.fontWeight = fontWeight
        new.textToSpeechEnabled = textToSpeechEnabled
        new.textToSpeechDelay = textToSpeechDelay
        new.textToSpeechLanguageVoices = textToSpeechLanguageVoices
        new.positionType = positionType
        new.facePosition = facePosition
        return new
    }
}

enum SettingsWidgetAlertsCheerBitsAlertOperator: String, Codable, CaseIterable {
    case equal = "="
    case greaterEqual = ">="

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetAlertsCheerBitsAlertOperator(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .equal
    }
}

let cheerBitsAlertOperators = SettingsWidgetAlertsCheerBitsAlertOperator.allCases.map { $0.rawValue }

class SettingsWidgetAlertsCheerBitsAlert: Codable, Identifiable {
    var id: UUID = .init()
    var bits: Int = 1
    var comparisonOperator: SettingsWidgetAlertsCheerBitsAlertOperator = .greaterEqual
    var alert: SettingsWidgetAlertsAlert = .init()

    func clone() -> SettingsWidgetAlertsCheerBitsAlert {
        let new = SettingsWidgetAlertsCheerBitsAlert()
        new.bits = bits
        new.comparisonOperator = comparisonOperator
        new.alert = alert
        return new
    }
}

class SettingsWidgetAlertsKickGiftsAlert: Codable, Identifiable {
    var id: UUID = .init()
    var amount: Int = 1
    var comparisonOperator: SettingsWidgetAlertsCheerBitsAlertOperator = .greaterEqual
    var alert: SettingsWidgetAlertsAlert = .init()

    func clone() -> SettingsWidgetAlertsKickGiftsAlert {
        let new = SettingsWidgetAlertsKickGiftsAlert()
        new.amount = amount
        new.comparisonOperator = comparisonOperator
        new.alert = alert
        return new
    }
}

private func createDefaultCheerBits() -> [SettingsWidgetAlertsCheerBitsAlert] {
    var cheerBits: [SettingsWidgetAlertsCheerBitsAlert] = []
    for (index, bits) in [1].enumerated() {
        let cheer = SettingsWidgetAlertsCheerBitsAlert()
        cheer.bits = bits
        cheer.alert.enabled = index == 0
        cheerBits.append(cheer)
    }
    return cheerBits
}

private func createDefaultKickGifts() -> [SettingsWidgetAlertsKickGiftsAlert] {
    var kickGifts: [SettingsWidgetAlertsKickGiftsAlert] = []
    for (index, amount) in [1].enumerated() {
        let gift = SettingsWidgetAlertsKickGiftsAlert()
        gift.amount = amount
        gift.alert.enabled = index == 0
        kickGifts.append(gift)
    }
    return kickGifts
}

class SettingsWidgetAlertsTwitch: Codable {
    var follows: SettingsWidgetAlertsAlert = .init()
    var subscriptions: SettingsWidgetAlertsAlert = .init()
    var raids: SettingsWidgetAlertsAlert = .init()
    var cheers: SettingsWidgetAlertsAlert = .init()
    var cheerBits: [SettingsWidgetAlertsCheerBitsAlert] = createDefaultCheerBits()

    init() {}

    enum CodingKeys: CodingKey {
        case follows,
             subscriptions,
             raids,
             cheers,
             cheerBits
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.follows, follows)
        try container.encode(.subscriptions, subscriptions)
        try container.encode(.raids, raids)
        try container.encode(.cheers, cheers)
        try container.encode(.cheerBits, cheerBits)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        follows = container.decode(.follows, SettingsWidgetAlertsAlert.self, .init())
        subscriptions = container.decode(.subscriptions, SettingsWidgetAlertsAlert.self, .init())
        raids = container.decode(.raids, SettingsWidgetAlertsAlert.self, .init())
        cheers = container.decode(.cheers, SettingsWidgetAlertsAlert.self, .init())
        cheerBits = container.decode(.cheerBits, [SettingsWidgetAlertsCheerBitsAlert].self, createDefaultCheerBits())
    }

    func clone() -> SettingsWidgetAlertsTwitch {
        let new = SettingsWidgetAlertsTwitch()
        new.follows = follows.clone()
        new.subscriptions = subscriptions.clone()
        new.raids = raids.clone()
        new.cheers = cheers.clone()
        new.cheerBits = cheerBits.map { $0.clone() }
        return new
    }
}

class SettingsWidgetAlertsKick: Codable {
    var subscriptions: SettingsWidgetAlertsAlert = .init()
    var giftedSubscriptions: SettingsWidgetAlertsAlert = .init()
    var hosts: SettingsWidgetAlertsAlert = .init()
    var rewards: SettingsWidgetAlertsAlert = .init()
    var kickGifts: [SettingsWidgetAlertsKickGiftsAlert] = createDefaultKickGifts()

    init() {}

    enum CodingKeys: CodingKey {
        case subscriptions,
             giftedSubscriptions,
             hosts,
             rewards,
             kickGifts
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.subscriptions, subscriptions)
        try container.encode(.giftedSubscriptions, giftedSubscriptions)
        try container.encode(.hosts, hosts)
        try container.encode(.rewards, rewards)
        try container.encode(.kickGifts, kickGifts)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subscriptions = container.decode(.subscriptions, SettingsWidgetAlertsAlert.self, .init())
        giftedSubscriptions = container.decode(.giftedSubscriptions, SettingsWidgetAlertsAlert.self, .init())
        hosts = container.decode(.hosts, SettingsWidgetAlertsAlert.self, .init())
        rewards = container.decode(.rewards, SettingsWidgetAlertsAlert.self, .init())
        kickGifts = container.decode(.kickGifts, [SettingsWidgetAlertsKickGiftsAlert].self, createDefaultKickGifts())
    }

    func clone() -> SettingsWidgetAlertsKick {
        let new = SettingsWidgetAlertsKick()
        new.subscriptions = subscriptions.clone()
        new.giftedSubscriptions = giftedSubscriptions.clone()
        new.hosts = hosts.clone()
        new.rewards = rewards.clone()
        new.kickGifts = kickGifts.map { $0.clone() }
        return new
    }
}

enum SettingsWidgetAlertsChatBotCommandImageType: String, Codable, CaseIterable {
    case file = "File"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetAlertsChatBotCommandImageType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .file
    }

    func toString() -> String {
        switch self {
        case .file:
            return String(localized: "File")
        }
    }
}

class SettingsWidgetAlertsChatBotCommand: Codable, Identifiable, @unchecked Sendable {
    var id: UUID = .init()
    var name: String = "myname"
    var alert: SettingsWidgetAlertsAlert = .init()
    var imageType: SettingsWidgetAlertsChatBotCommandImageType = .file

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             alert,
             imageType
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.alert, alert)
        try container.encode(.imageType, imageType)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "myname")
        alert = container.decode(.alert, SettingsWidgetAlertsAlert.self, .init())
        imageType = container.decode(.imageType, SettingsWidgetAlertsChatBotCommandImageType.self, .file)
    }

    func clone() -> SettingsWidgetAlertsChatBotCommand {
        let new = SettingsWidgetAlertsChatBotCommand()
        new.name = name
        new.alert = alert.clone()
        new.imageType = imageType
        return new
    }
}

class SettingsWidgetAlertsChatBot: Codable {
    var commands: [SettingsWidgetAlertsChatBotCommand] = []

    func clone() -> SettingsWidgetAlertsChatBot {
        let new = SettingsWidgetAlertsChatBot()
        for command in commands {
            new.commands.append(command.clone())
        }
        return new
    }
}

class SettingsWidgetAlertsSpeechToTextString: Codable, Identifiable {
    var id: UUID = .init()
    var string: String = ""
    var alert: SettingsWidgetAlertsAlert = .init()

    func clone() -> SettingsWidgetAlertsSpeechToTextString {
        let new = SettingsWidgetAlertsSpeechToTextString()
        new.id = id
        new.string = string
        new.alert = alert.clone()
        return new
    }
}

class SettingsWidgetAlertsSpeechToText: Codable {
    var strings: [SettingsWidgetAlertsSpeechToTextString] = []

    func clone() -> SettingsWidgetAlertsSpeechToText {
        let new = SettingsWidgetAlertsSpeechToText()
        for string in strings {
            new.strings.append(string.clone())
        }
        return new
    }
}

class SettingsWidgetAlerts: Codable {
    var twitch: SettingsWidgetAlertsTwitch = .init()
    var kick: SettingsWidgetAlertsKick = .init()
    var chatBot: SettingsWidgetAlertsChatBot = .init()
    var speechToText: SettingsWidgetAlertsSpeechToText = .init()
    var needsSubtitles: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case twitch,
             kick,
             chatBot,
             speechToText,
             needsSubtitles
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.twitch, twitch)
        try container.encode(.kick, kick)
        try container.encode(.chatBot, chatBot)
        try container.encode(.speechToText, speechToText)
        try container.encode(.needsSubtitles, needsSubtitles)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        twitch = container.decode(.twitch, SettingsWidgetAlertsTwitch.self, .init())
        kick = container.decode(.kick, SettingsWidgetAlertsKick.self, .init())
        chatBot = container.decode(.chatBot, SettingsWidgetAlertsChatBot.self, .init())
        speechToText = container.decode(.speechToText, SettingsWidgetAlertsSpeechToText.self, .init())
        needsSubtitles = container.decode(.needsSubtitles, Bool.self, false)
    }

    func clone() -> SettingsWidgetAlerts {
        let new = SettingsWidgetAlerts()
        new.twitch = twitch.clone()
        new.kick = kick.clone()
        new.chatBot = chatBot.clone()
        new.speechToText = speechToText.clone()
        new.needsSubtitles = needsSubtitles
        return new
    }
}

enum SettingsSceneSwitchTransition: String, Codable, CaseIterable {
    case blur = "Blur"
    case freeze = "Freeze"
    case blurAndZoom = "Blur & zoom"

    init(from decoder: Decoder) throws {
        self = try SettingsSceneSwitchTransition(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ??
            .blur
    }

    func toString() -> String {
        switch self {
        case .blur:
            return String(localized: "Blur")
        case .freeze:
            return String(localized: "Freeze")
        case .blurAndZoom:
            return String(localized: "Blur & zoom")
        }
    }

    func toVideoUnit() -> SceneSwitchTransition {
        switch self {
        case .blur:
            return .blur
        case .freeze:
            return .freeze
        case .blurAndZoom:
            return .blurAndZoom
        }
    }
}

class SettingsWidgetVTuber: Codable, ObservableObject {
    var id: UUID = .init()
    @Published var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    @Published var backCameraId: String = bestBackCameraId
    @Published var frontCameraId: String = bestFrontCameraId
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    @Published var externalCameraName: String = ""
    @Published var cameraPositionY: Double = 1.37
    @Published var cameraFieldOfView: Double = 18
    @Published var modelName: String = ""
    @Published var mirror: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             ristCameraId,
             rtspCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             cameraPositionY,
             cameraFieldOfView,
             modelName,
             mirror
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.cameraPositionY, cameraPositionY)
        try container.encode(.cameraFieldOfView, cameraFieldOfView)
        try container.encode(.modelName, modelName)
        try container.encode(.mirror, mirror)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        cameraPosition = decodeCameraPosition(container, .cameraPosition, .screenCapture)
        backCameraId = decodeCameraId(container, .backCameraId, bestBackCameraId)
        frontCameraId = decodeCameraId(container, .frontCameraId, bestFrontCameraId)
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        cameraPositionY = container.decode(.cameraPositionY, Double.self, 1.37)
        cameraFieldOfView = container.decode(.cameraFieldOfView, Double.self, 18)
        modelName = container.decode(.modelName, String.self, "")
        mirror = container.decode(.mirror, Bool.self, false)
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        case .none:
            return .none
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        case .none:
            cameraPosition = .none
        }
    }
}

class SettingsWidgetPngTuber: Codable, ObservableObject {
    var id: UUID = .init()
    @Published var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    @Published var backCameraId: String = bestBackCameraId
    @Published var frontCameraId: String = bestFrontCameraId
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    @Published var externalCameraName: String = ""
    @Published var modelName: String = ""
    @Published var mirror: Bool = false

    enum CodingKeys: CodingKey {
        case id,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             ristCameraId,
             rtspCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             modelName,
             mirror
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.modelName, modelName)
        try container.encode(.mirror, mirror)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        cameraPosition = decodeCameraPosition(container, .cameraPosition, .screenCapture)
        backCameraId = decodeCameraId(container, .backCameraId, bestBackCameraId)
        frontCameraId = decodeCameraId(container, .frontCameraId, bestFrontCameraId)
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        modelName = container.decode(.modelName, String.self, "")
        mirror = container.decode(.mirror, Bool.self, false)
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        case .none:
            return .none
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        case .none:
            cameraPosition = .none
        }
    }
}

class SettingsWidgetSnapshot: Codable, ObservableObject {
    var id: UUID = .init()
    @Published var showtime: Int = 5

    enum CodingKeys: CodingKey {
        case id,
             showtime
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.showtime, showtime)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        showtime = container.decode(.showtime, Int.self, 5)
    }
}

class SettingsWidget: Codable, Identifiable, Equatable, ObservableObject, Named {
    static let baseName = String(localized: "My widget")
    @Published var name: String
    var id: UUID = .init()
    @Published var type: SettingsWidgetType = .text
    var text: SettingsWidgetText = .init()
    var browser: SettingsWidgetBrowser = .init()
    var crop: SettingsWidgetCrop = .init()
    var map: SettingsWidgetMap = .init()
    var scene: SettingsWidgetScene = .init()
    var qrCode: SettingsWidgetQrCode = .init()
    var alerts: SettingsWidgetAlerts = .init()
    var videoSource: SettingsWidgetVideoSource = .init()
    var scoreboard: SettingsWidgetScoreboard = .init()
    var vTuber: SettingsWidgetVTuber = .init()
    var pngTuber: SettingsWidgetPngTuber = .init()
    var snapshot: SettingsWidgetSnapshot = .init()
    @Published var enabled: Bool = true
    @Published var effects: [SettingsVideoEffect] = []

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsWidget, rhs: SettingsWidget) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             type,
             text,
             browser,
             crop,
             map,
             scene,
             qrCode,
             alerts,
             videoSource,
             scoreboard,
             vTuber,
             pngTuber,
             snapshot,
             enabled,
             effects
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.type, type)
        try container.encode(.text, text)
        try container.encode(.browser, browser)
        try container.encode(.crop, crop)
        try container.encode(.map, map)
        try container.encode(.scene, scene)
        try container.encode(.qrCode, qrCode)
        try container.encode(.alerts, alerts)
        try container.encode(.videoSource, videoSource)
        try container.encode(.scoreboard, scoreboard)
        try container.encode(.vTuber, vTuber)
        try container.encode(.pngTuber, pngTuber)
        try container.encode(.snapshot, snapshot)
        try container.encode(.enabled, enabled)
        try container.encode(.effects, effects)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        type = container.decode(.type, SettingsWidgetType.self, .text)
        text = container.decode(.text, SettingsWidgetText.self, .init())
        browser = container.decode(.browser, SettingsWidgetBrowser.self, .init())
        crop = container.decode(.crop, SettingsWidgetCrop.self, .init())
        map = container.decode(.map, SettingsWidgetMap.self, .init())
        scene = container.decode(.scene, SettingsWidgetScene.self, .init())
        qrCode = container.decode(.qrCode, SettingsWidgetQrCode.self, .init())
        alerts = container.decode(.alerts, SettingsWidgetAlerts.self, .init())
        videoSource = container.decode(.videoSource, SettingsWidgetVideoSource.self, .init())
        scoreboard = container.decode(.scoreboard, SettingsWidgetScoreboard.self, .init())
        vTuber = container.decode(.vTuber, SettingsWidgetVTuber.self, .init())
        pngTuber = container.decode(.pngTuber, SettingsWidgetPngTuber.self, .init())
        snapshot = container.decode(.snapshot, SettingsWidgetSnapshot.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        effects = container.decode(.effects, [SettingsVideoEffect].self, [])
        migrateFromOlderVersions()
    }

    private func migrateFromOlderVersions() {
        if type == .videoSource, !effects.contains(where: { $0.type == .shape }) {
            let shape = SettingsVideoEffectShape()
            shape.cornerRadius = 0
            var updated = false
            if videoSource.cornerRadius != 0 || videoSource.borderWidth != 0 {
                shape.cornerRadius = videoSource.cornerRadius
                shape.borderWidth = videoSource.borderWidth
                shape.borderColor = videoSource.borderColor
                shape.borderColorColor = videoSource.borderColorColor
                updated = true
                videoSource.cornerRadius = 0
                videoSource.borderWidth = 0
            }
            if videoSource.cropEnabled, !videoSource.trackFaceEnabled {
                shape.cropEnabled = videoSource.cropEnabled
                shape.cropX = videoSource.cropX
                shape.cropY = videoSource.cropY
                shape.cropWidth = videoSource.cropWidth
                shape.cropHeight = videoSource.cropHeight
                updated = true
                videoSource.cropEnabled = false
            }
            if updated {
                let effect = SettingsVideoEffect()
                effect.type = .shape
                effect.shape = shape
                effects.append(effect)
            }
        }
    }

    func getEffects() -> [VideoEffect] {
        return effects.filter { $0.enabled }.map { $0.getEffect() }
    }

    func image() -> String {
        switch type {
        case .image:
            return "photo"
        case .browser:
            return "globe"
        case .text:
            return "textformat"
        case .crop:
            return "crop"
        case .map:
            return "map"
        case .scene:
            return "photo.on.rectangle"
        case .qrCode:
            return "qrcode"
        case .alerts:
            return "megaphone"
        case .videoSource:
            return "video"
        case .scoreboard:
            return "rectangle.split.2x1"
        case .vTuber:
            return "person.crop.circle"
        case .pngTuber:
            return "person.crop.circle.dashed"
        case .snapshot:
            return "camera.aperture"
        }
    }
}

class SettingsSceneWidget: Codable, Identifiable, Equatable, ObservableObject {
    static func == (lhs: SettingsSceneWidget, rhs: SettingsSceneWidget) -> Bool {
        return lhs.id == rhs.id
    }

    var id: UUID = .init()
    @Published var widgetId: UUID
    @Published var x: Double = 0.0
    @Published var xString: String = "0.0"
    @Published var y: Double = 0.0
    @Published var yString: String = "0.0"
    // To be removed.
    @Published var width2: Double = 100.0
    // To be removed.
    @Published var height2: Double = 100.0
    @Published var size: Double = 100.0
    @Published var sizeString: String = "100.0"
    @Published var alignment: SettingsAlignment = .topLeft
    var migrated: Bool = true
    var migrated2: Bool = true

    init(widgetId: UUID) {
        self.widgetId = widgetId
    }

    enum CodingKeys: CodingKey {
        case widgetId,
             id,
             x,
             y,
             width,
             height,
             size,
             alignment,
             migrated,
             migrated2
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.widgetId, widgetId)
        try container.encode(.id, id)
        try container.encode(.x, x)
        try container.encode(.y, y)
        try container.encode(.width, width2)
        try container.encode(.height, height2)
        try container.encode(.size, size)
        try container.encode(.alignment, alignment)
        try container.encode(.migrated, migrated)
        try container.encode(.migrated2, migrated2)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        widgetId = container.decode(.widgetId, UUID.self, .init())
        id = container.decode(.id, UUID.self, .init())
        x = container.decode(.x, Double.self, 0.0)
        xString = String(x)
        y = container.decode(.y, Double.self, 0.0)
        yString = String(y)
        width2 = container.decode(.width, Double.self, 100.0)
        height2 = container.decode(.height, Double.self, 100.0)
        if let size = container.decode(.size, Double?.self, nil) {
            self.size = size
        } else {
            size = container.decode(.size, Double.self, min(width2, height2))
        }
        sizeString = String(size)
        alignment = container.decode(.alignment, SettingsAlignment.self, .topLeft)
        migrated = container.decode(.migrated, Bool.self, false)
        migrated2 = container.decode(.migrated2, Bool.self, false)
    }

    func clone() -> SettingsSceneWidget {
        let new = SettingsSceneWidget(widgetId: widgetId)
        new.x = x
        new.xString = xString
        new.y = y
        new.yString = yString
        new.size = size
        new.sizeString = sizeString
        new.alignment = alignment
        new.migrated = migrated
        new.migrated2 = migrated2
        return new
    }

    func isSamePositioning(other: SettingsSceneWidget) -> Bool {
        return x == other.x && y == other.y && size == other.size
    }

    func extent() -> CGRect {
        return .init(x: x, y: y, width: size, height: size)
    }
}

enum SettingsSceneCameraPosition: String, Codable, CaseIterable {
    case back = "Back"
    case front = "Front"
    case rtmp = "RTMP"
    case external = "External"
    case srtla = "SRT(LA)"
    case rist = "RIST"
    case rtsp = "RTSP"
    case mediaPlayer = "Media player"
    case screenCapture = "Screen capture"
    case backTripleLowEnergy = "Back triple"
    case backDualLowEnergy = "Back dual"
    case backWideDualLowEnergy = "Back wide dual"
    case none = "None"

    init(from decoder: Decoder) throws {
        self = try SettingsSceneCameraPosition(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .back
    }

    func isBuiltin() -> Bool {
        return builtinCameraPositions.contains(self)
    }
}

private let builtinCameraPositions: [SettingsSceneCameraPosition] = [
    .back,
    .front,
    .backTripleLowEnergy,
    .backDualLowEnergy,
    .backWideDualLowEnergy,
]

class SettingsWidgetVideoSource: Codable, ObservableObject {
    @Published var cornerRadius: Float = 0
    @Published var cameraPosition: SettingsSceneCameraPosition = .screenCapture
    @Published var backCameraId: String = bestBackCameraId
    @Published var frontCameraId: String = bestFrontCameraId
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    @Published var externalCameraName: String = ""
    var cropEnabled: Bool = false
    var cropX: Double = 0.25
    var cropY: Double = 0.0
    var cropWidth: Double = 0.5
    var cropHeight: Double = 1.0
    @Published var rotation: Double = 0.0
    var trackFaceEnabled: Bool = false
    @Published var trackFaceZoom: Double = 0.75
    var mirror: Bool = false
    @Published var borderWidth: Double = 0
    var borderColor: RgbColor = .init(red: 0, green: 0, blue: 0)
    @Published var borderColorColor: Color

    enum CodingKeys: CodingKey {
        case cornerRadius,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             ristCameraId,
             rtspCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             cropEnabled,
             cropX,
             cropY,
             cropWidth,
             cropHeight,
             rotation,
             trackFaceEnabled,
             trackFaceZoom,
             mirror,
             borderWidth,
             borderColor
    }

    init() {
        borderColorColor = borderColor.color()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.cornerRadius, cornerRadius)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.cropEnabled, cropEnabled)
        try container.encode(.cropX, cropX)
        try container.encode(.cropY, cropY)
        try container.encode(.cropWidth, cropWidth)
        try container.encode(.cropHeight, cropHeight)
        try container.encode(.rotation, rotation)
        try container.encode(.trackFaceEnabled, trackFaceEnabled)
        try container.encode(.trackFaceZoom, trackFaceZoom)
        try container.encode(.mirror, mirror)
        try container.encode(.borderWidth, borderWidth)
        try container.encode(.borderColor, borderColor)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cornerRadius = container.decode(.cornerRadius, Float.self, 0)
        cameraPosition = decodeCameraPosition(container, .cameraPosition, .screenCapture)
        backCameraId = decodeCameraId(container, .backCameraId, bestBackCameraId)
        frontCameraId = decodeCameraId(container, .frontCameraId, bestFrontCameraId)
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        cropEnabled = container.decode(.cropEnabled, Bool.self, false)
        cropX = container.decode(.cropX, Double.self, 0.25)
        cropY = container.decode(.cropY, Double.self, 0.0)
        cropWidth = container.decode(.cropWidth, Double.self, 0.5)
        cropHeight = container.decode(.cropHeight, Double.self, 1.0)
        rotation = container.decode(.rotation, Double.self, 0.0)
        trackFaceEnabled = container.decode(.trackFaceEnabled, Bool.self, false)
        trackFaceZoom = container.decode(.trackFaceZoom, Double.self, 0.75)
        mirror = container.decode(.mirror, Bool.self, false)
        borderWidth = container.decode(.borderWidth, Double.self, 0)
        borderColor = container.decode(.borderColor, RgbColor.self, .init(red: 0, green: 0, blue: 0))
        borderColorColor = borderColor.color()
    }

    func toEffectSettings() -> VideoSourceEffectSettings {
        return .init(rotation: rotation,
                     trackFaceEnabled: trackFaceEnabled,
                     trackFaceZoom: 1.5 + (1 - trackFaceZoom) * 4,
                     mirror: mirror)
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        case .none:
            return .none
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        case .none:
            cameraPosition = .none
        }
    }
}

enum SettingsWidgetScoreboardType: String, Codable, CaseIterable {
    case padel = "Padel"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetScoreboardType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .padel
    }

    func toString() -> String {
        switch self {
        case .padel:
            return String(localized: "Padel")
        }
    }
}

class SettingsWidgetScoreboardPlayer: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "🇸🇪 Moblin")
    var id: UUID = .init()
    @Published var name: String = baseName

    enum CodingKeys: CodingKey {
        case id,
             name
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
    }
}

class SettingsWidgetScoreboardScore: Codable, Identifiable {
    var home: Int = 0
    var away: Int = 0
}

enum SettingsWidgetPadelScoreboardGameType: String, Codable, CaseIterable {
    case doubles = "Double"
    case singles = "Single"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetPadelScoreboardGameType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ??
            .doubles
    }

    func toString() -> String {
        switch self {
        case .doubles:
            return String(localized: "Doubles")
        case .singles:
            return String(localized: "Singles")
        }
    }
}

enum SettingsWidgetPadelScoreboardScoreIncrement {
    case home
    case away
}

class SettingsWidgetPadelScoreboard: Codable, ObservableObject {
    var type: SettingsWidgetPadelScoreboardGameType = .doubles
    var homePlayer1: UUID = .init()
    var homePlayer2: UUID = .init()
    var awayPlayer1: UUID = .init()
    var awayPlayer2: UUID = .init()
    var score: [SettingsWidgetScoreboardScore] = [.init()]
    var scoreChanges: [SettingsWidgetPadelScoreboardScoreIncrement] = []

    enum CodingKeys: CodingKey {
        case type,
             homePlayer1,
             homePlayer2,
             awayPlayer1,
             awayPlayer2,
             score
    }

    init() {}

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.type, type)
        try container.encode(.homePlayer1, homePlayer1)
        try container.encode(.homePlayer2, homePlayer2)
        try container.encode(.awayPlayer1, awayPlayer1)
        try container.encode(.awayPlayer2, awayPlayer2)
        try container.encode(.score, score)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = container.decode(.type, SettingsWidgetPadelScoreboardGameType.self, .doubles)
        homePlayer1 = container.decode(.homePlayer1, UUID.self, .init())
        homePlayer2 = container.decode(.homePlayer2, UUID.self, .init())
        awayPlayer1 = container.decode(.awayPlayer1, UUID.self, .init())
        awayPlayer2 = container.decode(.awayPlayer2, UUID.self, .init())
        score = container.decode(.score, [SettingsWidgetScoreboardScore].self, [.init()])
    }
}

class SettingsWidgetScoreboard: Codable {
    var type: SettingsWidgetScoreboardType = .padel
    var padel: SettingsWidgetPadelScoreboard = .init()
}

enum SettingsWidgetVideoEffectType: String, Codable, CaseIterable {
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case bloom = "Bloom"
    case random = "Random"
    case triple = "Triple"
    case noiseReduction = "Noise reduction"
    case pixellate = "Pixellate"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetVideoEffectType(rawValue: decoder.singleValueContainer()
            .decode(RawValue.self)) ?? .movie
    }
}

enum SettingsWidgetType: String, Codable, CaseIterable {
    case text = "Text"
    case browser = "Browser"
    case videoSource = "Video source"
    case image = "Image"
    case alerts = "Alerts"
    case map = "Map"
    case snapshot = "Snapshot"
    case scene = "Scene"
    case vTuber = "VTuber"
    case pngTuber = "PNGTuber"
    case qrCode = "QR code"
    case scoreboard = "Scoreboard"
    case crop = "Crop"

    init(from decoder: Decoder) throws {
        self = try SettingsWidgetType(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .text
    }

    func toString() -> String {
        switch self {
        case .text:
            return String(localized: "Text")
        case .browser:
            return String(localized: "Browser")
        case .videoSource:
            return String(localized: "Video source")
        case .image:
            return String(localized: "Image")
        case .alerts:
            return String(localized: "Alerts")
        case .map:
            return String(localized: "Map")
        case .snapshot:
            return String(localized: "Snapshot")
        case .scene:
            return String(localized: "Scene")
        case .vTuber:
            return String(localized: "VTuber")
        case .pngTuber:
            return String(localized: "PNGTuber")
        case .qrCode:
            return String(localized: "QR code")
        case .scoreboard:
            return String(localized: "Scoreboard")
        case .crop:
            return String(localized: "Crop")
        }
    }
}

let widgetTypes = SettingsWidgetType.allCases

class SettingsScene: Codable, Identifiable, Equatable, ObservableObject, Named {
    static let baseName = String(localized: "My scene")
    @Published var name: String
    var id: UUID = .init()
    @Published var enabled: Bool = true
    @Published var cameraPosition: SettingsSceneCameraPosition = defaultBackCameraPosition
    @Published var backCameraId: String = bestBackCameraId
    @Published var frontCameraId: String = bestFrontCameraId
    @Published var rtmpCameraId: UUID = .init()
    @Published var srtlaCameraId: UUID = .init()
    @Published var ristCameraId: UUID = .init()
    @Published var rtspCameraId: UUID = .init()
    @Published var mediaPlayerCameraId: UUID = .init()
    @Published var externalCameraId: String = ""
    var externalCameraName: String = ""
    @Published var widgets: [SettingsSceneWidget] = []
    @Published var videoSourceRotation: Double = 0.0
    @Published var videoStabilizationMode: SettingsVideoStabilizationMode = .off
    @Published var overrideVideoStabilizationMode: Bool = false
    @Published var fillFrame: Bool = false
    @Published var overrideMic: Bool = false
    @Published var micId: String = ""

    init(name: String) {
        self.name = name
    }

    static func == (lhs: SettingsScene, rhs: SettingsScene) -> Bool {
        return lhs.id == rhs.id
    }

    enum CodingKeys: CodingKey {
        case name,
             id,
             enabled,
             cameraType,
             cameraPosition,
             backCameraId,
             frontCameraId,
             rtmpCameraId,
             srtlaCameraId,
             ristCameraId,
             rtspCameraId,
             mediaPlayerCameraId,
             externalCameraId,
             externalCameraName,
             widgets,
             videoSourceRotation,
             videoStabilizationMode,
             overrideVideoStabilizationMode,
             fillFrame,
             overrideMic,
             micId
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.name, name)
        try container.encode(.id, id)
        try container.encode(.enabled, enabled)
        try container.encode(.cameraPosition, cameraPosition)
        try container.encode(.backCameraId, backCameraId)
        try container.encode(.frontCameraId, frontCameraId)
        try container.encode(.rtmpCameraId, rtmpCameraId)
        try container.encode(.srtlaCameraId, srtlaCameraId)
        try container.encode(.ristCameraId, ristCameraId)
        try container.encode(.rtspCameraId, rtspCameraId)
        try container.encode(.mediaPlayerCameraId, mediaPlayerCameraId)
        try container.encode(.externalCameraId, externalCameraId)
        try container.encode(.externalCameraName, externalCameraName)
        try container.encode(.widgets, widgets)
        try container.encode(.videoSourceRotation, videoSourceRotation)
        try container.encode(.videoStabilizationMode, videoStabilizationMode)
        try container.encode(.overrideVideoStabilizationMode, overrideVideoStabilizationMode)
        try container.encode(.fillFrame, fillFrame)
        try container.encode(.overrideMic, overrideMic)
        try container.encode(.micId, micId)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = container.decode(.name, String.self, "")
        id = container.decode(.id, UUID.self, .init())
        enabled = container.decode(.enabled, Bool.self, true)
        cameraPosition = decodeCameraPosition(container, .cameraPosition, defaultBackCameraPosition)
        backCameraId = decodeCameraId(container, .backCameraId, bestBackCameraId)
        frontCameraId = decodeCameraId(container, .frontCameraId, bestFrontCameraId)
        rtmpCameraId = container.decode(.rtmpCameraId, UUID.self, .init())
        srtlaCameraId = container.decode(.srtlaCameraId, UUID.self, .init())
        ristCameraId = container.decode(.ristCameraId, UUID.self, .init())
        rtspCameraId = container.decode(.rtspCameraId, UUID.self, .init())
        mediaPlayerCameraId = container.decode(.mediaPlayerCameraId, UUID.self, .init())
        externalCameraId = container.decode(.externalCameraId, String.self, "")
        externalCameraName = container.decode(.externalCameraName, String.self, "")
        widgets = container.decode(.widgets, [SettingsSceneWidget].self, [])
        videoSourceRotation = container.decode(.videoSourceRotation, Double.self, 0.0)
        videoStabilizationMode = container.decode(.videoStabilizationMode, SettingsVideoStabilizationMode.self, .off)
        overrideVideoStabilizationMode = container.decode(.overrideVideoStabilizationMode, Bool.self, false)
        fillFrame = container.decode(.fillFrame, Bool.self, false)
        overrideMic = container.decode(.overrideMic, Bool.self, false)
        micId = container.decode(.micId, String.self, "")
    }

    func clone() -> SettingsScene {
        let new = SettingsScene(name: name)
        new.enabled = enabled
        new.cameraPosition = cameraPosition
        new.backCameraId = backCameraId
        new.frontCameraId = frontCameraId
        new.rtmpCameraId = rtmpCameraId
        new.srtlaCameraId = srtlaCameraId
        new.ristCameraId = ristCameraId
        new.rtspCameraId = rtspCameraId
        new.mediaPlayerCameraId = mediaPlayerCameraId
        new.externalCameraId = externalCameraId
        new.externalCameraName = externalCameraName
        for widget in widgets {
            new.widgets.append(widget.clone())
        }
        new.videoSourceRotation = videoSourceRotation
        new.videoStabilizationMode = videoStabilizationMode
        new.overrideVideoStabilizationMode = overrideVideoStabilizationMode
        new.fillFrame = fillFrame
        new.overrideMic = overrideMic
        new.micId = micId
        return new
    }

    func toCameraId() -> SettingsCameraId {
        switch cameraPosition {
        case .back:
            return .back(id: backCameraId)
        case .front:
            return .front(id: frontCameraId)
        case .rtmp:
            return .rtmp(id: rtmpCameraId)
        case .external:
            return .external(id: externalCameraId, name: externalCameraName)
        case .srtla:
            return .srtla(id: srtlaCameraId)
        case .rist:
            return .rist(id: ristCameraId)
        case .rtsp:
            return .rtsp(id: rtspCameraId)
        case .mediaPlayer:
            return .mediaPlayer(id: mediaPlayerCameraId)
        case .screenCapture:
            return .screenCapture
        case .backTripleLowEnergy:
            return .backTripleLowEnergy
        case .backDualLowEnergy:
            return .backDualLowEnergy
        case .backWideDualLowEnergy:
            return .backWideDualLowEnergy
        case .none:
            return .none
        }
    }

    func updateCameraId(settingsCameraId: SettingsCameraId) {
        switch settingsCameraId {
        case let .back(id: id):
            cameraPosition = .back
            backCameraId = id
        case let .front(id: id):
            cameraPosition = .front
            frontCameraId = id
        case let .rtmp(id: id):
            cameraPosition = .rtmp
            rtmpCameraId = id
        case let .srtla(id: id):
            cameraPosition = .srtla
            srtlaCameraId = id
        case let .rist(id: id):
            cameraPosition = .rist
            ristCameraId = id
        case let .rtsp(id: id):
            cameraPosition = .rtsp
            rtspCameraId = id
        case let .mediaPlayer(id: id):
            cameraPosition = .mediaPlayer
            mediaPlayerCameraId = id
        case let .external(id: id, name: name):
            cameraPosition = .external
            externalCameraId = id
            externalCameraName = name
        case .screenCapture:
            cameraPosition = .screenCapture
        case .backTripleLowEnergy:
            cameraPosition = .backTripleLowEnergy
        case .backDualLowEnergy:
            cameraPosition = .backDualLowEnergy
        case .backWideDualLowEnergy:
            cameraPosition = .backWideDualLowEnergy
        case .none:
            cameraPosition = .none
        }
    }
}

class SettingsAutoSceneSwitcherScene: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var sceneId: UUID?
    @Published var time: Int = 15

    enum CodingKeys: CodingKey {
        case id,
             sceneId,
             time
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.sceneId, sceneId)
        try container.encode(.time, time)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        time = container.decode(.time, Int.self, 15)
    }
}

class SettingsAutoSceneSwitcher: Codable, Identifiable, ObservableObject, Named {
    static let baseName = String(localized: "My switcher")
    var id: UUID = .init()
    @Published var name: String = baseName
    @Published var shuffle: Bool = false
    @Published var scenes: [SettingsAutoSceneSwitcherScene] = []

    enum CodingKeys: CodingKey {
        case id,
             name,
             shuffle,
             scenes
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.shuffle, shuffle)
        try container.encode(.scenes, scenes)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, Self.baseName)
        shuffle = container.decode(.shuffle, Bool.self, false)
        scenes = container.decode(.scenes, [SettingsAutoSceneSwitcherScene].self, [])
    }
}

class SettingsAutoSceneSwitchers: Codable, Identifiable, ObservableObject {
    @Published var switcherId: UUID?
    @Published var switchers: [SettingsAutoSceneSwitcher] = []

    enum CodingKeys: CodingKey {
        case switcherId, switchers
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.switcherId, switcherId)
        try container.encode(.switchers, switchers)
    }

    init() {}

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switcherId = try? container.decode(UUID?.self, forKey: .switcherId)
        switchers = container.decode(.switchers, [SettingsAutoSceneSwitcher].self, [])
    }
}
