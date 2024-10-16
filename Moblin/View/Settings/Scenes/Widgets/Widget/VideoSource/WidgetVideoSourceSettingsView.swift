import SwiftUI

private enum AnchorPoint {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
}

private struct CropView: View {
    @EnvironmentObject var model: Model
    var widgetId: UUID
    var widget: SettingsWidgetVideoSource
    @State private var position: CGPoint = .init(x: 100, y: 100)
    @State private var positionOffset: CGSize = .init(width: 0, height: 0)
    @State private var positionAnchorPoint: AnchorPoint?

    private func calculatePositionAnchorPoint(location: CGPoint, size: CGSize) -> (AnchorPoint?, CGSize) {
        let x = location.x / size.width
        let y = location.y / size.height
        let xTopLeft = widget.cropX!
        let yTopLeft = widget.cropY!
        let xBottomRight = widget.cropX! + widget.cropWidth!
        let yBottomRight = widget.cropY! + widget.cropHeight!
        let xCenter = xTopLeft + widget.cropWidth! / 2
        let yCenter = yTopLeft + widget.cropHeight! / 2
        let xCenterTopLeft = xTopLeft + widget.cropWidth! / 4
        let yCenterTopLeft = yTopLeft + widget.cropHeight! / 4
        let xCenterBottomRight = xBottomRight - widget.cropWidth! / 4
        let yCenterBottomRight = yBottomRight - widget.cropHeight! / 4
        if x > xCenterTopLeft && x < xCenterBottomRight && y > yCenterTopLeft && y < yCenterBottomRight {
            return (.center, .init(width: CGFloat(xCenter - x), height: CGFloat(yCenter - y)))
        } else if x + 0.1 < xTopLeft || x > xBottomRight + 0.1 || y + 0.1 < yTopLeft || y > yBottomRight +
            0.1
        {
            return (.center, .init(width: CGFloat(xCenter - x), height: CGFloat(yCenter - y)))
        } else if x < xCenterTopLeft && y < yCenterTopLeft {
            return (.topLeft, .init(width: CGFloat(xTopLeft - x), height: CGFloat(yTopLeft - y)))
        } else if x > xCenterBottomRight && y < yCenterTopLeft {
            return (.topRight, .init(width: CGFloat(xBottomRight - x), height: CGFloat(yTopLeft - y)))
        } else if x < xCenterTopLeft && y > yCenterBottomRight {
            return (.bottomLeft, .init(width: CGFloat(xTopLeft - x), height: CGFloat(yBottomRight - y)))
        } else if x > xCenterBottomRight && y > yCenterBottomRight {
            return (.bottomRight, .init(width: CGFloat(xBottomRight - x), height: CGFloat(yBottomRight - y)))
        } else {
            return (nil, .zero)
        }
    }

    private func updatePositionAnchorPoint(location: CGPoint, size: CGSize) {
        if positionAnchorPoint == nil {
            (positionAnchorPoint, positionOffset) = calculatePositionAnchorPoint(
                location: location,
                size: size
            )
        }
    }

