import SwiftUI

struct SnapshotCountdownView: View {
    @ObservedObject var snapshot: Snapshot

    var body: some View {
        if let snapshotJob = snapshot.currentJob, snapshot.countdown > 0 {
            VStack {
                Text("Taking snapshot in")
                Text(String(snapshot.countdown))
                    .font(.title)
                Text(snapshotJob.message)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: 300, alignment: .center)
            .padding(10)
            .background(.black.opacity(0.75))
            .cornerRadius(10)
        }
    }
}
