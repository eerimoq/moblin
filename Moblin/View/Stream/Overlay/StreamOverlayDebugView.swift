import SwiftUI

struct StreamOverlayDebugView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            ForEach(model.debugLines, id: \.self) { line in
                Text(line)
                    .font(smallFont)
                    .foregroundColor(.white)
                    .padding([.leading, .trailing], 2)
                    .background(Color(white: 0, opacity: 0.8))
                    .cornerRadius(5)
            }
        }
    }
}
