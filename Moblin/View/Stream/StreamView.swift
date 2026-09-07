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

class CameraPreviewUiView: UIView {
    private(set) var previewLayers: [UUID: AVCaptureVideoPreviewLayer] = [:]

    func setDevices(ids: [UUID]) {
        for (id, previewLayer) in previewLayers where !ids.contains(id) {
            previewLayer.removeFromSuperlayer()
            previewLayers.removeValue(forKey: id)
        }
        for id in ids where previewLayers[id] == nil {
            let previewLayer = AVCaptureVideoPreviewLayer()
            previewLayer.frame = bounds
            previewLayer.isHidden = true
            layer.addSublayer(previewLayer)
            previewLayers[id] = previewLayer
        }
    }

    func select(id: UUID?) {
        for (previewLayerId, previewLayer) in previewLayers {
            previewLayer.isHidden = previewLayerId != id
        }
    }

    func setVideoOrientation(_ videoOrientation: AVCaptureVideoOrientation) {
        for previewLayer in previewLayers.values {
            previewLayer.connection?.videoOrientation = videoOrientation
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for previewLayer in previewLayers.values {
            previewLayer.frame = bounds
        }
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
        } else if show.cameraPreview {
            cameraPreviewView
        } else {
            streamPreviewView
        }
    }
}