    private func createPositionPath(size: CGSize) -> Path {
        var xTopLeft = widget.cropX!
        var yTopLeft = widget.cropY!
        var xBottomRight = xTopLeft + widget.cropWidth!
        var yBottomRight = yTopLeft + widget.cropHeight!
        let positionX = ((position.x) / size.width + positionOffset.width)
            .clamped(to: 0 ... 1)
        let positionY = ((position.y) / size.height + positionOffset.height)
            .clamped(to: 0 ... 1)
        let minimumWidth = 0.05
        let minimumHeight = 0.04
        switch positionAnchorPoint {
        case .topLeft:
            if positionX + minimumWidth < xBottomRight {
                xTopLeft = positionX
            }
            if positionY + minimumHeight < yBottomRight {
                yTopLeft = positionY
            }
        case .topRight:
            if positionX > xTopLeft + minimumWidth {
                xBottomRight = positionX
            }
            if positionY + minimumHeight < yBottomRight {
                yTopLeft = positionY
            }
        case .bottomLeft:
            if positionX + minimumWidth < xBottomRight {
                xTopLeft = positionX
            }
            if positionY > yTopLeft + minimumHeight {
                yBottomRight = positionY
            }
        case .bottomRight:
            if positionX > xTopLeft + minimumWidth {
                xBottomRight = positionX
            }
            if positionY > yTopLeft + minimumHeight {
                yBottomRight = positionY
            }
        case .center:
            let halfWidth = widget.cropWidth! / 2
            let halfHeight = widget.cropHeight! / 2
            var x = widget.cropX!
            var y = widget.cropY!
            if positionX - halfWidth >= 0 && positionX + halfWidth <= 1 {
                x = positionX - halfWidth
            }
            if positionY - halfHeight >= 0 && positionY + halfHeight <= 1 {
                y = positionY - halfHeight
            }
            xTopLeft = x
            yTopLeft = y
            xBottomRight = x + widget.cropWidth!
            yBottomRight = y + widget.cropHeight!
        case nil:
            break
        }
        widget.cropX = xTopLeft
        widget.cropY = yTopLeft
        widget.cropWidth = xBottomRight - xTopLeft
        widget.cropHeight = yBottomRight - yTopLeft
        model.getVideoSourceEffect(id: widgetId)?.setSettings(settings: widget.toEffectSettings())
        let xPoints = CGFloat(widget.cropX!) * size.width
        let yPoints = CGFloat(widget.cropY!) * size.height
        let widthPoints = CGFloat(widget.cropWidth!) * size.width
        let heightPoints = CGFloat(widget.cropHeight!) * size.height
        var path = Path()
        path.move(to: .init(x: xPoints, y: yPoints))
        path.addLine(to: .init(x: xPoints + widthPoints, y: yPoints))
        path.addLine(to: .init(x: xPoints + widthPoints, y: yPoints + heightPoints))
        path.addLine(to: .init(x: xPoints, y: yPoints + heightPoints))
        path.addLine(to: .init(x: xPoints, y: yPoints))
        path.addEllipse(in: .init(x: xPoints - 5, y: yPoints - 5, width: 10, height: 10))
        path.addEllipse(in: .init(x: xPoints + widthPoints - 5, y: yPoints - 5, width: 10, height: 10))
        path.addEllipse(in: .init(
            x: xPoints + widthPoints - 5,
            y: yPoints + heightPoints - 5,
            width: 10,
            height: 10
        ))
        path.addEllipse(in: .init(x: xPoints - 5, y: yPoints + heightPoints - 5, width: 10, height: 10))
        return path
    }

    var body: some View {
        ZStack {
            Image("AlertFace")
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
    }
}

struct WidgetVideoSourceSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var cornerRadius: Float
    @State var selectedRotation: Double

    private func onCameraChange(cameraId: String) {
        widget.videoSource!
            .updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated()
    }

    private func setEffectSettings() {
        model.getVideoSourceEffect(id: widget.id)?
            .setSettings(settings: widget.videoSource!.toEffectSettings())
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: String(localized: "Video source"),
                    onChange: onCameraChange,
                    footers: [
                        String(
                            localized: "Only RTMP, SRT(LA) and screen capture video sources are currently supported."
                        ),
                    ],
                    items: model.listCameraPositions(excludeBuiltin: true).map { id, name in
                        InlinePickerItem(id: id, text: name)
                    },
                    selectedId: model.getCameraPositionId(videoSourceWidget: widget.videoSource)
                )
            } label: {
                HStack {
                    Text("Video source")
                    Spacer()
                    Text(model.getCameraPositionName(videoSourceWidget: widget.videoSource))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        Section {
            Slider(
                value: $cornerRadius,
                in: 0 ... 1,
                step: 0.01
            )
            .onChange(of: cornerRadius) { _ in
                widget.videoSource!.cornerRadius = cornerRadius
                setEffectSettings()
            }
        } header: {
            Text("Corner radius")
        }
        Section {
            Picker("Rotation", selection: $selectedRotation) {
                ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { rotation in
                    Text("\(Int(rotation))°")
                        .tag(rotation)
                }
            }
            .onChange(of: selectedRotation) { rotation in
                widget.videoSource!.rotation = rotation
                setEffectSettings()
            }
        }
        Section {
            Toggle(isOn: Binding(get: {
                widget.videoSource!.cropEnabled!
            }, set: { value in
                widget.videoSource!.cropEnabled = value
                setEffectSettings()
            })) {
                Text("Enabled")
            }
        } header: {
            Text("Crop")
        }
        Section {
            CropView(widgetId: widget.id, widget: widget.videoSource!)
        }
    }
}
