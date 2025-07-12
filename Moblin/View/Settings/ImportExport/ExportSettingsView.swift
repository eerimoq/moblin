import SwiftUI

struct ExportSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HCenter {
            Button("Export to clipboard") {
                model.settings.exportToClipboard()
                model.makeToast(title: "Settings exported")
            }
        }
    }
}
