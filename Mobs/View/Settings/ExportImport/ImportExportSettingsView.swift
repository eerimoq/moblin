import SwiftUI

struct ImportExportSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        Form {
            Section {
                ImportSettingsView(model: model)
            }
            Section {
                ExportSettingsView(model: model)
            } footer: {
                Text("""
                     Do not share your settings with anyone as they may contain \
                     sensitive data (stream keys, etc.)!
                     """
                ).bold()
            }
        }
        .navigationTitle("Import and export settings")
    }
}
