import SwiftUI

struct TallyView: View {
    @ObservedObject var tally: Tally

    var body: some View {
        if let state = tally.state {
            ZStack(alignment: .top) {
                Rectangle()
                    .strokeBorder(state.background.color(), lineWidth: 4)
                if !state.message.isEmpty {
                    Text(state.message)
                        .font(.caption.bold())
                        .lineLimit(1)
                        .foregroundStyle(state.foreground.color())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(state.background.color(), ignoresSafeAreaEdges: [])
                }
            }
            .allowsHitTesting(false)
        }
    }
}
