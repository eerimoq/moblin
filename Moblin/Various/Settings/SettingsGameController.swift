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
            String(localized: "Kapow")
        case .yes:
            String(localized: "Yes")
        case .no:
            String(localized: "No")
        case .wakeup:
            String(localized: "Wakeup")
        }
    }

    @available(iOS 18, *)
    func toSystem() -> DockAccessory.Animation {
        switch self {
        case .kapow:
            .kapow
        case .yes:
            .yes
        case .no:
            .no
        case .wakeup:
            .wakeup
        }
    }
}

enum SettingsControllerThumbStickFunction: String, Codable, CaseIterable {
    case unused = "Unused"
    case gimbalPanTilt = "Gimbal pan and tilt"

    func toString() -> String {
        switch self {
        case .unused:
            String(localized: "Unused")
        case .gimbalPanTilt:
            String(localized: "Gimbal pan and tilt")
        }
    }

    func color() -> Color {
        switch self {
        case .unused:
            .gray
        default:
            .primary
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
    case gimbalTracking = "Gimbal tracking"
    case mute = "Mute"
    case torch = "Torch"
    case blackScreen = "Black screen"
    case scene = "Scene"
    case switchScene = "Switch scene"
    case widget = "Widget"
    case macro = "Macro"
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
            String(localized: "Unused")
        case .record:
            String(localized: "Record")
        case .stream:
            String(localized: "Stream")
        case .zoomIn:
            String(localized: "Zoom in")
        case .zoomOut:
            String(localized: "Zoom out")
        case .gimbalUp:
            String(localized: "Gimbal up")
        case .gimbalDown:
            String(localized: "Gimbal down")
        case .gimbalLeft:
            String(localized: "Gimbal left")
        case .gimbalRight:
            String(localized: "Gimbal right")
        case .gimbalPreset:
            String(localized: "Gimbal preset")
        case .gimbalAnimate:
            String(localized: "Gimbal animate")
        case .gimbalTracking:
            String(localized: "Gimbal tracking")
        case .mute:
            String(localized: "Mute")
        case .torch:
            String(localized: "Torch")
        case .blackScreen:
            String(localized: "Stealth mode")
        case .scene:
            String(localized: "Scene")
        case .switchScene:
            String(localized: "Switch scene")
        case .widget:
            String(localized: "Widget")
        case .macro:
            String(localized: "Macro")
        case .instantReplay:
            String(localized: "Instant replay")
        case .stopReplay:
            String(localized: "Stop replay")
        case .snapshot:
            String(localized: "Snapshot")
        case .pauseTts:
            String(localized: "Pause TTS")
        case .pixellate:
            String(localized: "Pixellate")
        case .movie:
            String(localized: "Movie")
        case .grayScale:
            String(localized: "Gray scale")
        case .sepia:
            String(localized: "Sepia")
        case .triple:
            String(localized: "Triple")
        case .twin:
            String(localized: "Twin")
        case .fourThree:
            String(localized: "4:3")
        case .pinch:
            String(localized: "Pinch")
        case .whirlpool:
            String(localized: "Whirlpool")
        case .poll:
            String(localized: "Poll")
        case .blurFaces:
            String(localized: "Blur faces")
        case .privacy:
            String(localized: "Blur background")
        case .beauty:
            String(localized: "Beauty")
        case .cameraMan:
            String(localized: "Camera man")
        }
    }

    func toString(sceneName: String?, widgetName: String?) -> String {
        switch self {
        case .scene:
            if let sceneName {
                String(localized: "\(sceneName) scene")
            } else {
                String(localized: "Scene")
            }
        case .widget:
            if let widgetName {
                String(localized: "\(widgetName) widget")
            } else {
                String(localized: "Widget")
            }
        default:
            toString()
        }
    }

    func color() -> Color {
        switch self {
        case .unused:
            .gray
        default:
            .primary
        }
    }

    func section() -> SettingsControllerFunctionSection {
        switch self {
        case .unused:
            .general
        case .record:
            .general
        case .stream:
            .general
        case .zoomIn:
            .general
        case .zoomOut:
            .general
        case .gimbalUp:
            .general
        case .gimbalDown:
            .general
        case .gimbalLeft:
            .general
        case .gimbalRight:
            .general
        case .gimbalPreset:
            .general
        case .gimbalAnimate:
            .general
        case .gimbalTracking:
            .general
        case .mute:
            .general
        case .torch:
            .general
        case .blackScreen:
            .general
        case .scene:
            .general
        case .switchScene:
            .general
        case .widget:
            .general
        case .macro:
            .general
        case .instantReplay:
            .general
        case .stopReplay:
            .general
        case .snapshot:
            .general
        case .pauseTts:
            .general
        case .pixellate:
            .filters
        case .movie:
            .filters
        case .grayScale:
            .filters
        case .sepia:
            .filters
        case .triple:
            .filters
        case .twin:
            .filters
        case .fourThree:
            .filters
        case .pinch:
            .filters
        case .whirlpool:
            .filters
        case .poll:
            .filters
        case .blurFaces:
            .filters
        case .privacy:
            .filters
        case .beauty:
            .filters
        case .cameraMan:
            .filters
        }
    }
}

struct SettingsControllerFunctionData {
    var sceneId: UUID?
    var widgetId: UUID?
    var gimbalPresetId: UUID?
    var gimbalMotion: SettingsGimbalMotion = .kapow
    var macroId: UUID?
}

class SettingsGameControllerButton: Codable, Identifiable, ObservableObject {
    var id: UUID = .init()
    var name: String = ""
    var text: String = ""
    @Published var function: SettingsControllerFunction = .unused
    @Published var functionData: SettingsControllerFunctionData = .init()

    init() {}

    enum CodingKeys: CodingKey {
        case id,
             name,
             text,
             function,
             sceneId,
             widgetId,
             gimbalPresetId,
             gimbalMotion,
             macroId
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.name, name)
        try container.encode(.text, text)
        try container.encode(.function, function)
        try container.encode(.sceneId, functionData.sceneId)
        try container.encode(.widgetId, functionData.widgetId)
        try container.encode(.gimbalPresetId, functionData.gimbalPresetId)
        try container.encode(.gimbalMotion, functionData.gimbalMotion)
        try container.encode(.macroId, functionData.macroId)
    }

    required init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decode(.id, UUID.self, .init())
        name = container.decode(.name, String.self, "")
        text = container.decode(.text, String.self, "")
        function = container.decode(.function, SettingsControllerFunction.self, .unused)
        functionData.sceneId = container.decode(.sceneId, UUID?.self, nil)
        functionData.widgetId = container.decode(.widgetId, UUID?.self, nil)
        functionData.gimbalPresetId = container.decode(.gimbalPresetId, UUID?.self, nil)
        functionData.gimbalMotion = container.decode(.gimbalMotion, SettingsGimbalMotion.self, .kapow)
        functionData.macroId = container.decode(.macroId, UUID?.self, nil)
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

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(.id, id)
        try container.encode(.buttons, buttons)
        try container.encode(.leftThumbStickFunction, leftThumbStickFunction)
        try container.encode(.rightThumbStickFunction, rightThumbStickFunction)
    }

    required init(from decoder: any Decoder) throws {
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
