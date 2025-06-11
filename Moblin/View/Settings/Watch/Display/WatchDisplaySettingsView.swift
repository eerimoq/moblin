import SwiftUI

struct WatchDisplaySettingsView: View {
    @ObservedObject var show: WatchSettingsShow

    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WatchLocalOverlaysSettingsView(show: show)
                } label: {
                    Text("Local overlays")
                }
            }
        }
        .navigationTitle("Display")
    }
}
