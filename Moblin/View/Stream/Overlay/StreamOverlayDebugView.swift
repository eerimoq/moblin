import SwiftUI

struct StreamOverlayDebugView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var debugOverlay: DebugOverlayProvider

    var body: some View {
        if !debugOverlay.debugLines.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(debugOverlay.debugLines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(smallFont)
            .foregroundStyle(.white)
            .padding([.leading, .trailing], 2)
            .background(Color(white: 0, opacity: 0.75))
            .cornerRadius(5)
        }
    }
}
