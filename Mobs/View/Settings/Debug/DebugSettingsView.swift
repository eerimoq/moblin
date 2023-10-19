import SwiftUI

struct DebugSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar

    var body: some View {
        Form {
            Section {
                NavigationLink(destination: DebugLogSettingsView(
                    model: model,
                    toolbar: toolbar
                )) {
                    Text("Log")
                }
                Toggle("Debug", isOn: Binding(get: {
                    logger.debugEnabled
                }, set: { value in
                    logger.debugEnabled = value
                }))
            }
        }
        .navigationTitle("Debug")
        .toolbar {
            toolbar
        }
    }
}
