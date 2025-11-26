import SwiftUI

private struct CornerRadiusView: View {
    @ObservedObject var shape: SettingsVideoEffectShape
    let updateWidget: () -> Void

    var body: some View {
        Section {
            HStack {
                Slider(
                    value: $shape.cornerRadius,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: shape.cornerRadius) { _ in
                    updateWidget()
                }
                Text(String(Int(shape.cornerRadius * 100)))
                    .frame(width: 35)
            }
        } header: {
            Text("Corner radius")
        }
    }
}

private struct BorderView: View {
    @ObservedObject var shape: SettingsVideoEffectShape
    let updateWidget: () -> Void

    var body: some View {
        Section {
            HStack {
                Text("Width")
                Slider(
                    value: $shape.borderWidth,
                    in: 0 ... 1.0,
                    step: 0.01
                )
                .onChange(of: shape.borderWidth) { _ in
                    updateWidget()
                }
            }
            ColorPicker("Color", selection: $shape.borderColorColor, supportsOpacity: false)
                .onChange(of: shape.borderColorColor) { _ in
                    guard let borderColor = shape.borderColorColor.toRgb() else {
                        return
                    }
                    shape.borderColor = borderColor
                    updateWidget()
                }
        } header: {
            Text("Border")
        }
    }
}

private struct CropView: View {
    @ObservedObject var shape: SettingsVideoEffectShape
    let updateWidget: () -> Void
    @State private var position: CGPoint = .init(x: 100, y: 100)
    @State private var positionOffset: CGSize = .init(width: 0, height: 0)
    @State private var positionAnchorPoint: AnchorPoint?

    private func updatePositionAnchorPoint(location: CGPoint, size: CGSize) {
        if positionAnchorPoint == nil {
            (positionAnchorPoint, positionOffset) = calculatePositioningAnchorPoint(
                location,
                size,
                shape.cropX,
                shape.cropY,
                shape.cropWidth,
                shape.cropHeight
            )
        }
    }

    private func createPositionPath(size: CGSize) -> Path {
        let (xTopLeft, yTopLeft, xBottomRight, yBottomRight) = calculatePositioningRectangle(
            positionAnchorPoint,
            shape.cropX,
            shape.cropY,
            shape.cropWidth,
            shape.cropHeight,
            position,
            size,
            positionOffset
        )
        shape.cropX = xTopLeft
        shape.cropY = yTopLeft
        shape.cropWidth = xBottomRight - xTopLeft
        shape.cropHeight = yBottomRight - yTopLeft
        updateWidget()
        let xPoints = CGFloat(shape.cropX) * size.width
        let yPoints = CGFloat(shape.cropY) * size.height
        let widthPoints = CGFloat(shape.cropWidth) * size.width
        let heightPoints = CGFloat(shape.cropHeight) * size.height
        return drawPositioningRectangle(xPoints, yPoints, widthPoints, heightPoints)
    }

    var body: some View {
        Section {
            ZStack {
                Image("GamlaLinkoping")
                    .resizable()
                    .aspectRatio(16 / 9, contentMode: .fit)
                GeometryReader { reader in
                    Canvas { context, size in
                        context.stroke(
                            createPositionPath(size: size),
                            with: .color(.black),
                            lineWidth: 1.5
                        )
                    }
                    .padding([.top, .bottom], 6)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                position = value.location
                                let size = CGSize(width: reader.size.width, height: reader.size.height - 12)
                                updatePositionAnchorPoint(location: position, size: size)
                            }
                            .onEnded { _ in
                                positionAnchorPoint = nil
                            }
                    )
                }
            }
            Toggle("Enabled", isOn: $shape.cropEnabled)
                .onChange(of: shape.cropEnabled) { _ in
                    updateWidget()
                }
        } header: {
            Text("Crop")
        }
    }
}

struct ShapeEffectView: View {
    let model: Model
    let widgetId: UUID
    let effectIndex: Int?
    let shape: SettingsVideoEffectShape

    private func updateWidget() {
        guard let effectIndex, let effect = model.getEffectWithPossibleEffects(id: widgetId) else {
            return
        }
        guard effectIndex < effect.effects.count else {
            return
        }
        guard let effect = effect.effects[effectIndex] as? ShapeEffect else {
            return
        }
        effect.setSettings(settings: shape.toSettings())
    }

    var body: some View {
        CornerRadiusView(shape: shape, updateWidget: updateWidget)
        BorderView(shape: shape, updateWidget: updateWidget)
        CropView(shape: shape, updateWidget: updateWidget)
    }
}
