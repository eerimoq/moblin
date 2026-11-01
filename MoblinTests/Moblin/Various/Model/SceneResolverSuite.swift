import Foundation
@testable import Moblin
import Testing

private func makeWidget(_ name: String, enabled: Bool = true) -> SettingsWidget {
    let widget = SettingsWidget(name: name)
    widget.enabled = enabled
    return widget
}

private func makeSceneWidget(_ name: String, scene: SettingsScene, enabled: Bool = true) -> SettingsWidget {
    let widget = makeWidget(name, enabled: enabled)
    widget.type = .scene
    widget.scene.sceneId = scene.id
    return widget
}

private func makeScene(_ name: String, _ widgets: [SettingsWidget]) -> SettingsScene {
    let scene = SettingsScene(name: name)
    scene.widgets = widgets.map { SettingsSceneWidget(widgetId: $0.id) }
    return scene
}

struct SceneResolverSuite {
    @Test
    func nestedScene() {
        let text = makeWidget("Text")
        let image = makeWidget("Image")
        let nested = makeScene("Nested", [image])
        let sceneWidget = makeSceneWidget("Scene", scene: nested)
        let main = makeScene("Main", [text, sceneWidget])
        let resolver = SceneResolver(scenes: [main, nested], widgets: [text, image, sceneWidget])
        let resolved = resolver.resolve(main)
        #expect(resolved.widgets.map(\.widget.name) == ["Text", "Scene", "Image"])
        #expect(resolved.widgets.map(\.scene.name) == ["Main", "Main", "Nested"])
        #expect(resolved.sceneIds == [main.id, nested.id])
    }

    @Test
    func disabledSceneWidget() {
        let image = makeWidget("Image")
        let nested = makeScene("Nested", [image])
        let sceneWidget = makeSceneWidget("Scene", scene: nested, enabled: false)
        let main = makeScene("Main", [sceneWidget])
        let resolver = SceneResolver(scenes: [main, nested], widgets: [image, sceneWidget])
        #expect(resolver.resolve(main).widgets.map(\.widget.name) == ["Scene"])
        #expect(resolver.resolve(main).drawnWidgets().isEmpty)
        let resolved = resolver.resolve(main, includeDisabledSceneWidgets: true)
        #expect(resolved.widgets.map(\.widget.name) == ["Scene", "Image"])
        #expect(resolved.widgets.map(\.enabled) == [false, false])
        #expect(resolved.drawnWidgets().isEmpty)
    }

    @Test
    func disabledNestedSceneWidgetDisablesItsContent() {
        let image = makeWidget("Image")
        let innerScene = makeScene("Inner", [image])
        let innerWidget = makeSceneWidget("Inner scene", scene: innerScene, enabled: false)
        let outerScene = makeScene("Outer", [innerWidget])
        let outerWidget = makeSceneWidget("Outer scene", scene: outerScene)
        let main = makeScene("Main", [outerWidget])
        let resolver = SceneResolver(scenes: [main, outerScene, innerScene],
                                     widgets: [image, innerWidget, outerWidget])
        let resolved = resolver.resolve(main, includeDisabledSceneWidgets: true)
        #expect(resolved.widgets.map(\.widget.name) == ["Outer scene", "Inner scene", "Image"])
        #expect(resolved.widgets.map(\.enabled) == [true, false, false])
        #expect(resolved.drawnWidgets().map(\.widget.name) == ["Outer scene"])
    }

    @Test
    func duplicatedWidgetIsDrawnOnce() {
        let text = makeWidget("Text")
        let nested = makeScene("Nested", [text])
        let sceneWidget = makeSceneWidget("Scene", scene: nested)
        let main = makeScene("Main", [text, sceneWidget])
        let resolver = SceneResolver(scenes: [main, nested], widgets: [text, sceneWidget])
        let resolved = resolver.resolve(main)
        #expect(resolved.widgets.map(\.first) == [true, true, false])
        #expect(resolved.firstWidgets().map(\.scene.name) == ["Main", "Main"])
        #expect(resolved.duplicatedWidgetCounts() == [text.id: 1])
    }

    @Test
    func cyclicScenes() {
        let first = makeScene("First", [])
        let second = makeScene("Second", [])
        let firstWidget = makeSceneWidget("First", scene: first)
        let secondWidget = makeSceneWidget("Second", scene: second)
        first.widgets = [SettingsSceneWidget(widgetId: secondWidget.id)]
        second.widgets = [SettingsSceneWidget(widgetId: firstWidget.id)]
        let resolver = SceneResolver(scenes: [first, second], widgets: [firstWidget, secondWidget])
        #expect(resolver.resolve(first).widgets.map(\.widget.name) == ["Second", "First"])
    }

    @Test
    func remoteWidget() {
        let text = makeWidget("Text")
        let remoteImage = makeWidget("Remote image")
        let remoteScene = makeScene("Remote", [remoteImage])
        let remoteWidget = makeSceneWidget("Remote scene", scene: remoteScene)
        let main = makeScene("Main", [text])
        let resolver = SceneResolver(scenes: [main, remoteScene], widgets: [text, remoteImage, remoteWidget])
        let resolved = resolver.resolve(main, remoteWidgetId: remoteWidget.id)
        #expect(resolved.widgets.map(\.widget.name) == ["Text", "Remote scene", "Remote image"])
    }

    @Test
    func addableWidgets() {
        let text = makeWidget("Text")
        let image = makeWidget("Image")
        let nested = makeScene("Nested", [image])
        let sceneWidget = makeSceneWidget("Scene", scene: nested)
        let main = makeScene("Main", [text, sceneWidget])
        let other = makeScene("Other", [])
        let resolver = SceneResolver(scenes: [main, nested, other], widgets: [text, image, sceneWidget])
        #expect(resolver.addableWidgets(scene: main).isEmpty)
        #expect(resolver.addableWidgets(scene: nested).isEmpty)
        #expect(resolver.addableWidgets(scene: other).map(\.name) == ["Text", "Image", "Scene"])
    }

    @Test
    func addableWidgetsWithOldDuplicates() {
        let text = makeWidget("Text")
        let image = makeWidget("Image")
        let main = makeScene("Main", [text, text])
        let resolver = SceneResolver(scenes: [main], widgets: [text, image])
        #expect(resolver.addableWidgets(scene: main).map(\.name) == ["Image"])
    }

    @Test
    func selectableScenes() {
        let text = makeWidget("Text")
        let image = makeWidget("Image")
        let withText = makeScene("With text", [text])
        let withImage = makeScene("With image", [image])
        let sceneWidget = makeSceneWidget("Scene", scene: withImage)
        let main = makeScene("Main", [text, sceneWidget])
        let resolver = SceneResolver(scenes: [main, withText, withImage], widgets: [text, image, sceneWidget])
        #expect(resolver.selectableScenes(widget: sceneWidget).map(\.name) == ["Main", "With image"])
    }
}
