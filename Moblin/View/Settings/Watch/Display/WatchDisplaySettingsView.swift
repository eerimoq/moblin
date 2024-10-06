import SwiftUI

struct WatchDisplaySettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink {
                    WatchLocalOverlaysSettingsView()
                } label: {
                    Text("Local overlays")
                }
            }
        }
        .navigationTitle("Display")
    }
}
