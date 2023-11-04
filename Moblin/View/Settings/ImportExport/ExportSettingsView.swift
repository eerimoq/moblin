import SwiftUI

struct ExportSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            Button("Export to clipboard") {
                model.settings.exportToClipboard()
                model.makeToast(title: "Settings exported")
            }
            Spacer()
        }
    }
}
