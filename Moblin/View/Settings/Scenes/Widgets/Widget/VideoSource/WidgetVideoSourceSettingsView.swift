import SwiftUI

enum AnchorPoint {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case center
}

func calculatePositioningRectangle(_ positionAnchorPoint: AnchorPoint?,
                                   _ cropX: Double,
                                   _ cropY: Double,
                                   _ cropWidth: Double,
                                   _ cropHeight: Double,
                                   _ position: CGPoint,
                                   _ size: CGSize,
                                   _ positionOffset: CGSize) -> (Double, Double, Double, Double)
{
    var xTopLeft = cropX
    var yTopLeft = cropY
    var xBottomRight = xTopLeft + cropWidth
    var yBottomRight = yTopLeft + cropHeight
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
        let halfWidth = cropWidth / 2
        let halfHeight = cropHeight / 2
        var x = cropX
        var y = cropY
        if positionX - halfWidth >= 0, positionX + halfWidth <= 1 {
            x = positionX - halfWidth
        }
        if positionY - halfHeight >= 0, positionY + halfHeight <= 1 {
            y = positionY - halfHeight
        }
        xTopLeft = x
        yTopLeft = y
        xBottomRight = x + cropWidth
        yBottomRight = y + cropHeight
    case nil:
        break
    }
    return (xTopLeft, yTopLeft, xBottomRight, yBottomRight)
}

