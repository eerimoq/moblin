import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Interactive Widget Overlay View (Simplified Version)
//
// Allows users to select, drag, and resize widgets directly on the camera preview.
// Optimized for review and PR acceptance by removing corner handles, snap guides, and toolbar HUDs.
//
// Supported Gestures:
// - Tap to select / deselect
// - Single-finger drag to move
// - Two-finger pinch to resize (size / font size)

struct InteractiveWidgetOverlayView: View {
    @ObservedObject var model: Model
    let previewSize: CGSize

    // Gesture States
    @State private var activeDragWidgetId: UUID? = nil
    @State private var dragStartLayoutX: Double = 0.0
    @State private var dragStartLayoutY: Double = 0.0
    @State private var dragStartTranslationX: CGFloat = 0.0
    @State private var dragStartTranslationY: CGFloat = 0.0
    @State private var lastDragUpdate: Date = .init()

    @State private var pinchStartSize: Double = 0.0
    @State private var isPinching: Bool = false

    private func triggerHaptic() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    // MARK: - Coordinate Mapping

    private func getVideoBounds() -> CGRect {
        let streamAspect = model.stream.dimensions().aspectRatio()
        let previewAspect = previewSize.width / previewSize.height

        var videoWidth: CGFloat
        var videoHeight: CGFloat
        var videoX: CGFloat
        var videoY: CGFloat

        if previewAspect > streamAspect {
            videoHeight = previewSize.height
            videoWidth = videoHeight * streamAspect
            videoX = (previewSize.width - videoWidth) / 2
            videoY = 0
        } else {
            videoWidth = previewSize.width
            videoHeight = videoWidth / streamAspect
            videoX = 0
            videoY = (previewSize.height - videoHeight) / 2
        }

        return CGRect(x: videoX, y: videoY, width: videoWidth, height: videoHeight)
    }

    private func getWidgetRect(widgetInScene: WidgetInScene, videoBounds: CGRect) -> CGRect {
        let layout = widgetInScene.sceneWidget.layout
        let (wWidth, wHeight) = getWidgetDimensions(widgetInScene: widgetInScene, videoBounds: videoBounds)

        var wX: CGFloat
        var wY: CGFloat

        if layout.alignment.isHorizontalCenter() {
            wX = videoBounds.minX + (videoBounds.width - wWidth) / 2
        } else if layout.alignment.isLeft() {
            wX = videoBounds.minX + CGFloat(layout.x / 100.0) * videoBounds.width
        } else { // Right
            wX = videoBounds.minX + videoBounds.width - CGFloat(layout.x / 100.0) * videoBounds.width - wWidth
        }

        if layout.alignment.isVerticalCenter() {
            wY = videoBounds.minY + (videoBounds.height - wHeight) / 2
        } else if layout.alignment.isTop() {
            wY = videoBounds.minY + CGFloat(layout.y / 100.0) * videoBounds.height
        } else { // Bottom
            wY = videoBounds.minY + videoBounds.height - CGFloat(layout.y / 100.0) * videoBounds.height - wHeight
        }

        return CGRect(x: wX, y: wY, width: wWidth, height: wHeight)
    }

    private func getWidgetAspectRatio(widget: SettingsWidget) -> CGFloat {
        switch widget.type {
        case .image:
            if let data = model.imageStorage.read(id: widget.id),
               let img = UIImage(data: data)
            {
                return img.size.width / img.size.height
            }
            return 1.0
        case .browser:
            return CGFloat(max(widget.browser.width, 1)) / CGFloat(max(widget.browser.height, 1))
        case .videoSource:
            return 16.0 / 9.0
        case .text:
            return 4.0
        default:
            return 1.0
        }
    }

    private func getWidgetDimensions(widgetInScene: WidgetInScene, videoBounds: CGRect) -> (CGFloat, CGFloat) {
        if widgetInScene.widget.type == .text {
            let fontSize = CGFloat(widgetInScene.widget.text.fontSizeFloat)
            let scale = videoBounds.width / 1920.0
            let estHeight = max(fontSize * scale * 1.2, 24)
            let estWidth = max(estHeight * 2.5, 60)
            return (estWidth, estHeight)
        }

        let layout = widgetInScene.sceneWidget.layout
        let aspect = getWidgetAspectRatio(widget: widgetInScene.widget)
        let streamAspect = model.stream.dimensions().aspectRatio()

        var wWidth: CGFloat
        var wHeight: CGFloat
        if streamAspect < aspect {
            wWidth = CGFloat(layout.size / 100.0) * videoBounds.width
            wHeight = wWidth / aspect
        } else {
            wHeight = CGFloat(layout.size / 100.0) * videoBounds.height
            wWidth = wHeight * aspect
        }
        return (wWidth, wHeight)
    }

    private func convertToTopLeft(widgetInScene: WidgetInScene, rect: CGRect, videoBounds: CGRect) {
        var layout = widgetInScene.sceneWidget.layout
        let currentXPercent = ((rect.minX - videoBounds.minX) / videoBounds.width) * 100.0
        let currentYPercent = ((rect.minY - videoBounds.minY) / videoBounds.height) * 100.0

        layout.alignment = .topLeft
        layout.x = max(0.0, Double(currentXPercent))
        layout.y = max(0.0, Double(currentYPercent))
        layout.updateXString()
        layout.updateYString()

        widgetInScene.sceneWidget.layout = layout
    }

