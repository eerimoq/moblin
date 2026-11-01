import Foundation

struct ResolvedSceneWidget: Identifiable {
    var id: UUID {
        sceneWidget.id
    }

    let scene: SettingsScene
    let sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget
    let parentsEnabled: Bool
    let first: Bool
    let remote: Bool

    var enabled: Bool {
        parentsEnabled && widget.enabled
    }

    var drawn: Bool {
        first && enabled
    }
}

struct ResolvedScene {
    var widgets: [ResolvedSceneWidget] = []
    var sceneIds: Set<UUID> = []

    func firstWidgets() -> [ResolvedSceneWidget] {
        widgets.filter(\.first)
    }

    func drawnWidgets() -> [ResolvedSceneWidget] {
        widgets.filter(\.drawn)
    }

    func localDrawnWidgets() -> [ResolvedSceneWidget] {
        widgets.filter { $0.drawn && !$0.remote }
    }

    func duplicatedWidgetCounts() -> [UUID: Int] {
        widgets.filter { !$0.first }.reduce(into: [:]) { counts, widget in
            counts[widget.widget.id, default: 0] += 1
        }
    }
}

private enum SceneWidgetsChange {
    case add(sceneId: UUID, widgetId: UUID)
    case setScene(widgetId: UUID, sceneId: UUID)
}

private struct SceneResolveKey: Hashable {
    let sceneId: UUID
    let includeRemote: Bool
    let includeDisabledSceneWidgets: Bool
}

final class SceneResolver {
    private let scenes: [SettingsScene]
    private let widgets: [SettingsWidget]
    private let scenesById: [UUID: SettingsScene]
    private let widgetsById: [UUID: SettingsWidget]
    private let remoteWidgetId: UUID?
    private var resolved: [SceneResolveKey: ResolvedScene] = [:]

