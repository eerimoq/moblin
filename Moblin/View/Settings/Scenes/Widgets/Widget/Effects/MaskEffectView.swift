import SwiftUI

private let maskPointHandleRadius: CGFloat = 12
private let maskMaxPoints = 20

private struct MaskCanvasView: View {
    @ObservedObject var mask: SettingsVideoEffectMask
    let updateWidget: () -> Void
    @State private var dragIndex: Int?
    @State private var panStartPoints: [MaskEffectPoint]?
    @State private var panStartLocation: CGPoint?

    private func canvasPoint(_ point: MaskEffectPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func normalizedPoint(_ location: CGPoint, _ size: CGSize) -> MaskEffectPoint {
        MaskEffectPoint(
            x: (location.x / size.width).clamped(to: 0 ... 1),
            y: (location.y / size.height).clamped(to: 0 ... 1)
        )
    }

    private func closestPointIndex(_ location: CGPoint, _ size: CGSize) -> Int? {
        var closest: Int?
        var closestDist = maskPointHandleRadius * 2
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

    private func drawPolygon(_ context: GraphicsContext, _ size: CGSize) {
        guard mask.points.count >= 2 else {
            return
        }
        var path = Path()
        let first = canvasPoint(mask.points[0], size)
        path.move(to: first)
        for point in mask.points.dropFirst() {
            path.addLine(to: canvasPoint(point, size))
        }
        path.closeSubpath()
        context.fill(path, with: .color(.white.opacity(0.25)))
        context.stroke(path, with: .color(.white), lineWidth: 1.5)
    }

    private func drawHandles(_ context: GraphicsContext, _ size: CGSize) {
        for point in mask.points {
            let pt = canvasPoint(point, size)
            let rect = CGRect(
                x: pt.x - maskPointHandleRadius / 2,
                y: pt.y - maskPointHandleRadius / 2,
                width: maskPointHandleRadius,
                height: maskPointHandleRadius
            )
            context.fill(Path(ellipseIn: rect), with: .color(.white))
            context.stroke(Path(ellipseIn: rect), with: .color(.black), lineWidth: 1)
        }
    }

    var body: some View {
        GeometryReader { reader in
            let size = reader.size
            ZStack {
                Image("GamlaLinkoping")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size.width, height: size.height)
                    .clipped()
                Canvas { context, canvasSize in
                    drawPolygon(context, canvasSize)
                    drawHandles(context, canvasSize)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if dragIndex == nil, panStartPoints == nil {
                                if let index = closestPointIndex(value.startLocation, size) {
                                    dragIndex = index
                                } else {
                                    panStartPoints = mask.points
                                    panStartLocation = value.startLocation
                                }
                            }
                            if let index = dragIndex {
                                mask.points[index] = normalizedPoint(value.location, size)
                                updateWidget()
                            } else if let startPoints = panStartPoints, let startLocation = panStartLocation {
                                let dx = (value.location.x - startLocation.x) / size.width
                                let dy = (value.location.y - startLocation.y) / size.height
                                mask.points = startPoints.map { point in
                                    MaskEffectPoint(
                                        x: (point.x + dx).clamped(to: 0 ... 1),
                                        y: (point.y + dy).clamped(to: 0 ... 1)
                                    )
                                }
                                updateWidget()
                            }
                        }
                        .onEnded { _ in
                            dragIndex = nil
                            panStartPoints = nil
                            panStartLocation = nil
                        }
                )
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }
}

struct MaskEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var mask: SettingsVideoEffectMask

    private func updateWidget() {
        model.getWidgetMaskEffect(widget, effect)?.setSettings(settings: mask.toSettings())
    }

    private func addPoint() {
        mask.points.append(.init(x: 0.5, y: 0.5))
        updateWidget()
    }

    private func removePoint(at offsets: IndexSet) {
        mask.points.remove(atOffsets: offsets)
        updateWidget()
    }

    private func resetPoints() {
        mask.points = MaskEffect.defaultPoints
        updateWidget()
    }

    var body: some View {
        Section {
            MaskCanvasView(mask: mask, updateWidget: updateWidget)
        } header: {
            Text("Polygon")
        } footer: {
            Text(
                "Drag handles to adjust polygon vertices. Drag anywhere else to move the polygon. The visible area is inside the polygon, or outside when inverted."
            )
        }
        Section {
            ForEach(Array(mask.points.enumerated()), id: \.offset) { index, point in
                HStack {
                    Text("Point \(index + 1)")
                    Spacer()
                    Text(String(format: "%.2f, %.2f", point.x, point.y))
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete(perform: removePoint)
            Button(action: addPoint) {
                HStack {
                    Image(systemName: "plus")
                    Text("Add point")
                }
            }
            .disabled(mask.points.count >= maskMaxPoints)
        } header: {
            Text("Points")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a point"))
        }
        Section {
            Toggle("Inverted", isOn: $mask.inverted)
                .onChange(of: mask.inverted) { _ in
                    updateWidget()
                }
            Button(action: resetPoints) {
                Text("Reset to default")
            }
        }
    }
}
