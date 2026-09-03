import AVFoundation
import SwiftUI

struct StreamPreviewView: UIViewRepresentable {
    let model: Model

    func makeUIView(context _: Context) -> PreviewView {
        model.streamPreviewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
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

    func makeUIView(context _: Context) -> CameraPreviewUiView {
        model.cameraPreviewView
    }

    func updateUIView(_: CameraPreviewUiView, context _: Context) {}
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
