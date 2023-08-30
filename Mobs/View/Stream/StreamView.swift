import HaishinKit
import SwiftUI

struct StreamView: UIViewRepresentable {
    var mthkView = MTHKView(frame: .zero)
    @Binding var rtmpStream: RTMPStream

    func makeUIView(context: Context) -> MTHKView {
        mthkView.videoGravity = .resizeAspect
        return mthkView
    }

    func updateUIView(_ uiView: MTHKView, context: Context) {
        mthkView.attachStream(rtmpStream)
    }
}
