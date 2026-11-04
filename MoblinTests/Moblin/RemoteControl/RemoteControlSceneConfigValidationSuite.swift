import Foundation
@testable import Moblin
import Testing

private func roundTrip<T: Codable>(_ value: T) -> T {
    try! JSONDecoder().decode(T.self, from: JSONEncoder().encode(value))
}

private func modified<T: Codable>(_ value: T, _ edit: (T) -> Void = { _ in }) -> T {
    let value = roundTrip(value)
    edit(value)
    return value
}

private func cameraId(_ videoSource: SettingsVideoSource) -> CameraId {
    String(describing: videoSource.toCameraId())
}

private func emptyWidget(_ type: SettingsWidgetType) -> SettingsWidget {
    let widget = SettingsWidget(name: "New")
    widget.type = type
    return widget
}

private func emptyScene(_ scene: SettingsScene) -> SettingsScene {
    let newScene = SettingsScene(name: scene.name)
    newScene.id = scene.id
    return newScene
}

private func replacing(_ scenes: [SettingsScene], _ scene: SettingsScene) -> [SettingsScene] {
    scenes.map { $0.id == scene.id ? scene : $0 }
}

private func sceneWidget(_ widgetId: UUID, x: Double = 0, y: Double = 0,
                         size: Double = 10) -> SettingsSceneWidget
{
    let sceneWidget = SettingsSceneWidget(widgetId: widgetId)
    sceneWidget.layout.x = x
    sceneWidget.layout.y = y
    sceneWidget.layout.size = size
    return sceneWidget
}

private func timer(delta: Int) -> SettingsWidgetTextTimer {
    let timer = SettingsWidgetTextTimer()
    timer.delta = delta
    return timer
}

private func effect(_ type: SettingsVideoEffectType) -> SettingsVideoEffect {
    let effect = SettingsVideoEffect()
    effect.type = type
    return effect
}

private func mask(_ points: [(Double, Double)]) -> SettingsVideoEffect {
    let mask = effect(.mask)
    mask.mask.points = points.map { .init(x: $0.0, y: $0.1) }
    return mask
}

struct RemoteControlSceneConfigValidationSuite {
    final class Fixture {
        let mainScene = SettingsScene(name: "Main")
        let targetScene = SettingsScene(name: "Target")
        let mainText = SettingsWidget(name: "Main text")
        let targetText = SettingsWidget(name: "Target text")
        let browser = SettingsWidget(name: "Browser")
        let targetInMain = SettingsWidget(name: "Target in main")
        let mainInTarget = SettingsWidget(name: "Main in target")
        let database = Database()
        let rtmpCameraId = UUID()
        var cameras = RemoteControlCameras(cameraId: cameraId)

        init() {
            mainText.type = .text
            mainText.text.formatString = "Main"
            targetText.type = .text
            targetText.text.formatString = "Target"
            browser.type = .browser
            browser.browser.url = "https://example.com"
            targetInMain.type = .scene
            targetInMain.scene.sceneId = targetScene.id
            mainInTarget.type = .scene
            mainInTarget.scene.sceneId = mainScene.id
            mainScene.widgets = [SettingsSceneWidget(widgetId: mainText.id), sceneWidget(targetInMain.id)]
            targetScene.widgets = [SettingsSceneWidget(widgetId: targetText.id)]
            database.scenes = [mainScene, targetScene]
            database.widgets = [mainText, targetText, browser, targetInMain, mainInTarget]
            var rtmp = mainScene.videoSource
            rtmp.cameraPosition = .rtmp
            rtmp.rtmpCameraId = rtmpCameraId
            cameras.ids = [cameraId(mainScene.videoSource), cameraId(rtmp)]
        }

        func scene(_ name: String) -> SettingsScene {
            database.scenes.first { $0.name == name }!
        }

        func makeWidget(_ type: SettingsWidgetType) -> SettingsWidget {
            let widget = emptyWidget(type)
            switch type {
            case .text:
                widget.text.formatString = "{timer}"
                widget.text.timers = [SettingsWidgetTextTimer()]
            case .image:
                widget.effects = [effect(.opacity)]
            case .browser:
                widget.browser.url = "https://example.com"
            case .slideshow:
                let slide = SettingsWidgetSlideshowSlide()
                slide.widgetId = mainText.id
                widget.slideshow.slides = [slide]
            case .wheelOfLuck:
                widget.wheelOfLuck.options = [SettingsWidgetWheelOfLuckOption()]
            case .scene:
                widget.scene.sceneId = targetScene.id
            case .crop:
                widget.crop.sourceWidgetId = browser.id
            default:
                break
            }
            return widget
        }
    }

