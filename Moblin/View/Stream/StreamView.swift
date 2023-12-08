import HaishinKit
import SwiftUI

struct StreamView: UIViewRepresentable {
    @EnvironmentObject var model: Model

    func makeUIView(context _: Context) -> MTHKView {
        return model.videoView
    }

    func updateUIView(_: HaishinKit.MTHKView, context _: Context) {}
}
