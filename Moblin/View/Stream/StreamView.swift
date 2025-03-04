import AVFoundation
import SwiftUI

struct StreamPreviewView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> PreviewView {
        return model.streamPreviewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
}

struct ExternalDisplayStreamPreviewView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> PreviewView {
        return model.externalDisplayStreamPreviewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
}

class CameraPreviewUiView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> CameraPreviewUiView {
        return model.cameraPreviewView
    }

    func updateUIView(_: CameraPreviewUiView, context _: Context) {}
}

struct StreamView: View {
    @EnvironmentObject var model: Model
    var cameraPreviewView: CameraPreviewView
    var streamPreviewView: StreamPreviewView

    var body: some View {
        if model.showCameraPreview {
            cameraPreviewView
        } else {
            streamPreviewView
        }
    }
}
