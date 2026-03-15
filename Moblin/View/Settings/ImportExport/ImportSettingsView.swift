import SwiftUI
import UniformTypeIdentifiers

private struct SettingsFilePickerView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.json],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

struct ImportSettingsView: View {
    @EnvironmentObject var model: Model
    @State private var showPicker = false

    private func succeeded() {
        model.setCurrentStream()
        model.updateIconImageFromDatabase()
        model.reloadStream()
        model.resetSelectedScene()
        model.updateQuickButtonStates()
    }

    private func failed(message: String) {
        model.makeErrorToast(
            title: String(localized: "Import settings failed"),
            subTitle: message
        )
    }

    private func onUrl(url: URL) {
        if let message = model.settings.importFromFile(url: url) {
            failed(message: message)
        } else {
            succeeded()
        }
    }

    var body: some View {
        TextButtonView("Import from file") {
            showPicker = true
            model.onDocumentPickerUrl = onUrl
        }
        .disabled(model.isLive || model.isRecording)
        .sheet(isPresented: $showPicker) {
            SettingsFilePickerView()
        }
    }
}
