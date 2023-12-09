import HaishinKit
import SwiftUI

struct StreamView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> PiPHKView {
        return model.videoView
    }

    func updateUIView(_: HaishinKit.PiPHKView, context _: Context) {}
}
