import DockKit
import Foundation
import SwiftUI

enum SettingsControllerFunctionSection {
    case general
    case filters
}

enum SettingsGimbalMotion: Codable, CaseIterable {
    case kapow
    case yes
    case no
    case wakeup

    func toString() -> String {
        switch self {
        case .kapow:
            return String(localized: "Kapow")
        case .yes:
            return String(localized: "Yes")
        case .no:
            return String(localized: "No")
        case .wakeup:
            return String(localized: "Wakeup")
        }
    }

    @available(iOS 18, *)
    func toSystem() -> DockAccessory.Animation {
        switch self {
        case .kapow:
            return .kapow
        case .yes:
            return .yes
        case .no:
            return .no
        case .wakeup:
            return .wakeup
        }
    }
}

enum SettingsControllerThumbStickFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case gimbalPanTilt = "Gimbal pan and tilt"

    func toString() -> String {
        switch self {
        case .unused:
            return String(localized: "Unused")
        case .gimbalPanTilt:
            return String(localized: "Gimbal pan and tilt")
        }
    }

    func color() -> Color {
        switch self {
        case .unused:
            return .gray
        default:
            return .primary
        }
    }
}

enum SettingsControllerFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case record = "Record"
    case stream = "Stream"
    case zoomIn = "Zoom in"
    case zoomOut = "Zoom out"
    case gimbalUp = "Gimbal up"
    case gimbalDown = "Gimbal down"
    case gimbalLeft = "Gimbal left"
    case gimbalRight = "Gimbal right"
    case gimbalPreset = "Gimbal preset"
    case gimbalAnimate = "Gimbal animate"
    case mute = "Mute"
    case torch = "Torch"
    case blackScreen = "Black screen"
    case scene = "Scene"
    case switchScene = "Switch scene"
    case widget = "Widget"
    case instantReplay = "Instant replay"
    case stopReplay = "Stop replay"
    case snapshot = "Snapshot"
    case pauseTts = "Pause TTS"
    case pixellate = "Pixellate"
    case movie = "Movie"
    case grayScale = "Gray scale"
    case sepia = "Sepia"
    case triple = "Triple"
    case twin = "Twin"
    case fourThree = "4:3"
    case pinch = "Pinch"
    case whirlpool = "Whirlpool"
    case poll = "Poll"
    case blurFaces = "Blur faces"
    case privacy = "Privacy"
    case beauty = "Beauty"
    case cameraMan = "Camera man"

    func toString() -> String {
        switch self {
        case .unused:
            return String(localized: "Unused")
        case .record:
            return String(localized: "Record")
        case .stream:
            return String(localized: "Stream")
        case .zoomIn:
            return String(localized: "Zoom in")
        case .zoomOut:
            return String(localized: "Zoom out")
        case .gimbalUp:
            return String(localized: "Gimbal up")
        case .gimbalDown:
            return String(localized: "Gimbal down")
        case .gimbalLeft:
            return String(localized: "Gimbal left")
        case .gimbalRight:
            return String(localized: "Gimbal right")
        case .gimbalPreset:
            return String(localized: "Gimbal preset")
        case .gimbalAnimate:
            return String(localized: "Gimbal animate")
        case .mute:
            return String(localized: "Mute")
        case .torch:
            return String(localized: "Torch")
        case .blackScreen:
            return String(localized: "Stealth mode")
        case .scene:
            return String(localized: "Scene")
        case .switchScene:
            return String(localized: "Switch scene")
        case .widget:
            return String(localized: "Widget")
        case .instantReplay:
            return String(localized: "Instant replay")
        case .stopReplay:
            return String(localized: "Stop replay")
        case .snapshot:
            return String(localized: "Snapshot")
        case .pauseTts:
            return String(localized: "Pause TTS")
        case .pixellate:
            return String(localized: "Pixellate")
        case .movie:
            return String(localized: "Movie")
        case .grayScale:
            return String(localized: "Gray scale")
        case .sepia:
            return String(localized: "Sepia")
        case .triple:
            return String(localized: "Triple")
        case .twin:
            return String(localized: "Twin")
        case .fourThree:
            return String(localized: "4:3")
        case .pinch:
            return String(localized: "Pinch")
        case .whirlpool:
            return String(localized: "Whirlpool")
        case .poll:
            return String(localized: "Poll")
        case .blurFaces:
            return String(localized: "Blur faces")
        case .privacy:
            return String(localized: "Blur background")
        case .beauty:
            return String(localized: "Beauty")
        case .cameraMan:
            return String(localized: "Camera man")
        }
    }

    func toString(sceneName: String?, widgetName: String?) -> String {
        switch self {
        case .scene:
            if let sceneName {
                return String(localized: "\(sceneName) scene")
            } else {
                return String(localized: "Scene")
            }
        case .widget:
            if let widgetName {
                return String(localized: "\(widgetName) widget")
            } else {
                return String(localized: "Widget")
            }
        default:
            return toString()
        }
    }

    func color() -> Color {
        switch self {
        case .unused:
            return .gray
        default:
            return .primary
        }
    }

    func section() -> SettingsControllerFunctionSection {
        switch self {
        case .unused:
            return .general
        case .record:
            return .general
        case .stream:
            return .general
        case .zoomIn:
            return .general
        case .zoomOut:
            return .general
        case .gimbalUp:
            return .general
        case .gimbalDown:
            return .general
        case .gimbalLeft:
            return .general
        case .gimbalRight:
            return .general
        case .gimbalPreset:
            return .general
        case .gimbalAnimate:
            return .general
        case .mute:
            return .general
        case .torch:
            return .general
        case .blackScreen:
            return .general
        case .scene:
            return .general
        case .switchScene:
            return .general
        case .widget:
            return .general
        case .instantReplay:
            return .general
        case .stopReplay:
            return .general
        case .snapshot:
            return .general
        case .pauseTts:
            return .general
        case .pixellate:
            return .filters
        case .movie:
            return .filters
        case .grayScale:
            return .filters
        case .sepia:
            return .filters
        case .triple:
            return .filters
        case .twin:
            return .filters
        case .fourThree:
            return .filters
        case .pinch:
            return .filters
        case .whirlpool:
            return .filters
        case .poll:
            return .filters
        case .blurFaces:
            return .filters
        case .privacy:
            return .filters
        case .beauty:
            return .filters
        case .cameraMan:
            return .filters
        }
    }
}