    init(scenes: [SettingsScene], widgets: [SettingsWidget], remoteWidgetId: UUID? = nil) {
        self.scenes = scenes
        self.widgets = widgets
        self.remoteWidgetId = remoteWidgetId
        scenesById = Dictionary(scenes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        widgetsById = Dictionary(widgets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func resolve(_ scene: SettingsScene,
                 includeRemote: Bool = false,
                 includeDisabledSceneWidgets: Bool = false) -> ResolvedScene
    {
        let key = SceneResolveKey(sceneId: scene.id,
                                  includeRemote: includeRemote,
                                  includeDisabledSceneWidgets: includeDisabledSceneWidgets)
        if let resolved = resolved[key] {
            return resolved
        }
        let resolved = resolve(scene, includeRemote ? remoteWidgetId : nil, includeDisabledSceneWidgets, nil)
        self.resolved[key] = resolved
        return resolved
    }

    func addableWidgets(scene: SettingsScene) -> [SettingsWidget] {
        let before = resolveAllScenes()
        return widgets.filter {
            !introducesDuplicatedWidgets(.add(sceneId: scene.id, widgetId: $0.id), before)
        }
    }

    func selectableScenes(widget: SettingsWidget) -> [SettingsScene] {
        let before = resolveAllScenes()
        return scenes.filter {
            !introducesDuplicatedWidgets(.setScene(widgetId: widget.id, sceneId: $0.id), before)
        }
    }

    private func resolveAllScenes() -> [ResolvedScene] {
        scenes.map { resolve($0, nil, true, nil) }
    }

    private func introducesDuplicatedWidgets(_ change: SceneWidgetsChange,
                                             _ before: [ResolvedScene]) -> Bool
    {
        zip(scenes, before).contains { scene, before in
            switch change {
            case let .add(sceneId, _):
                guard before.sceneIds.contains(sceneId) else {
                    return false
                }
            case let .setScene(widgetId, _):
                guard before.widgets.contains(where: { $0.widget.id == widgetId }) else {
                    return false
                }
            }
            let beforeCounts = before.duplicatedWidgetCounts()
            return resolve(scene, nil, true, change).duplicatedWidgetCounts().contains { widgetId, count in
                count > beforeCounts[widgetId, default: 0]
            }
        }
    }

    private func resolve(_ scene: SettingsScene,
                         _ remoteWidgetId: UUID?,
                         _ includeDisabledSceneWidgets: Bool,
                         _ change: SceneWidgetsChange?) -> ResolvedScene
    {
        var walk = SceneWalk(includeDisabledSceneWidgets: includeDisabledSceneWidgets, change: change)
        walk.resolved.sceneIds.insert(scene.id)
        walk.visit(scene, sceneWidgets(scene, change), true, false, self)
        if let remoteWidgetId {
            walk.visit(scene, [SettingsSceneWidget(widgetId: remoteWidgetId)], true, true, self)
        }
        return walk.resolved
    }

    fileprivate func findScene(id: UUID) -> SettingsScene? {
        scenesById[id]
    }

    fileprivate func findWidget(id: UUID) -> SettingsWidget? {
        widgetsById[id]
    }

    fileprivate func sceneWidgets(_ scene: SettingsScene,
                                  _ change: SceneWidgetsChange?) -> [SettingsSceneWidget]
    {
        if case let .add(sceneId, widgetId) = change, sceneId == scene.id {
            return scene.widgets + [SettingsSceneWidget(widgetId: widgetId)]
        }
        return scene.widgets
    }
}

private struct SceneWalk {
    let includeDisabledSceneWidgets: Bool
    let change: SceneWidgetsChange?
    var resolved = ResolvedScene()
    var widgetIds: Set<UUID> = []

    mutating func visit(_ scene: SettingsScene,
                        _ sceneWidgets: [SettingsSceneWidget],
                        _ parentsEnabled: Bool,
                        _ remote: Bool,
                        _ resolver: SceneResolver)
    {
        for sceneWidget in sceneWidgets {
            guard let widget = resolver.findWidget(id: sceneWidget.widgetId) else {
                continue
            }
            resolved.widgets.append(ResolvedSceneWidget(scene: scene,
                                                        sceneWidget: sceneWidget,
                                                        widget: widget,
                                                        parentsEnabled: parentsEnabled,
                                                        first: widgetIds.insert(widget.id).inserted,
                                                        remote: remote))
            guard widget.type == .scene, widget.enabled || includeDisabledSceneWidgets else {
                continue
            }
            var nestedSceneId = widget.scene.sceneId
            if case let .setScene(widgetId, sceneId) = change, widgetId == widget.id {
                nestedSceneId = sceneId
            }
            guard let nestedScene = resolver.findScene(id: nestedSceneId),
                  resolved.sceneIds.insert(nestedScene.id).inserted
            else {
                continue
            }
            visit(nestedScene,
                  resolver.sceneWidgets(nestedScene, change),
                  parentsEnabled && widget.enabled,
                  remote,
                  resolver)
        }
    }
}

extension Model {
    func makeSceneResolver() -> SceneResolver {
        SceneResolver(scenes: database.scenes + remoteSceneScenes,
                      widgets: database.widgets + remoteSceneWidgets,
                      remoteWidgetId: remoteSceneWidgets.first?.id)
    }

    func resolveScene(_ scene: SettingsScene,
                      includeRemote: Bool = false,
                      includeDisabledSceneWidgets: Bool = false) -> ResolvedScene
    {
        makeSceneResolver().resolve(scene,
                                    includeRemote: includeRemote,
                                    includeDisabledSceneWidgets: includeDisabledSceneWidgets)
    }

    func drawnWidgetsInSelectedScene() -> [SettingsWidget] {
        guard let scene = getSelectedScene() else {
            return []
        }
        return resolveScene(scene).drawnWidgets().map(\.widget)
    }

    func addableWidgets(scene: SettingsScene) -> [SettingsWidget] {
        SceneResolver(scenes: database.scenes, widgets: database.widgets).addableWidgets(scene: scene)
    }

    func selectableScenes(widget: SettingsWidget) -> [SettingsScene] {
        SceneResolver(scenes: database.scenes, widgets: database.widgets).selectableScenes(widget: widget)
    }
}
