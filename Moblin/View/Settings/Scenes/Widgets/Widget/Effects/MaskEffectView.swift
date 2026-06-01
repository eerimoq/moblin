import SwiftUI

private let maskPointHandleRadius: CGFloat = 12
private let maskEdgeHitWidth: CGFloat = 20
private let maskDragThreshold: CGFloat = 6
private let maskTapThreshold: CGFloat = 4
private let maskMinimumPoints = 3

private struct MaskCanvasView: View {
    @ObservedObject var mask: SettingsVideoEffectMask
    let updateWidget: () -> Void
    let refreshPreviewImage: () -> Void
    let previewImage: UIImage?
    let isPortrait: Bool
    @Binding var selectedPointIndex: Int?
    @Binding var selectedEdgeIndex: Int?
    @State private var dragIndex: Int?
    @State private var pendingDragIndex: Int?
    @State private var panStartPoints: [SettingsVideoEffectMaskEffectPoint]?
    @State private var panStartLocation: CGPoint?

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
        let pts = mask.points.map { canvasPoint($0, size) }
        let path = Path(makeCatmullRomPath(pts, tension: mask.tension))
        context.fill(path, with: .color(.white.opacity(0.25)))
        context.stroke(path, with: .color(.white), lineWidth: 1.5)
    }

    private func drawHighlightedEdge(_ context: GraphicsContext, _ size: CGSize) {
        guard let selectedEdgeIndex else {
            return
        }
        let points = mask.points.map { canvasPoint($0, size) }
        let numberOfPoints = points.count
        let point0 = points[(selectedEdgeIndex - 1 + numberOfPoints) % numberOfPoints]
        let point1 = points[selectedEdgeIndex]
        let point2 = points[(selectedEdgeIndex + 1) % numberOfPoints]
        let point3 = points[(selectedEdgeIndex + 2) % numberOfPoints]
        let tension = CGFloat(mask.tension)
        let control1 = CGPoint(
            x: point1.x + (point2.x - point0.x) * tension,
            y: point1.y + (point2.y - point0.y) * tension
        )
        let control2 = CGPoint(
            x: point2.x - (point3.x - point1.x) * tension,
            y: point2.y - (point3.y - point1.y) * tension
        )
        var path = Path()
        path.move(to: point1)
        path.addCurve(to: point2, control1: control1, control2: control2)
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
        if let pendingDragIndex, dragIndex == nil {
            let dist = hypot(
                value.location.x - value.startLocation.x,
                value.location.y - value.startLocation.y
            )
            if dist >= maskDragThreshold {
                dragIndex = pendingDragIndex
                self.pendingDragIndex = nil
            }
        }
        if let dragIndex {
            mask.points[dragIndex] = normalizedPoint(value.location, size)
            updateWidget()
        } else if let panStartPoints, let panStartLocation {
            let dx = (value.location.x - panStartLocation.x) / size.width * 100
            let dy = (value.location.y - panStartLocation.y) / size.height * 100
            mask.points = panStartPoints.map { point in
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

    private func resizeShape(scale: Double) {
        let centerX = mask.points.map(\.x).reduce(0, +) / Double(mask.points.count)
        let centerY = mask.points.map(\.y).reduce(0, +) / Double(mask.points.count)
        mask.points = mask.points.map {
            SettingsVideoEffectMaskEffectPoint(
                x: (centerX + ($0.x - centerX) * scale).clamped(to: 0 ... 100),
                y: (centerY + ($0.y - centerY) * scale).clamped(to: 0 ... 100)
            )
        }
        updateWidget()
    }

    var body: some View {
        VStack(spacing: 10) {
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
                }
            }
            .aspectRatio(isPortrait ? 9 / 16 : 16 / 9, contentMode: .fit)
            HStack(spacing: 12) {
                Button {
                    resizeShape(scale: 1 / 1.1)
                } label: {
                    Image(systemName: "square.resize.down")
                }
                .buttonStyle(.borderless)
                Button {
                    resizeShape(scale: 1.1)
                } label: {
                    Image(systemName: "square.resize.up")
                }
                .buttonStyle(.borderless)
                Spacer()
                Button {
                    refreshPreviewImage()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
            }
            .font(.title)
        }
    }
}

private struct MaskEditorView: View {
    @ObservedObject var mask: SettingsVideoEffectMask
    let updateWidget: () -> Void
    @Binding var selectedPointIndex: Int?
    @Binding var selectedEdgeIndex: Int?
    @State private var xText: String = ""
    @State private var yText: String = ""

    private func updateXYText() {
        guard let selectedPointIndex else {
            return
        }
        let point = mask.points[selectedPointIndex]
        xText = formatOneDecimal(point.x)
        yText = formatOneDecimal(point.y)
    }

    private func commitX() {
        guard let x = Double(xText) else {
            return
        }
        setX(x)
    }

    private func commitY() {
        guard let y = Double(yText) else {
            return
        }
        setY(value: y)
    }

    private func adjustX(delta: Double) {
        guard let selectedPointIndex else {
            return
        }
        setX(mask.points[selectedPointIndex].x + delta)
    }

    private func adjustY(delta: Double) {
        guard let selectedPointIndex else {
            return
        }
        setY(value: mask.points[selectedPointIndex].y + delta)
    }

    private func setX(_ value: Double) {
        guard let selectedPointIndex else {
            return
        }
        let x = value.clamped(to: 0 ... 100)
        guard x != mask.points[selectedPointIndex].x else {
            return
        }
        mask.points[selectedPointIndex].x = x
        updateWidget()
    }

    private func setY(value: Double) {
        guard let selectedPointIndex else {
            return
        }
        let y = value.clamped(to: 0 ... 100)
        guard y != mask.points[selectedPointIndex].y else {
            return
        }
        mask.points[selectedPointIndex].y = y
        updateWidget()
    }

    private func pointSettings(_ selectedPointIndex: Int) -> some View {
        Group {
            HStack {
                Text("X")
                TextField("", text: $xText)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commitX() }
                Button {
                    adjustX(delta: -0.1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .font(.title)
                Button {
                    adjustX(delta: 0.1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .font(.title)
            }
            HStack {
                Text("Y")
                TextField("", text: $yText)
                    .multilineTextAlignment(.trailing)
                    .onSubmit { commitY() }
                Button {
                    adjustY(delta: -0.1)
                } label: {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .font(.title)
                Button {
                    adjustY(delta: 0.1)
                } label: {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .font(.title)
            }
            Button(role: .destructive) {
                mask.points.remove(at: selectedPointIndex)
                self.selectedPointIndex = nil
                updateWidget()
            } label: {
                HCenter {
                    Text("Delete point")
                }
            }
            .disabled(mask.points.count <= maskMinimumPoints)
        }
        .onChange(of: self.selectedPointIndex) { _ in
            updateXYText()
        }
        .onChange(of: mask.points) { _ in
            updateXYText()
        }
        .onAppear {
            updateXYText()
        }
    }

    private func edgeSettings(_ selectedEdgeIndex: Int) -> some View {
        Button {
            let point1 = mask.points[selectedEdgeIndex]
            let point2 = mask.points[(selectedEdgeIndex + 1) % mask.points.count]
            let newPoint = SettingsVideoEffectMaskEffectPoint(
                x: (point1.x + point2.x) / 2,
                y: (point1.y + point2.y) / 2
            )
            mask.points.insert(newPoint, at: selectedEdgeIndex + 1)
            self.selectedEdgeIndex = nil
            selectedPointIndex = selectedEdgeIndex + 1
            updateWidget()
        } label: {
            HCenter {
                Text("Create point")
            }
        }
    }

    var body: some View {
        if let selectedPointIndex {
            pointSettings(selectedPointIndex)
        } else if let selectedEdgeIndex {
            edgeSettings(selectedEdgeIndex)
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
        model.getWidgetMaskEffect(widget, effect)?.setSettings(settings: mask.toEffectSettings())
    }

    private func refreshPreviewImage() {
        model.takeVideoSourcePreviewImage(widget: widget) { image in
            previewImage = image
        }
    }

    var body: some View {
        Section {
            MaskCanvasView(
                mask: mask,
                updateWidget: updateWidget,
                refreshPreviewImage: refreshPreviewImage,
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
