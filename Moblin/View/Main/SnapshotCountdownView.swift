import SwiftUI

struct SnapshotCountdownView: View {
    @EnvironmentObject var model: Model
    let message: String

    var body: some View {
        VStack {
            Text("Taking snapshot in")
            Text(String(model.snapshotCountdown))
                .font(.title)
            Text(message)
                .multilineTextAlignment(.center)
        }
        .foregroundColor(.white)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: 300, alignment: .center)
        .padding(10)
        .background(.black.opacity(0.75))
        .cornerRadius(10)
    }
}
