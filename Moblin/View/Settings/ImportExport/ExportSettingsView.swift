import SwiftUI

struct ExportSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            Button("Export to clipboard") {
                do {
                    try model.settings.exportToClipboard()
                    model.makeToast(title: "Settings exported")
                } catch {
                    model.makeErrorToast(title: "Failed to export settings")
                }
            }
            Spacer()
        }
    }
}
