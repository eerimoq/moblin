import SwiftUI

struct ExportSettingsView: View {
    @ObservedObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            Button("Export to clipboard") {
                if let message = model.settings.exportToClipboard() {
                    model.makeErrorToast(title: "Export settings failed", subTitle: message)
                } else {
                    model.makeToast(title: "Settings exported")
                }
            }
            Spacer()
        }
    }
}