    struct WidgetCase: CustomTestStringConvertible {
        let testDescription: String
        let type: SettingsWidgetType
        let editableTextTimers: Int
        let edit: @Sendable (Fixture, SettingsWidget) -> Void

        init(_ description: String,
             _ type: SettingsWidgetType,
             editableTextTimers: Int = 0,
             edit: @escaping @Sendable (Fixture, SettingsWidget) -> Void = { _, _ in })
        {
            testDescription = description
            self.type = type
            self.editableTextTimers = editableTextTimers
            self.edit = edit
        }
    }

    struct SceneCase: CustomTestStringConvertible {
        let testDescription: String
        let scene: String
        let edit: @Sendable (Fixture, SettingsScene) -> Void

        init(_ description: String,
             _ scene: String,
             edit: @escaping @Sendable (Fixture, SettingsScene) -> Void)
        {
            testDescription = description
            self.scene = scene
            self.edit = edit
        }
    }

    struct WidgetScenesCase: CustomTestStringConvertible {
        let testDescription: String
        let type: SettingsWidgetType
        let scenes: [String]
        let valid: Bool

        init(_ description: String, _ type: SettingsWidgetType, _ scenes: [String], _ valid: Bool) {
            testDescription = description
            self.type = type
            self.scenes = scenes
            self.valid = valid
        }
    }

