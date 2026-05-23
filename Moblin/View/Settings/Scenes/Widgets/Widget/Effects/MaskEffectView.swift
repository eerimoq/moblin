import SwiftUI

private let maskPointHandleRadius: CGFloat = 12
private let maskMaxPoints = 20

private struct MaskCanvasView: View {
    @ObservedObject var mask: SettingsVideoEffectMask
    let updateWidget: () -> Void
    let previewImage: UIImage?
    let isPortrait: Bool
    @State private var dragIndex: Int?
    @State private var panStartPoints: [SettingsVideoEffectMaskEffectPoint]?
    @State private var panStartLocation: CGPoint?

    private func canvasPoint(_ point: SettingsVideoEffectMaskEffectPoint, _ size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }

    private func normalizedPoint(_ location: CGPoint, _ size: CGSize) -> SettingsVideoEffectMaskEffectPoint {
        SettingsVideoEffectMaskEffectPoint(
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
        let pts = mask.points.map { canvasPoint($0, size) }
        let path: Path
        if mask.smooth, pts.count >= 3 {
            path = Path(makeCatmullRomPath(pts))
        } else {
            var p = Path()
            p.move(to: pts[0])
            for pt in pts.dropFirst() {
                p.addLine(to: pt)
            }
            p.closeSubpath()
            path = p
        }
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
                                    SettingsVideoEffectMaskEffectPoint(
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
        .aspectRatio(isPortrait ? 9 / 16 : 16 / 9, contentMode: .fit)
    }
}

struct MaskEffectView: View {
    let model: Model
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    @ObservedObject var mask: SettingsVideoEffectMask
    @State private var previewImage: UIImage?

    private func updateWidget() {
        model.getWidgetMaskEffect(widget, effect)?.setSettings(settings: mask.toSettings())
    }

    private func deletePoint(at offsets: IndexSet) {
        mask.points.remove(atOffsets: offsets)
        updateWidget()
    }

    var body: some View {
        Section {
            MaskCanvasView(mask: mask,
                           updateWidget: updateWidget,
                           previewImage: previewImage,
                           isPortrait: model.stream.portrait)
        } header: {
            Text("Shape")
        } footer: {
            Text("""
            Drag handles to adjust polygon vertices. Drag anywhere else to move the polygon. \
            The visible area is inside the polygon, or outside when inverted.
            """)
        }
        .onAppear {
            model.takeVideoSourcePreviewImage(widget: widget) { image in
                previewImage = image
            }
        }
        Section {
            ForEach(mask.points) { point in
                HStack {
                    DraggableItemPrefixView()
                    Text("")
                    Spacer()
                    Text(String(format: "X: %.02f", point.x))
                    Spacer()
                    Text(String(format: "Y: %.02f", point.y))
                    Spacer()
                }
                .contextMenuDeleteButton {
                    if let offsets = makeOffsets(mask.points, point.id) {
                        deletePoint(at: offsets)
                    }
                }
            }
            .onMove { froms, to in
                mask.points.move(fromOffsets: froms, toOffset: to)
                updateWidget()
            }
            .onDelete(perform: deletePoint)
            AddButtonView {
                mask.points.append(.init(x: 0.5, y: 0.5))
                updateWidget()
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
            Toggle("Smooth", isOn: $mask.smooth)
                .onChange(of: mask.smooth) { _ in
                    updateWidget()
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
