import SwiftUI

struct RemoteControlTallyView: View {
    @ObservedObject var tally: RemoteControlTally

    var body: some View {
        if tally.on {
            ZStack(alignment: .top) {
                Rectangle()
                    .strokeBorder(.red, lineWidth: 4)
                Text("ON AIR")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.red)
            }
            .allowsHitTesting(false)
        }
    }
}
