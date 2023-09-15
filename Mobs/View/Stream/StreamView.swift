import HaishinKit
import SwiftUI

var attachedNetStream: NetStream?

struct StreamView: UIViewRepresentable {
    @ObservedObject var model: Model

    func makeUIView(context _: Context) -> MTHKView {
        return model.mthkView
    }

    func updateUIView(_: MTHKView, context _: Context) {
    }
}
