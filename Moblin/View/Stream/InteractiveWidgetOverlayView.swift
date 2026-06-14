import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Interactive Widget Overlay View

// This view overlays the video preview and allows users to select, drag, resize,
// and manage widgets using touch gestures (tap, drag, pinch).
//
// Architecture:
// - Tap to select/deselect widgets
// - Single-finger drag to move selected widget
// - Two-finger pinch to resize selected widget
// - Corner handles for precise resize
// - Snapping to edges and center guides with haptic feedback
// - HUD toolbar for z-ordering, locking, and deletion

struct InteractiveWidgetOverlayView: View {
    @ObservedObject var model: Model
    let previewSize: CGSize

    // Drag state
    @State private var activeDragWidgetId: UUID?
    @State private var dragStartLayoutX: Double = 0.0
    @State private var dragStartLayoutY: Double = 0.0
    @State private var dragStartTranslationX: CGFloat = 0.0
    @State private var dragStartTranslationY: CGFloat = 0.0
    @State private var lastDragUpdate: Date = .init()

    // Pinch state
    @State private var pinchStartSize: Double = 0.0
    @State private var isPinching: Bool = false

    // Snapping states
    @State private var activeSnapX: CGFloat?
    @State private var activeSnapY: CGFloat?
    @State private var hasHapticedX: Bool = false
    @State private var hasHapticedY: Bool = false

    // Corner resizing states
    @State private var activeResizeHandle: String?
    @State private var resizeStartRect: CGRect = .zero
    @State private var resizeStartSize: Double = 0.0
    @State private var resizeStartLayoutX: Double = 0.0
    @State private var resizeStartLayoutY: Double = 0.0

    private let snapThreshold: CGFloat = 4.0

    // MARK: - Haptic Feedback

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
        let (widgetWidth, widgetHeight) = getWidgetDimensions(
            widgetInScene: widgetInScene,
            videoBounds: videoBounds
        )

        // Mirror the move logic from EffectUtils.swift
        var wX: CGFloat
        var wY: CGFloat

        if layout.alignment.isHorizontalCenter() {
            wX = videoBounds.minX + (videoBounds.width - widgetWidth) / 2
        } else if layout.alignment.isLeft() {
            wX = videoBounds.minX + CGFloat(layout.x / 100.0) * videoBounds.width
        } else { // Right
            wX = videoBounds.minX + videoBounds.width - CGFloat(layout.x / 100.0) * videoBounds
                .width - widgetWidth
        }

        if layout.alignment.isVerticalCenter() {
            wY = videoBounds.minY + (videoBounds.height - widgetHeight) / 2
        } else if layout.alignment.isTop() {
            wY = videoBounds.minY + CGFloat(layout.y / 100.0) * videoBounds.height
        } else { // Bottom
            wY = videoBounds.minY + videoBounds.height - CGFloat(layout.y / 100.0) * videoBounds
                .height - widgetHeight
        }

        return CGRect(x: wX, y: wY, width: widgetWidth, height: widgetHeight)
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

    // MARK: - Layout Conversion

    /// Convert any alignment mode to topLeft for direct position manipulation during gestures.
    /// This ensures consistent coordinate math regardless of the widget's original alignment.
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

    // MARK: - Snapping Logic

