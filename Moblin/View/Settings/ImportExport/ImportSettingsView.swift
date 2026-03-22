import SwiftUI
import UniformTypeIdentifiers

private struct SettingsFilePickerView: UIViewControllerRepresentable {
    @EnvironmentObject var model: Model

    func makeUIViewController(context _: Context) -> UIDocumentPickerViewController {
        let documentPicker = UIDocumentPickerViewController(
            forOpeningContentTypes: [moblinSettingsFileType],
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

    var body: some View {
        Section {
            if importState == .fromFile {
                HCenter {
                    ProgressView()
                }
            } else {
                TextButtonView("Import from file") {
                    showPicker = true
                    model.onDocumentPickerUrl = { url in
                        model.importSettingsWithConfirmation {
                            importState = .fromFile
                            model.importSettingsFromFile(url: url) {
                                importState = .idle
                            }
                        }
                    }
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
                    model.importSettingsWithConfirmation {
                        importState = .fromClipboard
                        model.importSettingsFromClipboard {
                            importState = .idle
                        }
                    }
                }
                .disabled(model.isLive || model.isRecording || importState != .idle)
            }
        }
    }
}
