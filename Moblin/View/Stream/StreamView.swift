import HaishinKit
import SwiftUI

struct StreamView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> PreviewView {
        return model.videoView
    }

    func updateUIView(_: HaishinKit.PreviewView, context _: Context) {}
}
