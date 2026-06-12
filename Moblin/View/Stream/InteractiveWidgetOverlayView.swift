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
    @State private var activeDragWidgetId: UUID? = nil
    @State private var dragStartLayoutX: Double = 0.0
    @State private var dragStartLayoutY: Double = 0.0
    @State private var dragAccumulatedX: CGFloat = 0.0
    @State private var dragAccumulatedY: CGFloat = 0.0

    // Pinch state
    @State private var pinchStartSize: Double = 0.0

    // Snapping states
    @State private var activeSnapX: CGFloat? = nil
    @State private var activeSnapY: CGFloat? = nil
    @State private var hasHapticedX: Bool = false
    @State private var hasHapticedY: Bool = false

    // Corner resizing states
    @State private var activeResizeHandle: String? = nil
    @State private var resizeStartRect: CGRect = .zero
    @State private var resizeStartSize: Double = 0.0
    @State private var resizeStartLayoutX: Double = 0.0
    @State private var resizeStartLayoutY: Double = 0.0

    private let snapThreshold: CGFloat = 6.0

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
        let aspect = getWidgetAspectRatio(widget: widgetInScene.widget)
        let streamAspect = model.stream.dimensions().aspectRatio()
        
        var wWidth: CGFloat
        var wHeight: CGFloat

        // Mirror the resizeMirror logic from EffectUtils.swift:
        // scaleX = (size/100 * streamW) / imgW; scaleY = (size/100 * streamH) / imgH
        // scale = min(scaleX, scaleY)
        // When streamAspect < widgetAspect: scaleX < scaleY, so width dominates
        if streamAspect < aspect {
            wWidth = CGFloat(layout.size / 100.0) * videoBounds.width
            wHeight = wWidth / aspect
        } else {
            wHeight = CGFloat(layout.size / 100.0) * videoBounds.height
            wWidth = wHeight * aspect
        }

        // Mirror the move logic from EffectUtils.swift
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
               let img = UIImage(data: data) {
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
        layout.x = Double(currentXPercent).clamped(to: 0...100)
        layout.y = Double(currentYPercent).clamped(to: 0...100)
        layout.updateXString()
        layout.updateYString()
        
        widgetInScene.sceneWidget.layout = layout
    }

    // MARK: - Snapping Logic

    private func applySnapping(
        candidateMinX: inout CGFloat,
        candidateMinY: inout CGFloat,
        wWidth: CGFloat,
        wHeight: CGFloat,
        videoBounds: CGRect
    ) {
        // Vertical snap guides (left, center, right)
        var snapLineX: CGFloat? = nil
        let leftDiff = abs(candidateMinX - videoBounds.minX)
        let centerDiff = abs((candidateMinX + wWidth / 2) - videoBounds.midX)
        let rightDiff = abs((candidateMinX + wWidth) - videoBounds.maxX)
        
        if leftDiff < snapThreshold {
            candidateMinX = videoBounds.minX
            snapLineX = videoBounds.minX
        } else if centerDiff < snapThreshold {
            candidateMinX = videoBounds.midX - wWidth / 2
            snapLineX = videoBounds.midX
        } else if rightDiff < snapThreshold {
            candidateMinX = videoBounds.maxX - wWidth
            snapLineX = videoBounds.maxX
        }

        // Horizontal snap guides (top, center, bottom)
        var snapLineY: CGFloat? = nil
        let topDiff = abs(candidateMinY - videoBounds.minY)
        let centerVDiff = abs((candidateMinY + wHeight / 2) - videoBounds.midY)
        let bottomDiff = abs((candidateMinY + wHeight) - videoBounds.maxY)
        
        if topDiff < snapThreshold {
            candidateMinY = videoBounds.minY
            snapLineY = videoBounds.minY
        } else if centerVDiff < snapThreshold {
            candidateMinY = videoBounds.midY - wHeight / 2
            snapLineY = videoBounds.midY
        } else if bottomDiff < snapThreshold {
            candidateMinY = videoBounds.maxY - wHeight
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

    private func getWidgetDimensions(widgetInScene: WidgetInScene, videoBounds: CGRect) -> (CGFloat, CGFloat) {
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

    // MARK: - Corner Resize Handles

    private func cornerHandle(x: CGFloat, y: CGFloat, handle: String, widgetInScene: WidgetInScene, rect: CGRect, videoBounds: CGRect) -> some View {
        let handleSize: CGFloat = 20
        return Circle()
            .fill(Color.white)
            .frame(width: handleSize, height: handleSize)
            .overlay(
                Circle()
                    .stroke(Color.blue, lineWidth: 2)
            )
            .contentShape(Circle().scale(1.5)) // Larger hit area for easier touch
            .position(x: x, y: y)
            .highPriorityGesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        var layout = widgetInScene.sceneWidget.layout
                        guard !layout.positioningLock else { return }
                        
                        if activeResizeHandle != handle {
                            activeResizeHandle = handle
                            convertToTopLeft(widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                            layout = widgetInScene.sceneWidget.layout
                            resizeStartRect = rect
                            resizeStartSize = layout.size
                            resizeStartLayoutX = layout.x
                            resizeStartLayoutY = layout.y
                        }
                        
                        let currentTouch = value.location
                        let aspect = getWidgetAspectRatio(widget: widgetInScene.widget)
                        let streamAspect = model.stream.dimensions().aspectRatio()
                        
                        var newWidth: CGFloat
                        var newHeight: CGFloat
                        
                        switch handle {
                        case "bottomRight":
                            newWidth = max(20, currentTouch.x - resizeStartRect.minX)
                            newHeight = max(20, currentTouch.y - resizeStartRect.minY)
                            
                            var newSize: Double
                            if streamAspect < aspect {
                                newSize = Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                newSize = Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1...100)
                            layout.updateSizeString()
                            
                        case "bottomLeft":
                            newWidth = max(20, resizeStartRect.maxX - currentTouch.x)
                            newHeight = max(20, currentTouch.y - resizeStartRect.minY)
                            
                            var newSize: Double
                            if streamAspect < aspect {
                                newSize = Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                newSize = Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1...100)
                            layout.updateSizeString()
                            layout.x = Double((resizeStartRect.maxX - newWidth - videoBounds.minX) / videoBounds.width) * 100.0
                            layout.updateXString()
                            
                        case "topRight":
                            newWidth = max(20, currentTouch.x - resizeStartRect.minX)
                            newHeight = max(20, resizeStartRect.maxY - currentTouch.y)
                            
                            var newSize: Double
                            if streamAspect < aspect {
                                newSize = Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                newSize = Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1...100)
                            layout.updateSizeString()
                            layout.y = Double((resizeStartRect.maxY - newHeight - videoBounds.minY) / videoBounds.height) * 100.0
                            layout.updateYString()
                            
                        case "topLeft":
                            newWidth = max(20, resizeStartRect.maxX - currentTouch.x)
                            newHeight = max(20, resizeStartRect.maxY - currentTouch.y)
                            
                            var newSize: Double
                            if streamAspect < aspect {
                                newSize = Double(newWidth / videoBounds.width) * 100.0
                            } else {
                                newSize = Double(newHeight / videoBounds.height) * 100.0
                            }
                            layout.size = newSize.clamped(to: 1...100)
                            layout.updateSizeString()
                            layout.x = Double((resizeStartRect.maxX - newWidth - videoBounds.minX) / videoBounds.width) * 100.0
                            layout.updateXString()
                            layout.y = Double((resizeStartRect.maxY - newHeight - videoBounds.minY) / videoBounds.height) * 100.0
                            layout.updateYString()
                            
                        default:
                            return
                        }
                        
                        widgetInScene.sceneWidget.layout = layout
                        model.updateWidgetLayoutDirectly(widgetId: widgetInScene.widget.id, sceneWidget: widgetInScene.sceneWidget)
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
        let yPos = rect.minY < 60 ? (rect.maxY + toolbarHeight / 2 + 12) : (rect.minY - toolbarHeight / 2 - 12)
        
        return HStack(spacing: 12) {
            Button(action: {
                triggerHaptic()
                model.sendWidgetToBack(widgetId: widgetInScene.widget.id)
            }) {
                Image(systemName: "arrow.down.to.line.compact")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Button(action: {
                triggerHaptic()
                model.bringWidgetToFront(widgetId: widgetInScene.widget.id)
            }) {
                Image(systemName: "arrow.up.to.line.compact")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            Divider()
                .frame(width: 1, height: 18)
                .background(Color.white.opacity(0.3))
            
            Button(action: {
                triggerHaptic()
                widgetInScene.sceneWidget.layout.positioningLock.toggle()
                model.sceneUpdated(attachCamera: false, updateRemoteScene: true)
            }) {
                Image(systemName: isLocked ? "lock.fill" : "lock.open.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isLocked ? .red : .white)
            }
            
            Divider()
                .frame(width: 1, height: 18)
                .background(Color.white.opacity(0.3))
            
            Button(action: {
                triggerHaptic()
                model.deleteWidgetFromScene(widgetId: widgetInScene.widget.id)
            }) {
                Image(systemName: "trash.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)
            }
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
    private func widgetItemView(widgetInScene: WidgetInScene, rect: CGRect, videoBounds: CGRect) -> some View {
        let isSelected = model.selectedWidgetForInteraction?.id == widgetInScene.id
        let isClickable = widgetInScene.sceneWidget.layout.clickable
        let isLocked = widgetInScene.sceneWidget.layout.positioningLock

        // Widget bounding box with visual feedback
        ZStack {
            // Transparent fill for full-area hit testing
            Color.black.opacity(0.001)

            // Selection outline
            Rectangle()
                .stroke(
                    !isClickable ? Color.gray.opacity(0.4) : (isSelected ? Color.blue : Color.white.opacity(0.7)),
                    style: StrokeStyle(lineWidth: isSelected ? 2.5 : 1.5, dash: isSelected ? [] : [5, 3])
                )
                .background(isSelected ? Color.blue.opacity(0.08) : Color.clear)
            
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
                    return text
                }()
                Text(labelText)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(isLocked ? Color.red : (!isClickable ? Color.gray : (isSelected ? Color.blue : Color.black.opacity(0.7))))
                    .cornerRadius(4)
                Spacer()
            }
            .padding(.top, -22)
        }
        .frame(width: max(rect.width, 10), height: max(rect.height, 10))
        .contentShape(Rectangle())
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(true)
        // TAP: Select widget on single tap
        .onTapGesture {
            triggerHaptic()
            if model.selectedWidgetForInteraction?.id == widgetInScene.id {
                // Tapping again deselects
                model.selectedWidgetForInteraction = nil
            } else {
                model.selectedWidgetForInteraction = widgetInScene
            }
        }
        // DRAG & PINCH composed simultaneously
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    // Auto-select on drag start
                    if model.selectedWidgetForInteraction?.id != widgetInScene.id {
                        triggerHaptic()
                        model.selectedWidgetForInteraction = widgetInScene
                    }
                    
                    var layout = widgetInScene.sceneWidget.layout
                    guard !layout.positioningLock else { return }

                    // Initialize drag state
                    if activeDragWidgetId != widgetInScene.id {
                        activeDragWidgetId = widgetInScene.id
                        // Convert to topLeft alignment for consistent math
                        convertToTopLeft(widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                        layout = widgetInScene.sceneWidget.layout
                        dragStartLayoutX = layout.x
                        dragStartLayoutY = layout.y
                        dragAccumulatedX = 0
                        dragAccumulatedY = 0
                    }

                    // Use translation which is relative to the start of the gesture
                    let dx = value.translation.width
                    let dy = value.translation.height

                    let (wWidth, wHeight) = getWidgetDimensions(widgetInScene: widgetInScene, videoBounds: videoBounds)

                    var candidateMinX = videoBounds.minX + CGFloat(dragStartLayoutX / 100.0) * videoBounds.width + dx
                    var candidateMinY = videoBounds.minY + CGFloat(dragStartLayoutY / 100.0) * videoBounds.height + dy

                    // Apply snapping
                    applySnapping(
                        candidateMinX: &candidateMinX,
                        candidateMinY: &candidateMinY,
                        wWidth: wWidth,
                        wHeight: wHeight,
                        videoBounds: videoBounds
                    )

                    // Convert back to percentage
                    layout.x = Double((candidateMinX - videoBounds.minX) / videoBounds.width) * 100.0
                    layout.y = Double((candidateMinY - videoBounds.minY) / videoBounds.height) * 100.0
                    layout.updateXString()
                    layout.updateYString()

                    widgetInScene.sceneWidget.layout = layout
                    model.updateWidgetLayoutDirectly(widgetId: widgetInScene.widget.id, sceneWidget: widgetInScene.sceneWidget)
                }
                .onEnded { _ in
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
                            // Auto-select on pinch
                            if model.selectedWidgetForInteraction?.id != widgetInScene.id {
                                triggerHaptic()
                                model.selectedWidgetForInteraction = widgetInScene
                            }
                            
                            var layout = widgetInScene.sceneWidget.layout
                            guard !layout.positioningLock else { return }
                            
                            if pinchStartSize == 0 {
                                pinchStartSize = layout.size
                            }
                            
                            let newSize = (pinchStartSize * Double(scale)).clamped(to: 1...100)
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
            let widgets = model.widgetsInCurrentScene(onlyEnabled: true)

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
                        Group {
                            cornerHandle(x: rect.minX, y: rect.minY, handle: "topLeft", widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                            cornerHandle(x: rect.maxX, y: rect.minY, handle: "topRight", widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                            cornerHandle(x: rect.minX, y: rect.maxY, handle: "bottomLeft", widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                            cornerHandle(x: rect.maxX, y: rect.maxY, handle: "bottomRight", widgetInScene: widgetInScene, rect: rect, videoBounds: videoBounds)
                        }

                        hudToolbar(widgetInScene: widgetInScene, rect: rect)
                    }
                }
            }
        }
    }
}