class SettingsGameControllerButton: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var name: String = ""
    var text: String = ""
    @Published var function: SettingsControllerFunction = .unused
    @Published var sceneId: UUID?
    @Published var widgetId: UUID?
    @Published var gimbalPresetId: UUID?
    @Published var gimbalMotion: SettingsGimbalMotion = .kapow

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             text,
             function,
             sceneId,
             widgetId,
             gimbalPresetId,
             gimbalMotion
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.text, text)
        try container.encode(.function, function)
        try container.encode(.sceneId, sceneId)
        try container.encode(.widgetId, widgetId)
        try container.encode(.gimbalPresetId, gimbalPresetId)
        try container.encode(.gimbalMotion, gimbalMotion)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        text = container.decode(.text, String.self, "")
        function = container.decode(.function, SettingsControllerFunction.self, .unused)
        sceneId = container.decode(.sceneId, UUID?.self, nil)
        widgetId = container.decode(.widgetId, UUID?.self, nil)
        gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        gimbalMotion = container.decode(.gimbalMotion, SettingsGimbalMotion.self, .kapow)
    }
}

class SettingsGameController: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    @Published var buttons: [SettingsGameControllerButton] = []
    @Published var leftThumbStickFunction: SettingsControllerThumbStickFunction = .unused
    @Published var rightThumbStickFunction: SettingsControllerThumbStickFunction = .unused

    init() {
        var button = SettingsGameControllerButton()
        button.name = "dpad.left.fill"
        button.text = String(localized: "Left")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.right.fill"
        button.text = String(localized: "Right")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.up.fill"
        button.text = String(localized: "Up")
        button.function = .zoomIn
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "dpad.down.fill"
        button.text = String(localized: "Down")
        button.function = .zoomOut
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "a.circle"
        button.text = "A"
        button.function = .torch
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "b.circle"
        button.text = "B"
        button.function = .mute
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "x.circle"
        button.text = "X"
        button.function = .blackScreen
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "y.circle"
        button.text = "Y"
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "circle.circle"
        button.text = String(localized: "Circle")
        button.function = .torch
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "xmark.circle"
        button.text = String(localized: "X mark")
        button.function = .mute
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "square.circle"
        button.text = String(localized: "Square")
        button.function = .blackScreen
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "triangle.circle"
        button.text = String(localized: "Triangle")
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "zl.rectangle.roundedtop"
        button.text = "ZL"
        button.function = .stream
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l.rectangle.roundedbottom"
        button.text = "L"
        button.function = .record
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "zr.rectangle.roundedtop"
        button.text = "ZR"
        button.function = .instantReplay
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r.rectangle.roundedbottom"
        button.text = "R"
        button.function = .snapshot
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l2.rectangle.roundedtop"
        button.text = "L2"
        button.function = .stream
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "l1.rectangle.roundedbottom"
        button.text = "L1"
        button.function = .record
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r2.rectangle.roundedtop"
        button.text = "R2"
        button.function = .pixellate
        buttons.append(button)
        button = SettingsGameControllerButton()
        button.name = "r1.rectangle.roundedbottom"
        button.text = "R1"
        button.function = .triple
        buttons.append(button)
    }

    enum CodingKeys: CodingKey {
        case id,
             buttons,
             leftThumbStickFunction,
             rightThumbStickFunction
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.buttons, buttons)
        try container.encode(.leftThumbStickFunction, leftThumbStickFunction)
        try container.encode(.rightThumbStickFunction, rightThumbStickFunction)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        buttons = container.decode(.buttons, [SettingsGameControllerButton].self, [])
        leftThumbStickFunction = container.decode(
            .leftThumbStickFunction,
            SettingsControllerThumbStickFunction.self,
            .unused
        )
        rightThumbStickFunction = container.decode(
            .rightThumbStickFunction,
            SettingsControllerThumbStickFunction.self,
            .unused
        )
    }
}
