import HaishinKit
import SwiftUI

struct StreamView: UIViewRepresentable {
    var mthkView = MTHKView(frame: .zero)
    @Binding var netStream: NetStream

    func makeUIView(context _: Context) -> MTHKView {
        mthkView.videoGravity = .resizeAspect
        return mthkView
    }

    func updateUIView(_: MTHKView, context _: Context) {
        // logger.info("stream: Attach stream")
        mthkView.attachStream(netStream)
    }
}
