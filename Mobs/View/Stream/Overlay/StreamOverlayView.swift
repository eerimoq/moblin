import SwiftUI

struct StreamOverlayView: View {
    @ObservedObject var model: Model

    var body: some View {
        HStack {
            LeftOverlayView(model: model)
            Spacer()
            RightOverlayView(model: model)
        }
        .padding([.trailing, .top])
    }
}
