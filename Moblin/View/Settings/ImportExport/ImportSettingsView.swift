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
            forOpeningContentTypes: [.zip],
            asCopy: true
        )
        documentPicker.delegate = model
        return documentPicker
    }

    func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}
}

struct ImportSettingsView: View {
    @ObservedObject var model: Model
    @State private var showPicker = false
    @State private var importing = false

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
        importing = true
        model.settings.importFromFile(url: url) { message in
            if let message {
                failed(message: message)
            } else {
                succeeded()
            }
            importing = false
        }
    }

    var body: some View {
        if importing {
            HCenter {
                ProgressView()
            }
        } else {
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
}