    @Test(arguments: SettingsWidgetType.allCases)
    func createAndEchoEveryWidgetType(type: SettingsWidgetType) {
        let fixture = Fixture()
        let widget = fixture.makeWidget(type)
        #expect(isValidRemoteControlWidgetUpdate(widget: emptyWidget(type),
                                                 new: modified(widget),
                                                 creating: true,
                                                 editableTextTimers: 0,
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
        #expect(isValidRemoteControlWidgetUpdate(widget: widget,
                                                 new: modified(widget),
                                                 creating: false,
                                                 editableTextTimers: 0,
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test
    func widgetTypeCannotChange() {
        let fixture = Fixture()
        #expect(!isValidRemoteControlWidgetUpdate(widget: fixture.mainText,
                                                  new: modified(fixture.mainText) { $0.type = .image },
                                                  creating: false,
                                                  editableTextTimers: 0,
                                                  database: fixture.database,
                                                  cameras: fixture.cameras))
    }

    @Test(arguments: [
        WidgetCase("Empty text", .text) { $1.text.formatString = "" },
        WidgetCase("Empty browser URL", .browser) { $1.browser.url = "" },
        WidgetCase("Blank browser URL", .browser) { $1.browser.url = " " },
        WidgetCase("Invalid browser URL", .browser) { $1.browser.url = "no url" },
        WidgetCase("No slides", .slideshow) { $1.slideshow.slides = [] },
        WidgetCase("No wheel of luck options", .wheelOfLuck) { $1.wheelOfLuck.options = [] },
        WidgetCase("Text timer delta", .text) {
            $1.text.formatString = "{timer}"
            $1.text.timers = [timer(delta: 15)]
        },
        WidgetCase("Crop of text widget", .crop) { $1.crop.sourceWidgetId = $0.mainText.id },
        WidgetCase("Slide of browser widget", .slideshow) { $1.slideshow.slides[0].widgetId = $0.browser.id },
        WidgetCase("Slide of unknown widget", .slideshow) { $1.slideshow.slides[0].widgetId = UUID() },
    ])
    func createIsRejected(testCase: WidgetCase) {
        let fixture = Fixture()
        #expect(!isValidRemoteControlWidgetUpdate(widget: emptyWidget(testCase.type),
                                                  new: modified(fixture.makeWidget(testCase.type)) {
                                                      testCase.edit(fixture, $0)
                                                  },
                                                  creating: true,
                                                  editableTextTimers: testCase.editableTextTimers,
                                                  database: fixture.database,
                                                  cameras: fixture.cameras))
    }

    @Test(arguments: [
        WidgetCase("Default padel players", .scoreboard),
        WidgetCase("Crop of unknown widget", .crop) { $1.crop.sourceWidgetId = UUID() },
        WidgetCase("Unknown scene", .scene) { $1.scene.sceneId = UUID() },
        WidgetCase("Text timer with default delta", .text) {
            $1.text.formatString = "{timer}"
            $1.text.timers = [SettingsWidgetTextTimer()]
        },
    ])
    func createIsAccepted(testCase: WidgetCase) {
        let fixture = Fixture()
        #expect(isValidRemoteControlWidgetUpdate(widget: emptyWidget(testCase.type),
                                                 new: modified(fixture.makeWidget(testCase.type)) {
                                                     testCase.edit(fixture, $0)
                                                 },
                                                 creating: true,
                                                 editableTextTimers: testCase.editableTextTimers,
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test(arguments: [
        WidgetCase("Crop of text widget", .crop) { $1.crop.sourceWidgetId = $0.mainText.id },
        WidgetCase("Crop of unknown widget", .crop) { $1.crop.sourceWidgetId = UUID() },
        WidgetCase("Unknown scene", .scene) { $1.scene.sceneId = UUID() },
        WidgetCase("Unknown padel player", .scoreboard) { $1.scoreboard.padel.homePlayer1 = UUID() },
        WidgetCase("Text font size", .text) { $1.text.fontSize = 5 },
        WidgetCase("Text delay", .text) { $1.text.delay = 11 },
        WidgetCase("Text width", .text) { $1.text.width = 0 },
        WidgetCase("Text corner radius", .text) { $1.text.cornerRadius = -1 },
        WidgetCase("Browser URL", .browser) { $1.browser.url = "no url" },
        WidgetCase("Browser width", .browser) { $1.browser.width = 0 },
        WidgetCase("Browser height", .browser) { $1.browser.height = 4000 },
        WidgetCase("Browser FPS", .browser) { $1.browser.baseFps = 16 },
        WidgetCase("Crop x", .crop) { $1.crop.x = -1 },
        WidgetCase("Crop width", .crop) { $1.crop.width = 0 },
        WidgetCase("Snapshot showtime", .snapshot) { $1.snapshot.showtime = 7 },
        WidgetCase("Chat height", .chat) { $1.chat.height = 2 },
        WidgetCase("Chat font size", .chat) { $1.chat.fontSize = 100 },
        WidgetCase("Chat messages", .chat) { $1.chat.maximumNumberOfMessages = 6 },
        WidgetCase("Map size", .map) { $1.map.size = 100 },
        WidgetCase("Map delay", .map) { $1.map.delay = 11 },
        WidgetCase("Emote combo minimum", .chatEmoteCombo) { $1.chatEmoteCombo.minimumCombo = 1 },
        WidgetCase("Emote combo reset", .chatEmoteCombo) { $1.chatEmoteCombo.resetAfter = 11 },
        WidgetCase("Pomodoro sound", .pomodoroTimer) { $1.pomodoroTimer.focusToBreakSoundId = UUID() },
        WidgetCase("Pomodoro focus", .pomodoroTimer) { $1.pomodoroTimer.focusDuration = 4 },
        WidgetCase("Pomodoro break", .pomodoroTimer) { $1.pomodoroTimer.breakDuration = 4 },
        WidgetCase("Pomodoro width", .pomodoroTimer) { $1.pomodoroTimer.width = 6 },
        WidgetCase("Golf holes", .scoreboard) { $1.scoreboard.golf.numberOfHoles = 10 },
        WidgetCase("Golf par", .scoreboard) { $1.scoreboard.golf.pars[0] = 10 },
        WidgetCase("Golf players", .scoreboard) {
            $1.scoreboard.golf.players = (0 ..< 5).map { _ in .init() }
        },
        WidgetCase("Generic clock", .scoreboard) { $1.scoreboard.generic.clock.maximum = 0 },
        WidgetCase("Modular width", .scoreboard) { $1.scoreboard.modular.width = 50 },
        WidgetCase("Modular row height", .scoreboard) { $1.scoreboard.modular.rowHeight = 200 },
        WidgetCase("Video source rotation", .videoSource) { $1.videoSource.rotation = 45 },
        WidgetCase("Video source face zoom", .videoSource) { $1.videoSource.trackFaceZoom = 2 },
        WidgetCase("Video source camera", .videoSource) {
            $1.videoSource.videoSource.cameraPosition = .rtmp
            $1.videoSource.videoSource.rtmpCameraId = UUID()
        },
        WidgetCase("No wheel of luck options", .wheelOfLuck) { $1.wheelOfLuck.options = [] },
        WidgetCase("Wheel of luck weight", .wheelOfLuck) { $1.wheelOfLuck.options[0].weight = 11 },
        WidgetCase("Wheel of luck function", .wheelOfLuck) { $1.wheelOfLuck.options[0].function = .gimbalUp },
        WidgetCase("VTuber field of view", .vTuber) { $1.vTuber.cameraFieldOfView = 5 },
        WidgetCase("VTuber camera y", .vTuber) { $1.vTuber.cameraPositionY = 3 },
        WidgetCase("VTuber arms angle", .vTuber) { $1.vTuber.armsAngle = 10 },
        WidgetCase("VTuber mouth", .vTuber) { $1.vTuber.sensitivity.mouth = 4 },
        WidgetCase("PNGTuber eyes", .pngTuber) { $1.pngTuber.sensitivity.eyes = 6 },
        WidgetCase("Slide time", .slideshow) { $1.slideshow.slides[0].time = 7 },
        WidgetCase("Alert font size", .alerts) { $1.alerts.twitch.follows.fontSize = 5 },
        WidgetCase("Alert image loops", .alerts) { $1.alerts.twitch.follows.imageLoopCount = 0 },
        WidgetCase("Alert speech delay", .alerts) { $1.alerts.twitch.follows.textToSpeechDelay = 6 },
        WidgetCase("Alert image", .alerts) { $1.alerts.twitch.follows.imageId = UUID() },
        WidgetCase("Alert sound", .alerts) { $1.alerts.twitch.follows.soundId = UUID() },
        WidgetCase("AI without configuration", .alerts) { $1.alerts.aiEnabled = true },
        WidgetCase("AI base URL", .alerts) { $1.alerts.ai.baseUrl = "no url" },
        WidgetCase("Timer delta when not editable", .text) {
            $1.text.formatString = "{timer}"
            $1.text.timers = [timer(delta: 15)]
        },
        WidgetCase("Delta of timer that is not editable", .text, editableTextTimers: 1) {
            $1.text.formatString = "{timer}"
            $1.text.timers = [SettingsWidgetTextTimer(), timer(delta: 15)]
        },
        WidgetCase("Invalid timer delta", .text, editableTextTimers: 1) {
            $1.text.formatString = "{timer}"
            $1.text.timers = [timer(delta: 7)]
        },
        WidgetCase("Existing timer delta when not editable", .text) { $1.text.timers[0].delta = 60 },
        WidgetCase("Invalid existing timer delta", .text, editableTextTimers: 1) {
            $1.text.timers[0].delta = 7
        },
        WidgetCase("Opacity", .image) {
            $1.effects[0].opacity.opacity = 2
        },
        WidgetCase("Effect type", .image) {
            $1.effects[0].type = .sepia
        },
        WidgetCase("Duplicate effect id", .image) {
            $1.effects.append(roundTrip($1.effects[0]))
        },
        WidgetCase("Mask with two points", .image) { $1.effects.append(mask([(0, 0), (50, 50)])) },
        WidgetCase("Unknown LUT", .image) {
            let lut = effect(.lut)
            lut.lut.lut = UUID()
            $1.effects.append(lut)
        },
        WidgetCase("Shape corner radius", .image) {
            let shape = effect(.shape)
            shape.shape.cornerRadius = 2
            $1.effects.append(shape)
        },
    ])
    func updateIsRejected(testCase: WidgetCase) {
        let fixture = Fixture()
        let widget = fixture.makeWidget(testCase.type)
        #expect(!isValidRemoteControlWidgetUpdate(widget: widget,
                                                  new: modified(widget) { testCase.edit(fixture, $0) },
                                                  creating: false,
                                                  editableTextTimers: testCase.editableTextTimers,
                                                  database: fixture.database,
                                                  cameras: fixture.cameras))
    }

    @Test(arguments: [
        WidgetCase("Crop of other browser widget", .crop) {
            let browser = $0.makeWidget(.browser)
            $0.database.widgets.append(browser)
            $1.crop.sourceWidgetId = browser.id
        },
        WidgetCase("Other scene", .scene) { $1.scene.sceneId = $0.mainScene.id },
        WidgetCase("Known padel player", .scoreboard) {
            let player = SettingsWidgetScoreboardPlayer()
            $0.database.scoreboardPlayers = [player]
            $1.scoreboard.padel.homePlayer1 = player.id
        },
        WidgetCase("Text font size", .text) { $1.text.fontSize = 50 },
        WidgetCase("Text format string", .text) { $1.text.formatString = "{time}" },
        WidgetCase("Text background color", .text) {
            $1.text.backgroundColor = RgbColor(red: 1, green: 2, blue: 3)
        },
        WidgetCase("Browser URL", .browser) { $1.browser.url = "https://example.org/" },
        WidgetCase("Snapshot showtime", .snapshot) { $1.snapshot.showtime = 10 },
        WidgetCase("QR code message", .qrCode) { $1.qrCode.message = "Remote" },
        WidgetCase("Golf holes", .scoreboard) { $1.scoreboard.golf.numberOfHoles = 9 },
        WidgetCase("Golf players", .scoreboard) {
            $1.scoreboard.golf.players = (0 ..< 3).map { _ in .init() }
        },
        WidgetCase("Scoreboard sport", .scoreboard) { $1.scoreboard.sport = .padel },
        WidgetCase("Wheel of luck weight", .wheelOfLuck) { $1.wheelOfLuck.options[0].weight = 20 },
        WidgetCase("Wheel of luck option", .wheelOfLuck) {
            $1.wheelOfLuck.options.append(SettingsWidgetWheelOfLuckOption())
        },
        WidgetCase("Video source rotation", .videoSource) { $1.videoSource.rotation = 90 },
        WidgetCase("Pomodoro sound", .pomodoroTimer) {
            let sound = SettingsAlertsMediaGalleryItem(name: "Sound")
            $0.database.alertsMediaGallery.customSounds = [sound]
            $1.pomodoroTimer.focusToBreakSoundId = sound.id
        },
        WidgetCase("Alert image and sound", .alerts) {
            let image = SettingsAlertsMediaGalleryItem(name: "Image")
            let sound = SettingsAlertsMediaGalleryItem(name: "Sound")
            $0.database.alertsMediaGallery.customImages = [image]
            $0.database.alertsMediaGallery.customSounds = [sound]
            $1.alerts.twitch.follows.imageId = image.id
            $1.alerts.twitch.follows.soundId = sound.id
        },
        WidgetCase("Configured AI", .alerts) {
            $1.alerts.ai.apiKey = "key"
            $1.alerts.aiEnabled = true
        },
        WidgetCase("Chat bot command", .alerts) {
            $1.alerts.chatBot.commands.append(SettingsWidgetAlertsChatBotCommand())
        },
        WidgetCase("Timer delta when editable", .text, editableTextTimers: 1) {
            $1.text.formatString = "{timer}"
            $1.text.timers = [timer(delta: 15)]
        },
        WidgetCase("Existing timer delta when editable", .text, editableTextTimers: 1) {
            $1.text.timers[0].delta = 60
        },
        WidgetCase("Opacity", .image) {
            $1.effects[0].opacity.opacity = 0.25
        },
        WidgetCase("Insert effect", .image) {
            $1.effects.insert(effect(.grayScale), at: 0)
        },
        WidgetCase("Remove effects", .image) {
            $1.effects = []
        },
        WidgetCase("Mask with three points", .image) {
            $1.effects.append(mask([(0, 0), (50, 50), (50, 0)]))
        },
        WidgetCase("Known LUT", .image) {
            let colorLut = SettingsColorLut(type: .diskCube, name: "Lut")
            $0.database.color.diskLutsCube = [colorLut]
            let lut = effect(.lut)
            lut.lut.lut = colorLut.id
            $1.effects.append(lut)
        },
        WidgetCase("Ignored effects of text widget", .text) {
            let opacity = effect(.opacity)
            $1.effects = [opacity, opacity]
        },
    ])
    func updateIsAccepted(testCase: WidgetCase) {
        let fixture = Fixture()
        let widget = fixture.makeWidget(testCase.type)
        #expect(isValidRemoteControlWidgetUpdate(widget: widget,
                                                 new: modified(widget) { testCase.edit(fixture, $0) },
                                                 creating: false,
                                                 editableTextTimers: testCase.editableTextTimers,
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test(arguments: [
        WidgetCase("Crop of unknown widget", .crop) { $1.crop.sourceWidgetId = UUID() },
        WidgetCase("Slide of unknown widget", .slideshow) { $1.slideshow.slides[0].widgetId = UUID() },
        WidgetCase("Unknown scene", .scene) { $1.scene.sceneId = UUID() },
    ])
    func danglingReferenceIsKeptOnEcho(testCase: WidgetCase) {
        let fixture = Fixture()
        let widget = fixture.makeWidget(testCase.type)
        testCase.edit(fixture, widget)
        #expect(isValidRemoteControlWidgetUpdate(widget: widget,
                                                 new: modified(widget),
                                                 creating: false,
                                                 editableTextTimers: testCase.editableTextTimers,
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test(arguments: [
        ("Renamed", true),
        ("Main text", true),
        ("Target text", false),
        ("", false),
    ])
    func widgetName(name: String, isValid: Bool) {
        let fixture = Fixture()
        let widgets = fixture.database.widgets
        #expect(isValidRemoteControlName(modified(fixture.mainText) { $0.name = name },
                                         widgets,
                                         widgets) == isValid)
    }

    @Test
    func newWidgetCannotTakeExistingName() {
        let fixture = Fixture()
        let widgets = fixture.database.widgets
        let new = modified(fixture.makeWidget(.text)) { $0.name = "Main text" }
        #expect(!isValidRemoteControlName(new, widgets + [new], widgets))
    }

    @Test(arguments: ["Main", "Target"])
    func sceneEcho(name: String) {
        let fixture = Fixture()
        let scene = fixture.scene(name)
        let echo = modified(scene)
        #expect(isValidRemoteControlScene(scene: echo,
                                          scenes: replacing(fixture.database.scenes, echo),
                                          database: fixture.database))
        #expect(isValidRemoteControlSceneUpdate(scene: scene,
                                                new: echo,
                                                database: fixture.database,
                                                cameras: fixture.cameras))
    }

    @Test
    func sceneClone() {
        let fixture = Fixture()
        let clone = modified(fixture.mainScene) {
            $0.id = UUID()
            $0.name = "Clone"
        }
        #expect(isValidRemoteControlScene(scene: clone,
                                          scenes: fixture.database.scenes + [clone],
                                          database: fixture.database))
        #expect(isValidRemoteControlSceneUpdate(scene: emptyScene(clone),
                                                new: clone,
                                                database: fixture.database,
                                                cameras: fixture.cameras))
    }

    @Test
    func newSceneCannotTakeExistingName() {
        let fixture = Fixture()
        let new = SettingsScene(name: "Target")
        #expect(!isValidRemoteControlScene(scene: new,
                                           scenes: fixture.database.scenes + [new],
                                           database: fixture.database))
    }

    @Test(arguments: [
        ("Renamed", true),
        ("Target", false),
        ("", false),
    ])
    func sceneName(name: String, isValid: Bool) {
        let fixture = Fixture()
        let renamed = modified(fixture.mainScene) { $0.name = name }
        #expect(isValidRemoteControlScene(scene: renamed,
                                          scenes: replacing(fixture.database.scenes, renamed),
                                          database: fixture.database) == isValid)
    }

    @Test(arguments: [
        (101.0, 0.0, 10.0),
        (-1, 0, 10),
        (0, 101, 10),
        (0, -1, 10),
        (0, 0, 0),
        (0, 0, 101),
    ])
    func sceneWidgetOutsideCanvasIsRejected(x: Double, y: Double, size: Double) {
        let fixture = Fixture()
        #expect(!isValidRemoteControlSceneUpdate(scene: fixture.mainScene,
                                                 new: modified(fixture.mainScene) {
                                                     $0.widgets[0].layout.x = x
                                                     $0.widgets[0].layout.y = y
                                                     $0.widgets[0].layout.size = size
                                                 },
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
        #expect(!isValidRemoteControlSceneUpdate(scene: fixture.targetScene,
                                                 new: modified(fixture.targetScene) {
                                                     $0.widgets.append(sceneWidget(fixture.mainText.id,
                                                                                   x: x,
                                                                                   y: y,
                                                                                   size: size))
                                                 },
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test
    func sceneWidgetAtCanvasEdgeIsAccepted() {
        let fixture = Fixture()
        #expect(isValidRemoteControlSceneUpdate(scene: fixture.mainScene,
                                                new: modified(fixture.mainScene) {
                                                    $0.widgets[0].layout.x = 100
                                                    $0.widgets[0].layout.y = 100
                                                    $0.widgets[0].layout.size = 1
                                                    $0.widgets[0].layout.alignment = .bottomRight
                                                },
                                                database: fixture.database,
                                                cameras: fixture.cameras))
    }

    @Test(arguments: [
        SceneCase("Change widget of scene widget", "Main") { $1.widgets[0].widgetId = $0.targetText.id },
        SceneCase("Add unknown widget", "Main") { $1.widgets.append(sceneWidget(UUID())) },
        SceneCase("Rotation", "Target") { $1.videoSourceRotation = 45 },
        SceneCase("Too high quick switch group", "Target") { $1.quickSwitchGroup = 5 },
        SceneCase("Too low quick switch group", "Target") { $1.quickSwitchGroup = 0 },
        SceneCase("Unknown mic", "Target") { $1.micId = "Unknown mic" },
        SceneCase("Unknown camera", "Target") {
            $1.videoSource.cameraPosition = .rtmp
            $1.videoSource.rtmpCameraId = UUID()
        },
    ])
    func sceneUpdateIsRejected(testCase: SceneCase) {
        let fixture = Fixture()
        let scene = fixture.scene(testCase.scene)
        #expect(!isValidRemoteControlSceneUpdate(scene: scene,
                                                 new: modified(scene) { testCase.edit(fixture, $0) },
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test(arguments: [
        SceneCase("Add widget", "Main") { $1.widgets.append(sceneWidget($0.browser.id)) },
        SceneCase("Remove widgets", "Main") { $1.widgets.removeAll() },
        SceneCase("Rotation", "Target") { $1.videoSourceRotation = 90 },
        SceneCase("Quick switch group", "Target") { $1.quickSwitchGroup = 2 },
        SceneCase("Known mic", "Target") {
            let mic = SettingsMicsMic()
            mic.inputUid = "Mic"
            $0.database.mics.mics = [mic]
            $1.micId = mic.id
        },
        SceneCase("Mirror, fill frame, stabilization and color", "Target") {
            $1.mirror = true
            $1.fillFrame = true
            $1.overrideVideoStabilizationMode = true
            $1.backgroundColor = RgbColor(red: 10, green: 20, blue: 30)
        },
        SceneCase("Known camera", "Target") {
            $1.videoSource.cameraPosition = .rtmp
            $1.videoSource.rtmpCameraId = $0.rtmpCameraId
        },
    ])
    func sceneUpdateIsAccepted(testCase: SceneCase) {
        let fixture = Fixture()
        let scene = fixture.scene(testCase.scene)
        #expect(isValidRemoteControlSceneUpdate(scene: scene,
                                                new: modified(scene) { testCase.edit(fixture, $0) },
                                                database: fixture.database,
                                                cameras: fixture.cameras))
    }

    @Test
    func newSceneWithUnknownWidgetIsRejected() {
        let fixture = Fixture()
        let new = SettingsScene(name: "Unknown widget")
        new.widgets = [sceneWidget(UUID())]
        #expect(!isValidRemoteControlSceneUpdate(scene: emptyScene(new),
                                                 new: modified(new),
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test(arguments: [
        SceneCase("Add same widget again", "Main") { $1.widgets.append(sceneWidget($0.mainText.id)) },
        SceneCase("Duplicate scene widget id", "Main") {
            let duplicate = roundTrip($1.widgets[0])
            duplicate.widgetId = $0.targetText.id
            $1.widgets.append(duplicate)
        },
        SceneCase("Add widget shown by nested scene", "Main") {
            $1.widgets.append(sceneWidget($0.targetText.id))
        },
        SceneCase("Add widget of scene shown in other scene", "Target") {
            $1.widgets.append(sceneWidget($0.mainText.id))
        },
    ])
    func duplicateWidgetsAreRejected(testCase: SceneCase) {
        let fixture = Fixture()
        let new = modified(fixture.scene(testCase.scene)) { testCase.edit(fixture, $0) }
        #expect(!isValidRemoteControlScene(scene: new,
                                           scenes: replacing(fixture.database.scenes, new),
                                           database: fixture.database))
    }

    @Test(arguments: [
        SceneCase("Add other widget", "Main") { $1.widgets.append(sceneWidget($0.browser.id)) },
        SceneCase("Remove widgets", "Main") { $1.widgets.removeAll() },
        SceneCase("Show scene that shows this scene", "Target") {
            $1.widgets.append(sceneWidget($0.mainInTarget.id))
        },
    ])
    func sceneWithoutDuplicateWidgetsIsAccepted(testCase: SceneCase) {
        let fixture = Fixture()
        let new = modified(fixture.scene(testCase.scene)) { testCase.edit(fixture, $0) }
        #expect(isValidRemoteControlScene(scene: new,
                                          scenes: replacing(fixture.database.scenes, new),
                                          database: fixture.database))
    }

    @Test
    func newSceneWithSameWidgetTwiceIsRejected() {
        let fixture = Fixture()
        let new = SettingsScene(name: "Twice")
        new.widgets = [sceneWidget(fixture.mainText.id), sceneWidget(fixture.mainText.id)]
        #expect(!isValidRemoteControlScene(scene: new,
                                           scenes: fixture.database.scenes + [new],
                                           database: fixture.database))
    }

    @Test
    func sceneWidgetCanShowSceneItIsIn() {
        let fixture = Fixture()
        let targetInMain = fixture.targetInMain
        #expect(isValidRemoteControlWidgetUpdate(widget: targetInMain,
                                                 new: modified(targetInMain) {
                                                     $0.scene.sceneId = fixture.mainScene.id
                                                 },
                                                 creating: false,
                                                 editableTextTimers: 0,
                                                 database: fixture.database,
                                                 cameras: fixture.cameras))
    }

    @Test
    func centeringSceneWidgetUnlocksPosition() {
        let sceneWidget = SettingsSceneWidget(widgetId: UUID())
        sceneWidget.layout.positioningLock = true
        let kept = remoteControlMergeSceneWidgets([sceneWidget], [roundTrip(sceneWidget)])
        #expect(kept.first === sceneWidget)
        #expect(sceneWidget.layout.positioningLock)
        _ = remoteControlMergeSceneWidgets([sceneWidget], [modified(sceneWidget) {
            $0.layout.alignment = .center
        }])
        #expect(!sceneWidget.layout.positioningLock)
        let new = SettingsSceneWidget(widgetId: UUID())
        new.layout.positioningLock = true
        new.layout.alignment = .topCenter
        let merged = remoteControlMergeSceneWidgets([sceneWidget], [new])
        #expect(merged.first === new)
        #expect(!new.layout.positioningLock)
    }

    @Test
    func partialCropDecodesDefaults() throws {
        let sourceWidgetId = UUID()
        let json = #"{"sourceWidgetId": "\#(sourceWidgetId.uuidString)", "x": 5}"#
        let crop = try JSONDecoder().decode(SettingsWidgetCrop.self, from: Data(json.utf8))
        #expect(crop.sourceWidgetId == sourceWidgetId)
        #expect(crop.x == 5)
        #expect(crop.y == 0)
        #expect(crop.width == 200)
        #expect(crop.height == 200)
    }

    @Test(arguments: [
        WidgetScenesCase("No scenes", .text, [], true),
        WidgetScenesCase("One scene", .text, ["Main"], true),
        WidgetScenesCase("Nested scene only", .browser, ["Target"], true),
        WidgetScenesCase("Scene and its nested scene", .text, ["Main", "Target"], false),
        WidgetScenesCase("Same scene twice", .text, ["Target", "Target"], false),
        WidgetScenesCase("Scene widget into scene already nesting it", .scene, ["Main"], true),
        WidgetScenesCase("Scene widget into its own scene", .scene, ["Target"], true),
    ])
    func createWidgetInScenes(widgetScenesCase: WidgetScenesCase) {
        let fixture = Fixture()
        #expect(isValidRemoteControlWidgetScenes(
            widget: fixture.makeWidget(widgetScenesCase.type),
            sceneIds: widgetScenesCase.scenes.map { fixture.scene($0).id },
            database: fixture.database
        ) == widgetScenesCase.valid)
    }

    @Test
    func createWidgetInUnknownScene() {
        let fixture = Fixture()
        #expect(!isValidRemoteControlWidgetScenes(widget: fixture.makeWidget(.text),
                                                  sceneIds: [UUID()],
                                                  database: fixture.database))
    }
}