func drawPositioningRectangle(
    _ xPoints: CGFloat,
    _ yPoints: CGFloat,
    _ widthPoints: CGFloat,
    _ heightPoints: CGFloat
) -> Path {
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

func calculatePositioningAnchorPoint(_ location: CGPoint,
                                     _ size: CGSize,
                                     _ cropX: Double,
                                     _ cropY: Double,
                                     _ cropWidth: Double,
                                     _ cropHeight: Double) -> (AnchorPoint?, CGSize)
{
    let x = location.x / size.width
    let y = location.y / size.height
    let xTopLeft = cropX
    let yTopLeft = cropY
    let xBottomRight = cropX + cropWidth
    let yBottomRight = cropY + cropHeight
    let xCenter = xTopLeft + cropWidth / 2
    let yCenter = yTopLeft + cropHeight / 2
    let xCenterTopLeft = xTopLeft + cropWidth / 4
    let yCenterTopLeft = yTopLeft + cropHeight / 4
    let xCenterBottomRight = xBottomRight - cropWidth / 4
    let yCenterBottomRight = yBottomRight - cropHeight / 4
    if x > xCenterTopLeft && x < xCenterBottomRight && y > yCenterTopLeft && y < yCenterBottomRight {
        return (.center, .init(width: CGFloat(xCenter - x), height: CGFloat(yCenter - y)))
    } else if x + 0.1 < xTopLeft || x > xBottomRight + 0.1 || y + 0.1 < yTopLeft || y > yBottomRight +
        0.1
    {
        return (.center, .init(width: CGFloat(xCenter - x), height: CGFloat(yCenter - y)))
    } else if x < xCenterTopLeft, y < yCenterTopLeft {
        return (.topLeft, .init(width: CGFloat(xTopLeft - x), height: CGFloat(yTopLeft - y)))
    } else if x > xCenterBottomRight, y < yCenterTopLeft {
        return (.topRight, .init(width: CGFloat(xBottomRight - x), height: CGFloat(yTopLeft - y)))
    } else if x < xCenterTopLeft, y > yCenterBottomRight {
        return (.bottomLeft, .init(width: CGFloat(xTopLeft - x), height: CGFloat(yBottomRight - y)))
    } else if x > xCenterBottomRight, y > yCenterBottomRight {
        return (.bottomRight, .init(width: CGFloat(xBottomRight - x), height: CGFloat(yBottomRight - y)))
    } else {
        return (nil, .zero)
    }
}

private struct CropView: View {
    @EnvironmentObject var model: Model
    var widgetId: UUID
    var widget: SettingsWidgetVideoSource
    @State private var position: CGPoint = .init(x: 100, y: 100)
    @State private var positionOffset: CGSize = .init(width: 0, height: 0)
    @State private var positionAnchorPoint: AnchorPoint?

    private func updatePositionAnchorPoint(location: CGPoint, size: CGSize) {
        if positionAnchorPoint == nil {
            (positionAnchorPoint, positionOffset) = calculatePositioningAnchorPoint(
                location,
                size,
                widget.cropX,
                widget.cropY,
                widget.cropWidth,
                widget.cropHeight
            )
        }
    }

    private func createPositionPath(size: CGSize) -> Path {
        let (xTopLeft, yTopLeft, xBottomRight, yBottomRight) = calculatePositioningRectangle(
            positionAnchorPoint,
            widget.cropX,
            widget.cropY,
            widget.cropWidth,
            widget.cropHeight,
            position,
            size,
            positionOffset
        )
        widget.cropX = xTopLeft
        widget.cropY = yTopLeft
        widget.cropWidth = xBottomRight - xTopLeft
        widget.cropHeight = yBottomRight - yTopLeft
        model.getVideoSourceEffect(id: widgetId)?.setSettings(settings: widget.toEffectSettings())
        let xPoints = CGFloat(widget.cropX) * size.width
        let yPoints = CGFloat(widget.cropY) * size.height
        let widthPoints = CGFloat(widget.cropWidth) * size.width
        let heightPoints = CGFloat(widget.cropHeight) * size.height
        return drawPositioningRectangle(xPoints, yPoints, widthPoints, heightPoints)
    }

    var body: some View {
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
    }
}

struct WidgetVideoSourceSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var widget: SettingsWidget
    @ObservedObject var videoSource: SettingsWidgetVideoSource

    private func onCameraChange(cameraId: String) {
        videoSource.updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated(attachCamera: true, updateRemoteScene: false)
    }

    private func setEffectSettings() {
        model.getVideoSourceEffect(id: widget.id)?
            .setSettings(settings: videoSource.toEffectSettings())
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: String(localized: "Video source"),
                    onChange: onCameraChange,
                    footers: [
                        String(localized: """
                        Limitation: At most one built-in or USB camera is \
                        supported at a time in a scene.
                        """),
                    ],
                    items: model.listCameraPositions(excludeBuiltin: false).map { id, name in
                        InlinePickerItem(id: id, text: name)
                    },
                    selectedId: model.getCameraPositionId(videoSourceWidget: videoSource)
                )
            } label: {
                HStack {
                    Text("Video source")
                    Spacer()
                    Text(model.getCameraPositionName(videoSourceWidget: videoSource))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        Section {
            HStack {
                Slider(
                    value: $videoSource.cornerRadius,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: videoSource.cornerRadius) { _ in
                    setEffectSettings()
                }
                Text(String(Int(videoSource.cornerRadius * 100)))
                    .frame(width: 35)
            }
        } header: {
            Text("Corner radius")
        }
        Section {
            VideoSourceRotationView(selectedRotation: $videoSource.rotation)
                .onChange(of: videoSource.rotation) { _ in
                    setEffectSettings()
                }
            Toggle(isOn: Binding(get: {
                videoSource.mirror
            }, set: { value in
                videoSource.mirror = value
                setEffectSettings()
            })) {
                Text("Mirror")
            }
        }
        Section {
            HStack {
                Text("Width")
                Slider(
                    value: $videoSource.borderWidth,
                    in: 0 ... 1.0,
                    step: 0.01
                )
                .onChange(of: videoSource.borderWidth) { _ in
                    setEffectSettings()
                }
            }
            ColorPicker("Color", selection: $videoSource.borderColorColor, supportsOpacity: false)
                .onChange(of: videoSource.borderColorColor) { _ in
                    guard let borderColor = videoSource.borderColorColor.toRgb() else {
                        return
                    }
                    videoSource.borderColor = borderColor
                    setEffectSettings()
                }
        } header: {
            Text("Border")
        }
        Section {
            Toggle(isOn: Binding(get: {
                videoSource.trackFaceEnabled
            }, set: { value in
                videoSource.trackFaceEnabled = value
                setEffectSettings()
                model.objectWillChange.send()
            })) {
                Text("Enabled")
            }
            HStack {
                Text("Zoom")
                Slider(
                    value: $videoSource.trackFaceZoom,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: videoSource.trackFaceZoom) { _ in
                    setEffectSettings()
                }
            }
        } header: {
            Text("Face tracking")
        }
        if !videoSource.trackFaceEnabled {
            Section {
                Toggle(isOn: Binding(get: {
                    videoSource.cropEnabled
                }, set: { value in
                    videoSource.cropEnabled = value
                    setEffectSettings()
                })) {
                    Text("Enabled")
                }
            } header: {
                Text("Crop")
            }
            Section {
                CropView(widgetId: widget.id, widget: videoSource)
            }
        }
        WidgetEffectsView(widget: widget)
    }
}
