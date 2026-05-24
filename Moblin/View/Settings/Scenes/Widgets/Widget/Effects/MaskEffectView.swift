import SwiftUI

private let maskPointHandleRadius: CGFloat = 12
private let maskEdgeHitWidth: CGFloat = 20
private let maskDragThreshold: CGFloat = 6
private let maskTapThreshold: CGFloat = 4
private let maskMinimumPoints = 3

private struct MaskCanvasView: View {
    @ObservedObject var mask: SettingsVideoEffectMask
    let updateWidget: () -> Void
    let previewImage: UIImage?
    let isPortrait: Bool
    @Binding var selectedPointIndex: Int?
    @Binding var selectedEdgeIndex: Int?
    @State private var dragIndex: Int?
    @State private var pendingDragIndex: Int?
    @State private var panStartPoints: [SettingsVideoEffectMaskEffectPoint]?
    @State private var panStartLocation: CGPoint?
    @State private var pinchStartPoints: [SettingsVideoEffectMaskEffectPoint]?

    private func canvasPoint(_ point: SettingsVideoEffectMaskEffectPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x / 100 * size.width, y: point.y / 100 * size.height)
    }

    private func normalizedPoint(_ location: CGPoint, _ size: CGSize) -> SettingsVideoEffectMaskEffectPoint {
        SettingsVideoEffectMaskEffectPoint(
            x: (location.x / size.width * 100).clamped(to: 0 ... 100),
            y: (location.y / size.height * 100).clamped(to: 0 ... 100)
        )
    }

    private func closestPointIndex(_ location: CGPoint, _ size: CGSize) -> Int? {
        var closest: Int?
        var closestDist = maskPointHandleRadius * 1.2
        for (index, point) in mask.points.enumerated() {
            let pt = canvasPoint(point, size)
            let dist = hypot(location.x - pt.x, location.y - pt.y)
            if dist < closestDist {
                closestDist = dist
                closest = index
            }
        }
        return closest
    }

    private func closestEdgeIndex(_ location: CGPoint, _ size: CGSize) -> Int? {
        guard mask.points.count >= 2 else {
            return nil
        }
        let pts = mask.points.map { canvasPoint($0, size) }
        var closest: Int?
        var closestDist = maskEdgeHitWidth
        for i in 0 ..< pts.count {
            let a = pts[i]
            let b = pts[(i + 1) % pts.count]
            let dist = pointToSegmentDistance(location, a, b)
            if dist < closestDist {
                closestDist = dist
                closest = i
            }
        }
        return closest
    }

    private func pointToSegmentDistance(_ p: CGPoint, _ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = b.x - a.x
        let dy = b.y - a.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else {
            return hypot(p.x - a.x, p.y - a.y)
        }
        let t = max(0, min(1, ((p.x - a.x) * dx + (p.y - a.y) * dy) / lengthSq))
        let projX = a.x + t * dx
        let projY = a.y + t * dy
        return hypot(p.x - projX, p.y - projY)
    }

    private func drawPolygon(_ context: GraphicsContext, _ size: CGSize) {
        guard mask.points.count >= 3 else {
            return
        }
        let pts = mask.points.map { canvasPoint($0, size) }
        let path = Path(makeCatmullRomPath(pts, tension: mask.tension))
        context.fill(path, with: .color(.white.opacity(0.25)))
        context.stroke(path, with: .color(.white), lineWidth: 1.5)
    }

    private func drawHighlightedEdge(_ context: GraphicsContext, _ size: CGSize) {
        guard let edgeIdx = selectedEdgeIndex, mask.points.count >= 2 else {
            return
        }
        let pts = mask.points.map { canvasPoint($0, size) }
        let n = pts.count
        let path: Path
        let point0 = pts[(edgeIdx - 1 + n) % n]
        let point1 = pts[edgeIdx]
        let point2 = pts[(edgeIdx + 1) % n]
        let point3 = pts[(edgeIdx + 2) % n]
        let tension = CGFloat(mask.tension)
        let cp1 = CGPoint(
            x: point1.x + (point2.x - point0.x) * tension,
            y: point1.y + (point2.y - point0.y) * tension
        )
        let cp2 = CGPoint(
            x: point2.x - (point3.x - point1.x) * tension,
            y: point2.y - (point3.y - point1.y) * tension
        )
        var p = Path()
        p.move(to: point1)
        p.addCurve(to: point2, control1: cp1, control2: cp2)
        path = p
        context.stroke(path, with: .color(.yellow), lineWidth: 3)
    }

    private func drawHandles(_ context: GraphicsContext, _ size: CGSize) {
        for (index, point) in mask.points.enumerated() {
            let pt = canvasPoint(point, size)
            let isSelected = index == selectedPointIndex
            let radius = isSelected ? maskPointHandleRadius * 1.4 : maskPointHandleRadius
            let rect = CGRect(
                x: pt.x - radius / 2,
                y: pt.y - radius / 2,
                width: radius,
                height: radius
            )
            context.fill(Path(ellipseIn: rect), with: .color(isSelected ? .yellow : .white))
            context.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: 1)
        }
    }

    private func gestureChanged(value: DragGesture.Value, size: CGSize) {
        if dragIndex == nil, pendingDragIndex == nil, panStartPoints == nil {
            if let index = closestPointIndex(value.startLocation, size) {
                pendingDragIndex = index
                selectedPointIndex = index
                selectedEdgeIndex = nil
            } else {
                panStartPoints = mask.points
                panStartLocation = value.startLocation
            }
        }
        if let pending = pendingDragIndex, dragIndex == nil {
            let dist = hypot(
                value.location.x - value.startLocation.x,
                value.location.y - value.startLocation.y
            )
            if dist >= maskDragThreshold {
                dragIndex = pending
                pendingDragIndex = nil
            }
        }
        if let index = dragIndex {
            mask.points[index] = normalizedPoint(value.location, size)
            updateWidget()
        } else if let startPoints = panStartPoints, let startLocation = panStartLocation {
            let dx = (value.location.x - startLocation.x) / size.width * 100
            let dy = (value.location.y - startLocation.y) / size.height * 100
            mask.points = startPoints.map { point in
                SettingsVideoEffectMaskEffectPoint(
                    x: (point.x + dx).clamped(to: 0 ... 100),
                    y: (point.y + dy).clamped(to: 0 ... 100)
                )
            }
            updateWidget()
        }
    }

    private func gestureEnded(value: DragGesture.Value, size: CGSize) {
        let wasDragging = dragIndex != nil
        let wasPanning = panStartPoints != nil
        dragIndex = nil
        pendingDragIndex = nil
        panStartPoints = nil
        panStartLocation = nil
        let dragDistance = hypot(
            value.location.x - value.startLocation.x,
            value.location.y - value.startLocation.y
        )
        if !wasDragging, !wasPanning || dragDistance < maskTapThreshold {
            if let index = closestPointIndex(value.startLocation, size) {
                selectedPointIndex = index
                selectedEdgeIndex = nil
            } else if let edgeIdx = closestEdgeIndex(value.startLocation, size) {
                selectedEdgeIndex = edgeIdx
                selectedPointIndex = nil
            } else {
                selectedPointIndex = nil
                selectedEdgeIndex = nil
            }
        }
    }

    private func pinchChanged(value: CGFloat) {
        if pinchStartPoints == nil {
            pinchStartPoints = mask.points
        }
        guard let startPoints = pinchStartPoints else {
            return
        }
        let cx = startPoints.map { $0.x }.reduce(0, +) / Double(startPoints.count)
        let cy = startPoints.map { $0.y }.reduce(0, +) / Double(startPoints.count)
        let scale = Double(value)
        mask.points = startPoints.map { point in
            SettingsVideoEffectMaskEffectPoint(
                x: (cx + (point.x - cx) * scale).clamped(to: 0 ... 100),
                y: (cy + (point.y - cy) * scale).clamped(to: 0 ... 100)
            )
        }
        updateWidget()
    }

    private func pinchEnded() {
        pinchStartPoints = nil
    }

    var body: some View {
        GeometryReader { reader in
            let size = reader.size
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                } else {
                    Image("GamlaLinkoping")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size.width, height: size.height)
                        .clipped()
                }
                Canvas { context, canvasSize in
                    drawPolygon(context, canvasSize)
                    drawHighlightedEdge(context, canvasSize)
                    drawHandles(context, canvasSize)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged {
                            gestureChanged(value: $0, size: size)
                        }
                        .onEnded {
                            gestureEnded(value: $0, size: size)
                        }
                )
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { value in
                            pinchChanged(value: value)
                        }
                        .onEnded { _ in
                            pinchEnded()
                        }
                )
            }
        }
        .aspectRatio(isPortrait ? 9 / 16 : 16 / 9, contentMode: .fit)
    }
}

