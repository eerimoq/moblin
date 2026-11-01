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

struct SceneResolver {
    private let scenes: [SettingsScene]
    private let widgets: [SettingsWidget]
    private let scenesById: [UUID: SettingsScene]
    private let widgetsById: [UUID: SettingsWidget]

    init(scenes: [SettingsScene], widgets: [SettingsWidget]) {
        self.scenes = scenes
        self.widgets = widgets
        scenesById = Dictionary(scenes.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        widgetsById = Dictionary(widgets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func resolve(_ scene: SettingsScene,
                 remoteWidgetId: UUID? = nil,
                 includeDisabledSceneWidgets: Bool = false) -> ResolvedScene
    {
        resolve(scene, remoteWidgetId, includeDisabledSceneWidgets, nil)
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
        var sceneWidgets = sceneWidgets(scene, change)
        if let remoteWidgetId {
            sceneWidgets.append(SettingsSceneWidget(widgetId: remoteWidgetId))
        }
        walk.visit(scene, sceneWidgets, true, self)
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
                                                        first: widgetIds.insert(widget.id).inserted))
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
                  resolver)
        }
    }
}

extension Model {
    func resolveScene(_ scene: SettingsScene,
                      includeRemote: Bool = false,
                      includeDisabledSceneWidgets: Bool = false) -> ResolvedScene
    {
        SceneResolver(
            scenes: database.scenes + remoteSceneScenes,
            widgets: database.widgets + remoteSceneWidgets
        )
        .resolve(scene,
                 remoteWidgetId: includeRemote ? remoteSceneWidgets.first?.id : nil,
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
