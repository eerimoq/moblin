import SwiftUI

struct DebugSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView(model: model)) {
                    Text("Log")
                }
            }
        }
        .navigationTitle("Debug")
    }
}
