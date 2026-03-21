import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let moblinSettings = UTType(
        exportedAs: "com.eerimoq.moblin.settings",
        conformingTo: .archive
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

private enum ImportState {
    case idle
    case fromFile
    case fromClipboard
}

struct ImportSettingsView: View {
    @ObservedObject var model: Model
    @State private var showPicker = false
    @State private var importState: ImportState = .idle

    private func onUrl(url: URL) {
        importState = .fromFile
        model.importFromFile(url: url) {
            importState = .idle
        }
    }

    var body: some View {
        Section {
            if importState == .fromFile {
                HCenter {
                    ProgressView()
                }
            } else {
                TextButtonView("Import from file") {
                    showPicker = true
                    model.onDocumentPickerUrl = onUrl
                }
                .disabled(model.isLive || model.isRecording || importState != .idle)
                .sheet(isPresented: $showPicker) {
                    SettingsFilePickerView()
                }
            }
        }
        Section {
            if importState == .fromClipboard {
                HCenter {
                    ProgressView()
                }
            } else {
                TextButtonView("Import from clipboard") {
                    importState = .fromClipboard
                    model.importFromClipboard {
                        importState = .idle
                    }
                }
                .disabled(model.isLive || model.isRecording || importState != .idle)
            }
        }
    }
}
