import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Text("Change settings in Moblin in iPhone/iPad.")
                NavigationLink(
                    destination: DebugSettingsView()
                ) {
                    HStack {
                        Image(systemName: "ladybug")
                            .frame(width: iconWidth)
                        Text("Debug")
                    }
                }
            }
        }
        .navigationTitle("Settings")
    }
}
