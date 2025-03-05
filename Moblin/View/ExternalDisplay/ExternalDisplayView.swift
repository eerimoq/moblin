import AVFoundation
import SwiftUI

struct ExternalDisplayStreamPreviewView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> PreviewView {
        return model.externalDisplayStreamPreviewView
    }

    func updateUIView(_: PreviewView, context _: Context) {}
}

struct ExternalDisplayView: View {
    var body: some View {
        ExternalDisplayStreamPreviewView()
    }
}