    private func applySnapping(
        candidateMinX: inout CGFloat,
        candidateMinY: inout CGFloat,
        widgetWidth: CGFloat,
        widgetHeight: CGFloat,
        videoBounds: CGRect
    ) {
        // Vertical snap guides (left, center, right)
        var snapLineX: CGFloat?
        let leftDiff = abs(candidateMinX - videoBounds.minX)
        let centerDiff = abs((candidateMinX + widgetWidth / 2) - videoBounds.midX)
        let rightDiff = abs((candidateMinX + widgetWidth) - videoBounds.maxX)

        if leftDiff < snapThreshold {
            candidateMinX = videoBounds.minX
            snapLineX = videoBounds.minX
        } else if centerDiff < snapThreshold {
            candidateMinX = videoBounds.midX - widgetWidth / 2
            snapLineX = videoBounds.midX
        } else if rightDiff < snapThreshold {
            candidateMinX = videoBounds.maxX - widgetWidth
            snapLineX = videoBounds.maxX
        }

        // Horizontal snap guides (top, center, bottom)
        var snapLineY: CGFloat?
        let topDiff = abs(candidateMinY - videoBounds.minY)
        let centerVDiff = abs((candidateMinY + widgetHeight / 2) - videoBounds.midY)
        let bottomDiff = abs((candidateMinY + widgetHeight) - videoBounds.maxY)

        if topDiff < snapThreshold {
            candidateMinY = videoBounds.minY
            snapLineY = videoBounds.minY
        } else if centerVDiff < snapThreshold {
            candidateMinY = videoBounds.midY - widgetHeight / 2
            snapLineY = videoBounds.midY
        } else if bottomDiff < snapThreshold {
            candidateMinY = videoBounds.maxY - widgetHeight
            snapLineY = videoBounds.maxY
        }

        // Haptic feedback on snap engage/disengage
        if snapLineX != nil {
            if !hasHapticedX {
                triggerHaptic()
                hasHapticedX = true
            }
        } else {
            hasHapticedX = false
        }

        if snapLineY != nil {
            if !hasHapticedY {
                triggerHaptic()
                hasHapticedY = true
            }
        } else {
            hasHapticedY = false
        }

        activeSnapX = snapLineX
        activeSnapY = snapLineY
    }

    // MARK: - Widget Dimensions Helper

    private func getWidgetDimensions(widgetInScene: WidgetInScene,
                                     videoBounds: CGRect) -> (CGFloat, CGFloat)
    {
        if widgetInScene.widget.type == .text {
            let fontSize = CGFloat(widgetInScene.widget.text.fontSizeFloat)
            // The text rendered height is roughly fontSize * scale.
            let scale = videoBounds.width / 1920.0
            let estHeight = max(fontSize * scale * 1.2, 24) // Minimum 24pt height
            let estWidth = max(estHeight * 2.5, 60) // Aspect 2.5:1 width
            return (estWidth, estHeight)
        }

        let layout = widgetInScene.sceneWidget.layout
        let aspect = getWidgetAspectRatio(widget: widgetInScene.widget)
        let streamAspect = model.stream.dimensions().aspectRatio()

        var widgetWidth: CGFloat
        var widgetHeight: CGFloat
        if streamAspect < aspect {
            widgetWidth = CGFloat(layout.size / 100.0) * videoBounds.width
            widgetHeight = widgetWidth / aspect
        } else {
            widgetHeight = CGFloat(layout.size / 100.0) * videoBounds.height
            widgetWidth = widgetHeight * aspect
        }
        return (widgetWidth, widgetHeight)
    }

    // MARK: - Corner Resize Handles

