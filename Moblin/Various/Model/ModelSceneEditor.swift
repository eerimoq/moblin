import Foundation

private func makeAlignment(left: Bool?, top: Bool?) -> SettingsAlignment {
    switch (left, top) {
    case (true, true):
        .topLeft
    case (false, true):
        .topRight
    case (true, false):
        .bottomLeft
    case (false, false):
        .bottomRight
    case (nil, true):
        .topCenter
    case (nil, false):
        .bottomCenter
    case (true, nil):
        .leftCenter
    case (false, nil):
        .rightCenter
    case (nil, nil):
        .center
    }
}

private func layoutOffsetFromPosition(_ position: Double,
                                      _ size: Double,
                                      _ streamSize: Double,
                                      _ isNear: Bool) -> Double
{
    if isNear {
        position * 100 / streamSize
    } else {
        (streamSize - position - size) * 100 / streamSize
    }
}

extension Model {
    func sceneEditorPresentationChanged() {
        sceneEditor.sceneId = nil
        updateWidgetOutlinesForShowingPanel()
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

    func sceneEditorMoveWidget(sceneWidget: SettingsSceneWidget,
                               position: CGPoint,
                               size: CGSize,
                               centered: (horizontal: Bool, vertical: Bool))
    {
        let canvasSize = widgetOutlines.canvasSize
        var layout = sceneWidget.layout
        let alignment = layout.alignment
        if alignment.isHorizontalOrVerticalCenter() {
            layout.positioningLock = false
        }
        let left: Bool? = if centered.horizontal {
            nil
        } else if alignment.isHorizontalCenter() {
            position.x + size.width / 2 < canvasSize.width / 2
        } else {
            alignment.isLeft()
        }
        let top: Bool? = if centered.vertical {
            nil
        } else if alignment.isVerticalCenter() {
            position.y + size.height / 2 < canvasSize.height / 2
        } else {
            alignment.isTop()
        }
        layout.alignment = makeAlignment(left: left, top: top)
        if let left {
            layout.x = layoutOffsetFromPosition(position.x, size.width, canvasSize.width, left)
            layout.updateXString()
        }
        if let top {
            layout.y = layoutOffsetFromPosition(position.y, size.height, canvasSize.height, top)
            layout.updateYString()
        }
        sceneWidget.layout = layout
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
        guard let index = scene.widgets.firstIndex(where: { $0.id == sceneWidget.id }) else {
            return
        }
        let newIndex = up ? index + 1 : index - 1
        guard scene.widgets.indices.contains(newIndex) else {
            return
        }
        scene.widgets.swapAt(index, newIndex)
        sceneUpdated()
        sceneSettingsPanelSceneId += 1
    }
}
