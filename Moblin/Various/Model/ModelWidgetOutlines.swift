import Foundation
import ImageIO

extension Model {
    func showWidgetOutlines() {
        guard showingPanel == .settings else {
            return
        }
        setWidgetOutlinesEnabled(widgetOutlines, true)
    }

    func hideWidgetOutlines() {
        setWidgetOutlinesEnabled(widgetOutlines, false)
    }

    func updateWidgetOutlinesForShowingPanel() {
        setWidgetOutlinesEnabled(widgetOutlines, [.sceneWidgets, .sceneSettings].contains(showingPanel))
    }

    func setSceneEditorWidgetOutlinesEnabled(_ enabled: Bool) {
        setWidgetOutlinesEnabled(sceneEditorWidgetOutlines, enabled)
    }

    private func setWidgetOutlinesEnabled(_ widgetOutlines: WidgetOutlines, _ enabled: Bool) {
        guard enabled != widgetOutlines.enabled else {
            return
        }
        widgetOutlines.enabled = enabled
        widgetOutlines.imageSizes = [:]
        if enabled {
            updateWidgetOutlines()
        } else {
            widgetOutlines.outlines = []
        }
    }

    func updateWidgetOutlines(resolvedSelectedScene: ResolvedScene? = nil) {
        if widgetOutlines.enabled {
            updateWidgetOutlines(
                widgetOutlines,
                getSelectedScene(),
                resolvedSelectedScene,
                sceneEditor: false
            )
        }
        if sceneEditorWidgetOutlines.enabled {
            updateWidgetOutlines(sceneEditorWidgetOutlines, sceneEditorScene(), nil, sceneEditor: true)
        }
    }

    private func updateWidgetOutlines(_ widgetOutlines: WidgetOutlines,
                                      _ scene: SettingsScene?,
                                      _ resolvedScene: ResolvedScene?,
                                      sceneEditor: Bool)
    {
        guard let scene else {
            widgetOutlines.outlines = []
            return
        }
        let canvasSize = media.getCanvasSize()
        if canvasSize != widgetOutlines.canvasSize {
            widgetOutlines.canvasSize = canvasSize
        }
        var outlines: [WidgetOutline] = []
        let resolved = resolvedScene
            ?? resolveScene(scene, includeRemote: true, includeDisabledSceneWidgets: sceneEditor)
        if sceneEditor {
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
        }
        for drawnWidget in resolved.firstWidgets() {
            let widget = drawnWidget.widget
            guard sceneEditor || drawnWidget.enabled, widget.hasPosition() else {
                continue
            }
            let layout = drawnWidget.sceneWidget.layout
            let size = widgetOutlineSize(widgetOutlines, widget, layout, canvasSize)
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
        if !widgetOutlinesEqual(outlines, widgetOutlines.outlines) {
            widgetOutlines.outlines = outlines
        }
    }

    private func widgetOutlineSize(_ widgetOutlines: WidgetOutlines,
                                   _ widget: SettingsWidget,
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
            guard let imageSize = widgetImageSize(widgetOutlines, widget) else {
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
        widgetOutlines.imageSizes.removeValue(forKey: id)
        sceneEditorWidgetOutlines.imageSizes.removeValue(forKey: id)
        updateWidgetOutlines()
    }

    private func widgetImageSize(_ widgetOutlines: WidgetOutlines, _ widget: SettingsWidget) -> CGSize? {
        if let size = widgetOutlines.imageSizes[widget.id] {
            return size
        }
        let size = readImageSize(url: imageStorage.makePath(id: widget.id))
        widgetOutlines.imageSizes[widget.id] = size
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
