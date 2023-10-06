import SwiftUI

struct StreamOverlayView: View {
    @ObservedObject var model: Model

    var body: some View {
        ZStack {
            HStack {
                Spacer()
                RightOverlayView(model: model)
            }
            GeometryReader { metrics in
                HStack {
                    LeftOverlayView(model: model)
                        .allowsHitTesting(false)
                    Spacer()
                }
                .frame(width: metrics.size.width * 0.7)
            }
            // model.webView
        }
        .padding([.trailing, .top])
    }
}
