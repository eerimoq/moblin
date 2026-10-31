import Foundation
import ImageIO

extension Model {
    func showWidgetOutlines() {
        guard showingPanel == .settings else {
            return
        }
        setWidgetOutlinesEnabled(true)
    }

    func hideWidgetOutlines() {
        setWidgetOutlinesEnabled(false)
    }

    func updateWidgetOutlinesForShowingPanel() {
        setWidgetOutlinesEnabled([.sceneWidgets, .sceneSettings]
            .contains(showingPanel) || presentingSceneEditor)
    }

    private func setWidgetOutlinesEnabled(_ enabled: Bool) {
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

    func updateWidgetOutlines() {
        guard widgetOutlines.enabled else {
            return
        }
        guard let scene = presentingSceneEditor ? sceneEditorScene() : getSelectedScene() else {
            widgetOutlines.outlines = []
            return
        }
        let canvasSize = media.getCanvasSize()
        if canvasSize != widgetOutlines.canvasSize {
            widgetOutlines.canvasSize = canvasSize
        }
        var outlines: [WidgetOutline] = []
        for drawnWidget in getDrawnSceneWidgets(scene: scene, includeDisabled: presentingSceneEditor) {
            let widget = drawnWidget.widget
            guard widget.hasPosition() else {
                continue
            }
            let layout = drawnWidget.sceneWidget.layout
            let size = widgetOutlineSize(widget: widget, layout: layout, canvasSize: canvasSize)
            outlines.append(WidgetOutline(sceneWidget: drawnWidget.sceneWidget,
                                          widget: widget,
                                          rect: CGRect(
                                              origin: layoutPosition(layout, size ?? .zero, canvasSize),
                                              size: size ?? .zero
                                          ),
                                          sized: size != nil,
                                          inScene: drawnWidget.scene === scene,
                                          enabled: widget.enabled))
        }
        if !widgetOutlinesEqual(outlines, widgetOutlines.outlines) {
            widgetOutlines.outlines = outlines
        }
    }

    private func widgetOutlineSize(widget: SettingsWidget,
                                   layout: SettingsWidgetLayout,
                                   canvasSize: CGSize) -> CGSize?
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
            guard let imageSize = widgetImageSize(widget: widget) else {
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
        updateWidgetOutlines()
    }

    private func widgetImageSize(widget: SettingsWidget) -> CGSize? {
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
                && $0.sized == $1.sized
                && $0.inScene == $1.inScene
                && $0.enabled == $1.enabled
        }
    }
}
