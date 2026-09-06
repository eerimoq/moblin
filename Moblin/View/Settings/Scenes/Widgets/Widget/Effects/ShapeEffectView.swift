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
    let previewImage: UIImage?
    let isPortrait: Bool
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

    private func createPositionRectangle(size: CGSize) -> CGRect {
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
        return CGRect(
            x: CGFloat(shape.cropX) * size.width,
            y: CGFloat(shape.cropY) * size.height,
            width: CGFloat(shape.cropWidth) * size.width,
            height: CGFloat(shape.cropHeight) * size.height
        )
    }

    var body: some View {
        Section {
            ZStack {
                if let previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .aspectRatio(isPortrait ? 9 / 16 : 16 / 9, contentMode: .fit)
                } else {
                    Image("GamlaLinkoping")
                        .resizable()
                        .aspectRatio(isPortrait ? 9 / 16 : 16 / 9, contentMode: .fit)
                }
                GeometryReader { reader in
                    Canvas { context, size in
                        drawPositioningRectangle(context, createPositionRectangle(size: size))
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                position = value.location
                                let size = reader.size
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
    let widget: SettingsWidget
    let effect: SettingsVideoEffect
    let shape: SettingsVideoEffectShape
    @State private var previewImage: UIImage?

    private func updateWidget() {
        model.getWidgetShapeEffect(widget, effect)?.setSettings(settings: shape.toSettings())
    }

    var body: some View {
        Group {
            CornerRadiusView(shape: shape, updateWidget: updateWidget)
            BorderView(shape: shape, updateWidget: updateWidget)
            CropView(shape: shape,
                     updateWidget: updateWidget,
                     previewImage: previewImage,
                     isPortrait: model.stream.portrait)
        }
        .onAppear {
            model.takeVideoSourcePreviewImage(widget: widget) { image in
                previewImage = image
            }
        }
    }
}