    private func cornerHandle(
        x: CGFloat,
        y: CGFloat,
        handle: String,
        widgetInScene: WidgetInScene,
        rect: CGRect,
        videoBounds: CGRect
    ) -> some View {
        let handleSize: CGFloat = 12
        return Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .stroke(Color.black, lineWidth: 1)
            )
            .contentShape(Circle().scale(2.0)) // Larger hit area for easier touch
            .position(x: x, y: y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { value in
                        var layout = widgetInScene.sceneWidget.layout
                        guard !layout.positioningLock else { return }

                        if activeResizeHandle != handle {
                            activeResizeHandle = handle
                            convertToTopLeft(
                                widgetInScene: widgetInScene,
                                rect: rect,
                                videoBounds: videoBounds
                            )
                            layout = widgetInScene.sceneWidget.layout
                            resizeStartRect = rect
                            resizeStartSize = layout.size
                            resizeStartLayoutX = layout.x
                            resizeStartLayoutY = layout.y
                        }
                        let aspect = getWidgetAspectRatio(widget: widgetInScene.widget)
                        let streamAspect = model.stream.dimensions().aspectRatio()

                        var newWidth: CGFloat
                        var newHeight: CGFloat

                        switch handle {
                        case "bottomRight":
                            newWidth = max(20, resizeStartRect.width + value.translation.width)
                            newHeight = max(20, resizeStartRect.height + value.translation.height)

                            let newSize = if streamAspect < aspect {
                                Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1 ... 100)
                            layout.updateSizeString()

                        case "bottomLeft":
                            newWidth = max(20, resizeStartRect.width - value.translation.width)
                            newHeight = max(20, resizeStartRect.height + value.translation.height)

                            let newSize = if streamAspect < aspect {
                                Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1 ... 100)
                            layout.updateSizeString()
                            layout.x = max(
                                0.0,
                                Double((resizeStartRect.maxX - newWidth - videoBounds.minX) / videoBounds
                                    .width) * 100.0
                            )
                            layout.updateXString()

                        case "topRight":
                            newWidth = max(20, resizeStartRect.width + value.translation.width)
                            newHeight = max(20, resizeStartRect.height - value.translation.height)

                            let newSize = if streamAspect < aspect {
                                Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1 ... 100)
                            layout.updateSizeString()
                            layout.y = max(
                                0.0,
                                Double((resizeStartRect.maxY - newHeight - videoBounds.minY) / videoBounds
                                    .height) * 100.0
                            )
                            layout.updateYString()

                        case "topLeft":
                            newWidth = max(20, resizeStartRect.width - value.translation.width)
                            newHeight = max(20, resizeStartRect.height - value.translation.height)

                            let newSize = if streamAspect < aspect {
                                Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1 ... 100)
                            layout.updateSizeString()
                            layout.x = max(
                                0.0,
                                Double((resizeStartRect.maxX - newWidth - videoBounds.minX) / videoBounds
                                    .width) * 100.0
                            )
                            layout.updateXString()
                            layout.y = max(
                                0.0,
                                Double((resizeStartRect.maxY - newHeight - videoBounds.minY) / videoBounds
                                    .height) * 100.0
                            )
                            layout.updateYString()

                        default:
                            return
                        }

                        widgetInScene.sceneWidget.layout = layout
                        model.updateWidgetLayoutDirectly(
                            widgetId: widgetInScene.widget.id,
                            sceneWidget: widgetInScene.sceneWidget
                        )
                    }
                    .onEnded { _ in
                        activeResizeHandle = nil
                        model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
                    }
            )
    }

    // MARK: - HUD Toolbar

    private func hudToolbar(widgetInScene: WidgetInScene, rect: CGRect) -> some View {
        let isLocked = widgetInScene.sceneWidget.layout.positioningLock
        let toolbarHeight: CGFloat = 38

        let xPos = rect.midX
        let yPos = rect
            .minY < 60 ? (rect.maxY + toolbarHeight / 2 + 12) : (rect.minY - toolbarHeight / 2 - 12)

        return HStack(spacing: 12) {
            Button(action: {
                triggerHaptic()
                model.objectWillChange.send()
                widgetInScene.sceneWidget.layout.positioningLock.toggle()
                model.storeSettings()
                model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
            }, label: {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isLocked ? .red : .white)
            })
        }
        .padding(.horizontal, 14)
        .frame(height: toolbarHeight)
        .background(Color.black.opacity(0.85))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 6, x: 0, y: 3)
        .position(x: xPos, y: yPos)
    }

    // MARK: - Widget Item View

    @ViewBuilder
    private func widgetItemView(widgetInScene: WidgetInScene, rect: CGRect,
                                videoBounds: CGRect) -> some View
    {
        let isSelected = model.selectedWidgetForInteraction?.id == widgetInScene.id
        let isClickable = widgetInScene.sceneWidget.layout.clickable
        let isLocked = widgetInScene.sceneWidget.layout.positioningLock
        let isEnabled = widgetInScene.widget.enabled

        // Widget bounding box with visual feedback
        ZStack {
            // Transparent fill covering the minimum 44x44 touch area
            Color.black.opacity(0.001)

            // Selection outline and content sized to the actual widget rect
            ZStack {
                if isSelected {
                    if widgetInScene.widget.hasSize() {
                        Rectangle()
                            .stroke(
                                !isEnabled ? Color.white :
                                    (!isClickable ? Color.gray.opacity(0.4) : Color.white),
                                style: StrokeStyle(lineWidth: 1.5)
                            )
                            .background(Color.white.opacity(0.25))
                    } else {
                        // Show a move icon in the center for select / drag when it has no layout size setting
                        Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.white.opacity(0.4))
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1.5)
                            )
                    }

                    // Widget name label
                    VStack(spacing: 2) {
                        let labelText: String = {
                            var text = widgetInScene.widget.name
                            if !isClickable {
                                text += " (Not Clickable)"
                            }
                            if isLocked {
                                text += " (Locked)"
                            }
                            if !isEnabled {
                                text += " (Hidden)"
                            }
                            return text
                        }()
                        Text(labelText)
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(!isEnabled ? Color.orange :
                                (isLocked ? Color.red :
                                    (!isClickable ? Color.gray : Color.black.opacity(0.85))))
                            .cornerRadius(4)
                        Spacer()
                    }
                    .padding(.top, widgetInScene.widget.hasSize() ? -22 : -28)
                }
            }
            .frame(
                width: widgetInScene.widget.hasSize() ? max(rect.width, 10) : 44,
                height: widgetInScene.widget.hasSize() ? max(rect.height, 10) : 44
            )
        }
        .frame(
            width: widgetInScene.widget.hasSize() ? max(rect.width, 44) : 44,
            height: widgetInScene.widget.hasSize() ? max(rect.height, 44) : 44
        )
        .contentShape(Rectangle())
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(true)
        // Unified gesture handling both TAP and DRAG + PINCH
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .global)
                .onChanged { value in
                    guard !isPinching else { return }

                    let dx = value.translation.width
                    let dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)

                    // Only move if we exceed the drag threshold of 5 points
                    if distance > 5 {
                        // Initialize drag state on actual drag start
                        if activeDragWidgetId != widgetInScene.id {
                            activeDragWidgetId = widgetInScene.id
                            // Convert to topLeft alignment for consistent math
                            convertToTopLeft(
                                widgetInScene: widgetInScene,
                                rect: rect,
                                videoBounds: videoBounds
                            )
                            let layout = widgetInScene.sceneWidget.layout
                            dragStartLayoutX = layout.x
                            dragStartLayoutY = layout.y
                            dragStartTranslationX = dx
                            dragStartTranslationY = dy
                        }

                        // Auto-select on drag start
                        if model.selectedWidgetForInteraction?.id != widgetInScene.id {
                            triggerHaptic()
                            model.selectedWidgetForInteraction = widgetInScene
                        }

                        var layout = widgetInScene.sceneWidget.layout
                        guard !layout.positioningLock else { return }

                        let (widgetWidth, widgetHeight) = getWidgetDimensions(
                            widgetInScene: widgetInScene,
                            videoBounds: videoBounds
                        )

                        let effectiveDx = dx - dragStartTranslationX
                        let effectiveDy = dy - dragStartTranslationY

                        var candidateMinX = videoBounds.minX + CGFloat(dragStartLayoutX / 100.0) * videoBounds
                            .width + effectiveDx
                        var candidateMinY = videoBounds.minY + CGFloat(dragStartLayoutY / 100.0) * videoBounds
                            .height + effectiveDy

                        // Apply snapping
                        applySnapping(
                            candidateMinX: &candidateMinX,
                            candidateMinY: &candidateMinY,
                            widgetWidth: widgetWidth,
                            widgetHeight: widgetHeight,
                            videoBounds: videoBounds
                        )

                        // Convert back to percentage
                        layout.x = max(
                            0.0,
                            Double((candidateMinX - videoBounds.minX) / videoBounds.width) * 100.0
                        )
                        layout.y = max(
                            0.0,
                            Double((candidateMinY - videoBounds.minY) / videoBounds.height) * 100.0
                        )
                        layout.updateXString()
                        layout.updateYString()

                        widgetInScene.sceneWidget.layout = layout

                        let now = Date()
                        if now.timeIntervalSince(lastDragUpdate) > 0.033 {
                            model.updateWidgetLayoutDirectly(
                                widgetId: widgetInScene.widget.id,
                                sceneWidget: widgetInScene.sceneWidget
                            )
                            lastDragUpdate = now
                        }
                    }
                }
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    let distance = sqrt(dx * dx + dy * dy)

                    // If user tapped without dragging, toggle selection (and we were not pinching)
                    if distance <= 5, !isPinching {
                        triggerHaptic()
                        if model.selectedWidgetForInteraction?.id == widgetInScene.id {
                            model.selectedWidgetForInteraction = nil
                        } else {
                            model.selectedWidgetForInteraction = widgetInScene
                        }
                    } else if distance > 5 {
                        // Force final layout sync
                        model.updateWidgetLayoutDirectly(
                            widgetId: widgetInScene.widget.id,
                            sceneWidget: widgetInScene.sceneWidget
                        )
                    }

                    isPinching = false
                    activeDragWidgetId = nil
                    activeSnapX = nil
                    activeSnapY = nil
                    hasHapticedX = false
                    hasHapticedY = false
                    model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
                }
                .simultaneously(with:
                    MagnificationGesture()
                        .onChanged { scale in
                            isPinching = true
                            // Auto-select on pinch
                            if model.selectedWidgetForInteraction?.id != widgetInScene.id {
                                triggerHaptic()
                                model.selectedWidgetForInteraction = widgetInScene
                            }

                            var layout = widgetInScene.sceneWidget.layout
                            guard !layout.positioningLock else { return }

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
                            model.updateWidgetLayoutDirectly(
                                widgetId: widgetInScene.widget.id,
                                sceneWidget: widgetInScene.sceneWidget
                            )
                        }
                        .onEnded { _ in
                            pinchStartSize = 0
                            model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
                        })
        )
    }

    // MARK: - Body

    var body: some View {
        if model.editWidgetsMode {
            let videoBounds = getVideoBounds()
            let widgets = model.widgetsInCurrentScene(onlyEnabled: false)

            ZStack {
                // Background overlay to deselect when tapping empty space
                Color.black.opacity(0.15)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        model.selectedWidgetForInteraction = nil
                    }

                // Snap guide lines (yellow dashed)
                if let snapX = activeSnapX {
                    Path { path in
                        path.move(to: CGPoint(x: snapX, y: 0))
                        path.addLine(to: CGPoint(x: snapX, y: previewSize.height))
                    }
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .allowsHitTesting(false)
                }
                if let snapY = activeSnapY {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: snapY))
                        path.addLine(to: CGPoint(x: previewSize.width, y: snapY))
                    }
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .allowsHitTesting(false)
                }

                // Widget interaction areas
                ForEach(widgets) { widgetInScene in
                    let rect = getWidgetRect(widgetInScene: widgetInScene, videoBounds: videoBounds)
                    let isSelected = model.selectedWidgetForInteraction?.id == widgetInScene.id

                    widgetItemView(widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)

                    // Corner handles and HUD for the selected widget
                    if isSelected {
                        if widgetInScene.widget.hasSize() {
                            Group {
                                cornerHandle(
                                    x: rect.minX,
                                    y: rect.minY,
                                    handle: "topLeft",
                                    widgetInScene: widgetInScene,
                                    rect: rect,
                                    videoBounds: videoBounds
                                )
                                cornerHandle(
                                    x: rect.maxX,
                                    y: rect.minY,
                                    handle: "topRight",
                                    widgetInScene: widgetInScene,
                                    rect: rect,
                                    videoBounds: videoBounds
                                )
                                cornerHandle(
                                    x: rect.minX,
                                    y: rect.maxY,
                                    handle: "bottomLeft",
                                    widgetInScene: widgetInScene,
                                    rect: rect,
                                    videoBounds: videoBounds
                                )
                                cornerHandle(
                                    x: rect.maxX,
                                    y: rect.maxY,
                                    handle: "bottomRight",
                                    widgetInScene: widgetInScene,
                                    rect: rect,
                                    videoBounds: videoBounds
                                )
                            }
                        }

                        hudToolbar(widgetInScene: widgetInScene, rect: rect)
                    }
                }
            }
        }
    }
}
