import AVFoundation
import SwiftUI

class SharedUiViewContainerView: UIView {
    private let sharedView: UIView

    init(sharedView: UIView) {
        self.sharedView = sharedView
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func attachSharedView() {
        guard window != nil, sharedView.superview !== self else {
            return
        }
        sharedView.frame = bounds
        addSubview(sharedView)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        attachSharedView()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        attachSharedView()
        sharedView.frame = bounds
    }
}

struct StreamPreviewView: UIViewRepresentable {
    let model: Model

    func makeUIView(context _: Context) -> SharedUiViewContainerView {
        SharedUiViewContainerView(sharedView: model.streamPreviewView)
    }

    func updateUIView(_ uiView: SharedUiViewContainerView, context _: Context) {
        uiView.attachSharedView()
    }
}

struct CameraPreviewWidget {
    let id: UUID
    let deviceId: UUID
    let layout: SettingsWidgetLayout
    let mirror: Bool
    var shape: WidgetShape
}

private class CameraPreviewWidgetLayer {
    let deviceId: UUID
    let borderLayer = CALayer()
    let previewLayer = AVCaptureVideoPreviewLayer()
    private let contentLayer = CALayer()

    init(deviceId: UUID) {
        self.deviceId = deviceId
        borderLayer.isHidden = true
        contentLayer.masksToBounds = true
        previewLayer.videoGravity = .resizeAspectFill
        contentLayer.addSublayer(previewLayer)
        borderLayer.addSublayer(contentLayer)
    }

    func layout(widget: CameraPreviewWidget, index: Int, canvasSize: CGSize, streamSize: CGSize) {
        let shape = widget.shape
        let contentRegion = shape.contentRegion
        guard !contentRegion.isEmpty else {
            return
        }
        let placement = shape.placement(widget.layout, streamSize)
        let scale = placement.scale
        let borderWidth = placement.borderWidth
        let borderColor = UIColor(red: shape.borderColor.red,
                                  green: shape.borderColor.green,
                                  blue: shape.borderColor.blue,
                                  alpha: shape.borderColor.alpha)
        var transform = CATransform3DMakeRotation(shape.rotationRadians(), 0, 0, 1)
        if widget.mirror {
            transform = CATransform3DConcat(transform, CATransform3DMakeScale(-1, 1, 1))
        }
        borderLayer.isHidden = false
        borderLayer.zPosition = CGFloat(index)
        borderLayer.transform = transform
        borderLayer.bounds = CGRect(origin: .zero, size: placement.borderSize)
        borderLayer.position = placement.center
        borderLayer.cornerRadius = CGFloat(shape.cornerRadiusPixels(placement.borderSize))
        borderLayer.backgroundColor = borderWidth > 0 ? borderColor.cgColor : nil
        contentLayer.frame = CGRect(origin: CGPoint(x: borderWidth, y: borderWidth), size: placement.size)
        contentLayer.cornerRadius = CGFloat(shape.cornerRadiusPixels(placement.size))
        previewLayer.frame = CGRect(x: -contentRegion.minX * scale,
                                    y: -contentRegion.minY * scale,
                                    width: canvasSize.width * scale,
                                    height: canvasSize.height * scale)
    }
}

class CameraPreviewUiView: UIView {
    private var sceneLayers: [UUID: AVCaptureVideoPreviewLayer] = [:]
    private var widgetLayers: [UUID: CameraPreviewWidgetLayer] = [:]
    private let widgetsLayer = CALayer()
    private var widgets: [CameraPreviewWidget] = []
    private var canvasSize: CGSize = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        widgetsLayer.zPosition = 1
        widgetsLayer.masksToBounds = true
        layer.addSublayer(widgetsLayer)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    var previewLayers: [AVCaptureVideoPreviewLayer: UUID] {
        var previewLayers: [AVCaptureVideoPreviewLayer: UUID] = [:]
        for (id, previewLayer) in sceneLayers {
            previewLayers[previewLayer] = id
        }
        for widgetLayer in widgetLayers.values {
            previewLayers[widgetLayer.previewLayer] = widgetLayer.deviceId
        }
        return previewLayers
    }

    func setDevices(ids: [UUID], widgets: [UUID: UUID]) {
        for (id, previewLayer) in sceneLayers where !ids.contains(id) {
            previewLayer.removeFromSuperlayer()
            sceneLayers.removeValue(forKey: id)
        }
        for id in ids where sceneLayers[id] == nil {
            let previewLayer = AVCaptureVideoPreviewLayer()
            previewLayer.frame = bounds
            previewLayer.isHidden = true
            layer.addSublayer(previewLayer)
            sceneLayers[id] = previewLayer
        }
        for (id, widgetLayer) in widgetLayers where widgets[id] != widgetLayer.deviceId {
            widgetLayer.borderLayer.removeFromSuperlayer()
            widgetLayers.removeValue(forKey: id)
        }
        for (id, deviceId) in widgets where widgetLayers[id] == nil {
            let widgetLayer = CameraPreviewWidgetLayer(deviceId: deviceId)
            widgetsLayer.addSublayer(widgetLayer.borderLayer)
            widgetLayers[id] = widgetLayer
        }
    }

    func select(id: UUID?, isMirrored: Bool) {
        for (previewLayerId, previewLayer) in sceneLayers {
            previewLayer.isHidden = previewLayerId != id
        }
        layer.sublayerTransform = isMirrored ? CATransform3DMakeScale(-1, 1, 1) : CATransform3DIdentity
    }

    func setWidgets(widgets: [CameraPreviewWidget], canvasSize: CGSize) {
        self.widgets = widgets
        self.canvasSize = canvasSize
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layoutWidgets()
        CATransaction.commit()
    }

    func setVideoOrientation(_ videoOrientation: AVCaptureVideoOrientation) {
        for previewLayer in previewLayers.keys {
            previewLayer.connection?.videoOrientation = videoOrientation
        }
    }

    private func layoutWidgets() {
        for widgetLayer in widgetLayers.values {
            widgetLayer.borderLayer.isHidden = true
        }
        guard !widgets.isEmpty else {
            return
        }
        widgetsLayer.frame = AVMakeRect(aspectRatio: canvasSize, insideRect: bounds)
        for (index, widget) in widgets.enumerated() {
            widgetLayers[widget.id]?.layout(widget: widget,
                                            index: index,
                                            canvasSize: canvasSize,
                                            streamSize: widgetsLayer.bounds.size)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for previewLayer in sceneLayers.values {
            previewLayer.frame = bounds
        }
        layoutWidgets()
        CATransaction.commit()
    }
}

struct CameraPreviewView: UIViewRepresentable {
    let model: Model

    func makeUIView(context _: Context) -> SharedUiViewContainerView {
        SharedUiViewContainerView(sharedView: model.cameraPreviewView)
    }

    func updateUIView(_ uiView: SharedUiViewContainerView, context _: Context) {
        uiView.attachSharedView()
    }
}

struct StreamView: View {
    @ObservedObject var show: Show
    let cameraPreviewView: CameraPreviewView
    let streamPreviewView: StreamPreviewView

    var body: some View {
        if show.chatPhone {
            Color.black
        } else {
            ZStack {
                streamPreviewView
                if show.cameraPreview {
                    cameraPreviewView
                }
            }
        }
    }
}
