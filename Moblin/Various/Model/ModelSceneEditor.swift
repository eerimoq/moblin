import Foundation
import ImageIO

struct WidgetOutline: Identifiable {
    var id: UUID {
        sceneWidget.id
    }

    let sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget
    let rect: CGRect
    let alignment: SettingsAlignment
    let sized: Bool
    let inScene: Bool
    let enabled: Bool
}

@MainActor
class SceneEditor: ObservableObject {
    @Published var sceneId: UUID?
    @Published var enabled = false
    @Published var outlines: [WidgetOutline] = []
    @Published var canvasSize: CGSize = .init(width: 1920, height: 1080)
    var imageSizes: [UUID: CGSize?] = [:]
}

extension Model {
    func sceneEditorPresentationChanged() {
        sceneEditor.sceneId = nil
        media.setShowCameraPreview(updateShowCameraPreview())
        setSceneEditorWidgetOutlinesEnabled(presentingSceneEditor)
        updateWidgetOutlines()
    }

    func sceneEditorScene() -> SettingsScene? {
        if let sceneId = sceneEditor.sceneId, let scene = database.findScene(id: sceneId) {
            return scene
        }
        return getSelectedScene()
    }

    func sceneEditorSelectScene(id: UUID) {
        guard let scene = database.findScene(id: id) else {
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

    func sceneEditorMoveWidget(sceneWidget: SettingsSceneWidget, rect: CGRect) {
        sceneWidget.layout = sceneEditorLayout(sceneWidget.layout, rect, sceneEditor.canvasSize)
        sceneUpdatedThrottled()
    }

    func sceneEditorSetWidgetAlignment(sceneWidget: SettingsSceneWidget,
                                       size: CGSize,
                                       alignment: SettingsAlignment)
    {
        sceneWidget.layout = sceneEditorAlignedLayout(sceneWidget.layout,
                                                      alignment,
                                                      size,
                                                      sceneEditor.canvasSize)
        sceneUpdated()
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

    private func sceneEditorDrawOrderTargetIndex(scene: SettingsScene,
                                                 sceneWidget: SettingsSceneWidget,
                                                 up: Bool) -> Int?
    {
        guard let index = scene.widgets.firstIndex(where: { $0.id == sceneWidget.id }) else {
            return nil
        }
        let shownSceneWidgetIds = Set(sceneEditor.outlines.filter(\.inScene).map(\.id))
        let step = up ? 1 : -1
        var newIndex = index + step
        while scene.widgets.indices.contains(newIndex),
              !shownSceneWidgetIds.contains(scene.widgets[newIndex].id)
        {
            newIndex += step
        }
        guard scene.widgets.indices.contains(newIndex) else {
            return nil
        }
        return newIndex
    }

    func sceneEditorCanMoveWidgetInDrawOrder(scene: SettingsScene,
                                             sceneWidget: SettingsSceneWidget,
                                             up: Bool) -> Bool
    {
        sceneEditorDrawOrderTargetIndex(scene: scene, sceneWidget: sceneWidget, up: up) != nil
    }

    func sceneEditorMoveWidgetInDrawOrder(scene: SettingsScene, sceneWidget: SettingsSceneWidget, up: Bool) {
        guard let index = scene.widgets.firstIndex(where: { $0.id == sceneWidget.id }),
              let newIndex = sceneEditorDrawOrderTargetIndex(scene: scene, sceneWidget: sceneWidget, up: up)
        else {
            return
        }
        scene.widgets.insert(scene.widgets.remove(at: index), at: newIndex)
        sceneUpdated()
        sceneSettingsPanelSceneId += 1
    }

    func setSceneEditorWidgetOutlinesEnabled(_ enabled: Bool) {
        guard enabled != sceneEditor.enabled else {
            return
        }
        sceneEditor.enabled = enabled
        sceneEditor.imageSizes = [:]
        if enabled {
            updateWidgetOutlines()
        } else {
            sceneEditor.outlines = []
        }
    }

    func updateWidgetOutlines(resolver: SceneResolver? = nil) {
        guard sceneEditor.enabled else {
            return
        }
        guard let scene = sceneEditorScene() else {
            sceneEditor.outlines = []
            return
        }
        let canvasSize = media.getCanvasSize()
        if canvasSize != sceneEditor.canvasSize {
            sceneEditor.canvasSize = canvasSize
        }
        var outlines: [WidgetOutline] = []
        let resolver = resolver ?? makeSceneResolver()
        let resolved = resolver.resolve(scene, includeRemote: true, includeDisabledSceneWidgets: true)
        for drawnWidget in resolved.firstWidgets() where drawnWidget.widget.type == .scene {
            guard scene.widgets.contains(where: { $0 === drawnWidget.sceneWidget }) else {
                continue
            }
            outlines.append(WidgetOutline(sceneWidget: drawnWidget.sceneWidget,
                                          widget: drawnWidget.widget,
                                          rect: CGRect(origin: .zero, size: canvasSize),
                                          alignment: drawnWidget.sceneWidget.layout.alignment,
                                          sized: true,
                                          inScene: true,
                                          enabled: drawnWidget.widget.enabled))
        }
        for drawnWidget in resolved.firstWidgets() {
            let widget = drawnWidget.widget
            guard widget.hasPosition() else {
                continue
            }
            let layout = drawnWidget.sceneWidget.layout
            let size = widgetOutlineSize(widget, layout, canvasSize)
            outlines.append(WidgetOutline(sceneWidget: drawnWidget.sceneWidget,
                                          widget: widget,
                                          rect: CGRect(
                                              origin: layoutPosition(layout, size ?? .zero, canvasSize),
                                              size: size ?? .zero
                                          ),
                                          alignment: layout.alignment,
                                          sized: size != nil,
                                          inScene: drawnWidget.scene === scene,
                                          enabled: drawnWidget.enabled))
        }
        if !widgetOutlinesEqual(outlines, sceneEditor.outlines) {
            sceneEditor.outlines = outlines
        }
    }

    private func widgetOutlineSize(_ widget: SettingsWidget,
                                   _ layout: SettingsWidgetLayout,
                                   _ canvasSize: CGSize) -> CGSize?
    {
        let box = CGSize(width: toPixels(layout.size, canvasSize.width),
                         height: toPixels(layout.size, canvasSize.height))
        let side = toPixels(layout.size, canvasSize.minimum())
        switch widget.type {
        case .map, .qrCode:
            return CGSize(width: side, height: side)
        case .bingoCard:
            return CGSize(width: side + 10, height: side + 10)
        case .browser:
            return fitInLayout(
                CGSize(width: Double(widget.browser.width), height: Double(widget.browser.height)),
                layout,
                canvasSize
            ) ?? box
        case .image:
            guard let imageSize = widgetImageSize(widget) else {
                return box
            }
            return fitInLayout(imageSize, layout, canvasSize) ?? box
        case .chatEmoteCombo:
            return CGSize(width: 2 * side, height: side)
        case .pomodoroTimer:
            return CGSize(width: widget.pomodoroTimer.width * side, height: 0.64 * side)
        case .wheelOfLuck:
            let wheelSide = 400 * canvasSize.width / 1920
            return CGSize(width: wheelSide + 0.3 * wheelSide / 12, height: wheelSide)
        case .chat:
            return CGSize(width: 20 * Double(widget.chat.fontSize),
                          height: Double(widget.chat.height) * canvasSize.height)
        case .videoSource, .snapshot, .slideshow, .vTuber, .pngTuber:
            return box
        case .text, .alerts, .scoreboard, .crop, .scene:
            return nil
        }
    }

    private func fitInLayout(_ size: CGSize, _ layout: SettingsWidgetLayout,
                             _ canvasSize: CGSize) -> CGSize?
    {
        guard size.width > 0, size.height > 0 else {
            return nil
        }
        let scale = layoutScale(layout, size, canvasSize)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    func imageWidgetUpdated(id: UUID) {
        sceneEditor.imageSizes.removeValue(forKey: id)
        updateWidgetOutlines()
    }

    private func widgetImageSize(_ widget: SettingsWidget) -> CGSize? {
        if let size = sceneEditor.imageSizes[widget.id] {
            return size
        }
        let size = readImageSize(url: imageStorage.makePath(id: widget.id))
        sceneEditor.imageSizes[widget.id] = size
        return size
    }

    private func readImageSize(url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Double,
              let height = properties[kCGImagePropertyPixelHeight] as? Double
        else {
            return nil
        }
        let orientation = properties[kCGImagePropertyOrientation] as? UInt32 ?? 1
        if orientation >= 5 {
            return CGSize(width: height, height: width)
        } else {
            return CGSize(width: width, height: height)
        }
    }

    private func widgetOutlinesEqual(_ first: [WidgetOutline], _ second: [WidgetOutline]) -> Bool {
        guard first.count == second.count else {
            return false
        }
        return zip(first, second).allSatisfy {
            $0.sceneWidget === $1.sceneWidget
                && $0.widget === $1.widget
                && $0.rect == $1.rect
                && $0.alignment == $1.alignment
                && $0.sized == $1.sized
                && $0.inScene == $1.inScene
                && $0.enabled == $1.enabled
        }
    }
}
