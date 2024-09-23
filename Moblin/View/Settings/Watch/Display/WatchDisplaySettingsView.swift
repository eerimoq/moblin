import SwiftUI

struct WatchDisplaySettingsView: View {
    var body: some View {
        Form {
            Section {
                NavigationLink(destination: WatchLocalOverlaysSettingsView()) {
                    Text("Local overlays")
                }
            }
        }
        .navigationTitle("Display")
    }
}
