import SwiftUI

struct ImportSettingsView: View {
    @EnvironmentObject var model: Model

    private func succeeded() {
        model.makeToast(title: String(localized: "Settings imported"))
        model.updateIconImageFromDatabase()
        model.reloadStream()
        model.resetSelectedScene()
        model.updateButtonStates()
        model.updateFaceFilterButtonState()
    }

    private func failed(message: String) {
        model.makeErrorToast(
            title: String(localized: "Import settings failed"),
            subTitle: message
        )
    }

    var body: some View {
        HStack {
            Spacer()
            Button("Import from clipboard") {
                if let message = model.settings.importFromClipboard() {
                    if let url = URL(string: UIPasteboard.general.string ?? "") {
                        if let message = model.handleSettingsUrl(url: url) {
                            failed(message: message)
                        } else {
                            succeeded()
                        }
                    } else {
                        failed(message: message)
                    }
                } else {
                    succeeded()
                }
            }
            .disabled(model.isLive || model.isRecording)
            Spacer()
        }
    }
}