private struct MaskEditorView: View {
    @ObservedObject var mask: SettingsVideoEffectMask
    let updateWidget: () -> Void
    @Binding var selectedPointIndex: Int?
    @Binding var selectedEdgeIndex: Int?
    @State private var xText: String = ""
    @State private var yText: String = ""

    private func updateXY() {
        guard let index = selectedPointIndex, index < mask.points.count else {
            return
        }
        let point = mask.points[index]
        xText = formatOneDecimal(point.x)
        yText = formatOneDecimal(point.y)
    }

    private func commitX() {
        guard let index = getSelectedPointIndex(),
              let x = parseNumber(text: xText),
              x != mask.points[index].x
        else {
            return
        }
        mask.points[index].x = x
        updateWidget()
    }

    private func commitY() {
        guard let index = getSelectedPointIndex(),
              let y = parseNumber(text: yText),
              y != mask.points[index].y
        else {
            return
        }
        mask.points[index].y = y
        updateWidget()
    }

    private func getSelectedPointIndex() -> Int? {
        guard let index = selectedPointIndex, index < mask.points.count else {
            return nil
        }
        return index
    }

    private func parseNumber(text: String) -> Double? {
        guard let value = Double(text) else {
            return nil
        }
        return value.clamped(to: 0 ... 100)
    }

