import SwiftUI

struct ImportSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack {
            Spacer()
            Button("Import from clipboard") {
                if let message = model.settings.importFromClipboard() {
                    model.makeErrorToast(
                        title: String(localized: "Import settings failed"),
                        subTitle: message
                    )
                } else {
                    model.makeToast(title: String(localized: "Settings imported"))
                    model.updateIconImageFromDatabase()
                    model.reloadStream()
                    model.resetSelectedScene()
                    model.updateButtonStates()
                }
            }
            .disabled(model.isLive || model.isRecording)
            Spacer()
        }
    }
}
