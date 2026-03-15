import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let moblinSettings = UTType(
        exportedAs: "com.eerimoq.moblin.settings",
        conformingTo: .data
    )
}

private struct SettingsFilePickerView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.moblinSettings],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

struct ImportSettingsView: View {
    let model: Model
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
        TextButtonView("Import") {
            showPicker = true
            model.onDocumentPickerUrl = onUrl
        }
        .disabled(model.isLive || model.isRecording)
        .sheet(isPresented: $showPicker) {
            SettingsFilePickerView()
        }
    }
}
