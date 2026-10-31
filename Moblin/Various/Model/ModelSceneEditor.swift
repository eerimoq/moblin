import Foundation

extension Model {
    func sceneEditorPresentationChanged() {
        sceneEditor.sceneId = nil
        media.setShowCameraPreview(updateShowCameraPreview())
        setSceneEditorWidgetOutlinesEnabled(presentingSceneEditor)
        updateWidgetOutlines()
    }

    func sceneEditorScene() -> SettingsScene? {
        if let sceneId = sceneEditor.sceneId, let scene = database.scenes.first(where: { $0.id == sceneId }) {
            return scene
        }
        return getSelectedScene()
    }

    func sceneEditorSelectScene(id: UUID) {
        guard let scene = database.scenes.first(where: { $0.id == id }) else {
            return
        }
        if scene.enabled {
            sceneEditor.sceneId = nil
            selectScene(id: id)
        } else {
            sceneEditor.sceneId = id
        }
        updateWidgetOutlines()
    }

    func isSceneEditorOutlineEditable(outline: WidgetOutline) -> Bool {
        database.scenes.contains(where: { $0 === outline.scene })
    }

    func sceneEditorMoveWidget(sceneWidget: SettingsSceneWidget,
                               rect: CGRect,
                               centered: (horizontal: Bool, vertical: Bool))
    {
        sceneWidget.layout = sceneEditorLayout(sceneWidget.layout,
                                               rect,
                                               sceneEditorWidgetOutlines.canvasSize,
                                               centered)
        sceneUpdatedThrottled()
    }

    func sceneEditorResizeWidget(sceneWidget: SettingsSceneWidget, size: Double) {
        sceneWidget.layout.size = size.clamped(to: 1 ... 100)
        sceneWidget.layout.updateSizeString()
        sceneUpdatedThrottled()
    }

    func sceneEditorToggleWidgetEnabled(widget: SettingsWidget) {
        widget.enabled.toggle()
        reloadSpeechToText()
        sceneUpdated(attachCamera: isCaptureDeviceWidget(widget: widget))
    }

    func sceneEditorRemoveWidget(scene: SettingsScene, sceneWidget: SettingsSceneWidget) {
        var attachCamera = false
        if scene.id == getSelectedScene()?.id, let widget = findWidget(id: sceneWidget.widgetId) {
            attachCamera = isCaptureDeviceWidget(widget: widget)
        }
        scene.widgets.removeAll(where: { $0.id == sceneWidget.id })
        sceneUpdated(attachCamera: attachCamera)
        sceneSettingsPanelSceneId += 1
    }

    func sceneEditorMoveWidgetInDrawOrder(scene: SettingsScene, sceneWidget: SettingsSceneWidget, up: Bool) {
        guard let index = scene.widgets.firstIndex(where: { $0.id == sceneWidget.id }),
              let editorScene = sceneEditorScene()
        else {
            return
        }
        let shownSceneWidgetIds = Set(resolveScene(editorScene, includeRemote: true).firstWidgets().map(\.id))
        let step = up ? 1 : -1
        var newIndex = index + step
        while scene.widgets.indices.contains(newIndex),
              !shownSceneWidgetIds.contains(scene.widgets[newIndex].id)
        {
            newIndex += step
        }
        guard scene.widgets.indices.contains(newIndex) else {
            return
        }
        scene.widgets.insert(scene.widgets.remove(at: index), at: newIndex)
        sceneUpdated()
        sceneSettingsPanelSceneId += 1
    }
}