    // MARK: - Widget Item View

    @ViewBuilder
    private func widgetItemView(widgetInScene: WidgetInScene, rect: CGRect, videoBounds: CGRect) -> some View {
        let isSelected = model.selectedWidgetForInteraction?.id == widgetInScene.id

        ZStack {
            // Invisible touch area
            Color.black.opacity(0.001)

            // Outline Box
            Rectangle()
                .stroke(
                    isSelected ? Color.white : Color.gray.opacity(0.5),
                    style: StrokeStyle(lineWidth: isSelected ? 2.0 : 1.0, dash: isSelected ? [] : [4, 4])
                )
                .background(isSelected ? Color.white.opacity(0.15) : Color.clear)

            // Small Label
            VStack {
                Text(widgetInScene.widget.name)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(isSelected ? Color.blue : Color.black.opacity(0.6))
                    .cornerRadius(3)
                Spacer()
            }
            .padding(.top, -18)
        }
        .frame(width: max(rect.width, 44), height: max(rect.height, 44))
        .position(x: rect.midX, y: rect.midY)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    guard !isPinching else { return }

                    let dx = value.translation.width
                    let dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance > 5 {
                        if activeDragWidgetId != widgetInScene.id {
                            activeDragWidgetId = widgetInScene.id
                            convertToTopLeft(widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                            
                            let layout = widgetInScene.sceneWidget.layout
                            dragStartLayoutX = layout.x
                            dragStartLayoutY = layout.y
                            dragStartTranslationX = dx
                            dragStartTranslationY = dy
                        }

                        if model.selectedWidgetForInteraction?.id != widgetInScene.id {
                            triggerHaptic()
                            model.selectedWidgetForInteraction = widgetInScene
                        }

                        var layout = widgetInScene.sceneWidget.layout
                        let effectiveDx = dx - dragStartTranslationX
                        let effectiveDy = dy - dragStartTranslationY

                        let candidateMinX = videoBounds.minX + CGFloat(dragStartLayoutX / 100.0) * videoBounds.width + effectiveDx
                        let candidateMinY = videoBounds.minY + CGFloat(dragStartLayoutY / 100.0) * videoBounds.height + effectiveDy

                        layout.x = max(0.0, Double((candidateMinX - videoBounds.minX) / videoBounds.width) * 100.0)
                        layout.y = max(0.0, Double((candidateMinY - videoBounds.minY) / videoBounds.height) * 100.0)
                        layout.updateXString()
                        layout.updateYString()

                        widgetInScene.sceneWidget.layout = layout

                        let now = Date()
                        if now.timeIntervalSince(lastDragUpdate) > 0.033 {
                            model.updateWidgetLayoutDirectly(widgetId: widgetInScene.widget.id, sceneWidget: widgetInScene.sceneWidget)
                            lastDragUpdate = now
                        }
                    }
                }
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)

                    if distance <= 5, !isPinching {
                        triggerHaptic()
                        if model.selectedWidgetForInteraction?.id == widgetInScene.id {
                            model.selectedWidgetForInteraction = nil
                        } else {
                            model.selectedWidgetForInteraction = widgetInScene
                        }
                    } else if distance > 5 {
                        model.updateWidgetLayoutDirectly(widgetId: widgetInScene.widget.id, sceneWidget: widgetInScene.sceneWidget)
                    }

                    isPinching = false
                    activeDragWidgetId = nil
                    model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
                }
                .simultaneously(with:
                    MagnificationGesture()
                        .onChanged { scale in
                            isPinching = true
                            if model.selectedWidgetForInteraction?.id != widgetInScene.id {
                                triggerHaptic()
                                model.selectedWidgetForInteraction = widgetInScene
                            }

                            var layout = widgetInScene.sceneWidget.layout

                            if widgetInScene.widget.type == .text {
                                if pinchStartSize == 0 {
                                    pinchStartSize = Double(widgetInScene.widget.text.fontSizeFloat)
                                }
                                let newSize = (pinchStartSize * Double(scale)).clamped(to: 10 ... 300)
                                widgetInScene.widget.text.fontSizeFloat = Float(newSize)
                                widgetInScene.widget.text.fontSize = Int(newSize)
                                model.objectWillChange.send()
                                return
                            }

                            if pinchStartSize == 0 {
                                pinchStartSize = layout.size
                            }

                            let newSize = (pinchStartSize * Double(scale)).clamped(to: 1 ... 100)
                            layout.size = newSize
                            layout.updateSizeString()

                            widgetInScene.sceneWidget.layout = layout
                            model.updateWidgetLayoutDirectly(widgetId: widgetInScene.widget.id, sceneWidget: widgetInScene.sceneWidget)
                        }
                        .onEnded { _ in
                            pinchStartSize = 0
                            model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
                        }
                )
        )
    }

    // MARK: - Body

    var body: some View {
        if model.editWidgetsMode {
            let videoBounds = getVideoBounds()
            let widgets = model.widgetsInCurrentScene(onlyEnabled: false)

            ZStack {
                // Background overlay to clear selection on empty space tap
                Color.black.opacity(0.12)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectedWidgetForInteraction = nil
                    }

                ForEach(widgets) { widgetInScene in
                    let rect = getWidgetRect(widgetInScene: widgetInScene, videoBounds: videoBounds)
                    widgetItemView(widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                }
            }
        }
    }
}