    var body: some View {
        if let pointIndex = selectedPointIndex {
            Group {
                HStack {
                    Text("X")
                    TextField("", text: $xText)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitX() }
                }
                HStack {
                    Text("Y")
                    TextField("", text: $yText)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { commitY() }
                }
                Button(role: .destructive) {
                    mask.points.remove(at: pointIndex)
                    selectedPointIndex = nil
                    updateWidget()
                } label: {
                    HCenter {
                        Text("Delete point")
                    }
                }
                .disabled(mask.points.count <= maskMinimumPoints)
            }
            .onChange(of: selectedPointIndex) { _ in
                updateXY()
            }
            .onChange(of: mask.points) { _ in
                updateXY()
            }
            .onAppear {
                updateXY()
            }
        } else if let edgeIndex = selectedEdgeIndex {
            Button {
                let count = mask.points.count
                let point1 = mask.points[edgeIndex]
                let point2 = mask.points[(edgeIndex + 1) % count]
                let newPoint = SettingsVideoEffectMaskEffectPoint(
                    x: (point1.x + point2.x) / 2,
                    y: (point1.y + point2.y) / 2
                )
                mask.points.insert(newPoint, at: edgeIndex + 1)
                selectedEdgeIndex = nil
                selectedPointIndex = edgeIndex + 1
                updateWidget()
            } label: {
                HCenter {
                    Text("Create point")
                }
            }
        }
    }
}

struct MaskEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var mask: SettingsVideoEffectMask
    @State private var previewImage: UIImage?
    @State private var selectedPointIndex: Int?
    @State private var selectedEdgeIndex: Int?

    private func updateWidget() {
        model.getWidgetMaskEffect(widget, effect)?.setSettings(settings: mask.toSettings())
    }

    var body: some View {
        Section {
            MaskCanvasView(
                mask: mask,
                updateWidget: updateWidget,
                previewImage: previewImage,
                isPortrait: model.stream.portrait,
                selectedPointIndex: $selectedPointIndex,
                selectedEdgeIndex: $selectedEdgeIndex
            )
            MaskEditorView(
                mask: mask,
                updateWidget: updateWidget,
                selectedPointIndex: $selectedPointIndex,
                selectedEdgeIndex: $selectedEdgeIndex
            )
        } header: {
            Text("Shape")
        }
        .onAppear {
            model.takeVideoSourcePreviewImage(widget: widget) { image in
                previewImage = image
            }
        }
        Section {
            Toggle("Inverted", isOn: $mask.inverted)
                .onChange(of: mask.inverted) { _ in
                    updateWidget()
                }
            HStack {
                Text("Smoothness")
                Slider(value: $mask.tension, in: 0 ... 0.5)
                    .onChange(of: mask.tension) { _ in
                        updateWidget()
                    }
            }
        }
        Section {
            Picker("Type", selection: $mask.backgroundType) {
                ForEach(SettingsMaskBackgroundType.allCases, id: \.self) { type in
                    Text(type.toString())
                        .tag(type)
                }
            }
            .onChange(of: mask.backgroundType) { _ in
                updateWidget()
            }
            if mask.backgroundType != .transparent {
                ColorPicker("Color", selection: $mask.backgroundColorColor, supportsOpacity: false)
                    .onChange(of: mask.backgroundColorColor) { _ in
                        guard let color = mask.backgroundColorColor.toRgb() else {
                            return
                        }
                        mask.backgroundColor = color
                        updateWidget()
                    }
            }
            if mask.backgroundType == .checkerboard {
                ColorPicker("Color 2", selection: $mask.backgroundColorColor2, supportsOpacity: false)
                    .onChange(of: mask.backgroundColorColor2) { _ in
                        guard let color = mask.backgroundColorColor2.toRgb() else {
                            return
                        }
                        mask.backgroundColor2 = color
                        updateWidget()
                    }
            }
        } header: {
            Text("Background")
        }
    }
}
