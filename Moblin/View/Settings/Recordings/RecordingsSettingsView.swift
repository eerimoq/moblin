import SwiftUI

private struct RecordingsLocationView: View {
    let model: Model
    let text: Text
    let path: URL

    private func makeSharedUrl(path: URL) -> URL? {
        guard let sharedUrl = URL(string: "shareddocuments://\(path.path())") else {
            return nil
        }
        if UIApplication.shared.canOpenURL(sharedUrl) {
            return sharedUrl
        } else {
            return nil
        }
    }

    private func openInFilesApp(sharedUrl: URL) {
        UIApplication.shared.open(sharedUrl)
    }

    private func copyPathToClipboard(path: URL) {
        UIPasteboard.general.string = path.path()
        let subTitle: String?
        if isMac() {
            subTitle = String(localized: "Open it in Finder app → Go → Go to Folder...")
        } else {
            subTitle = nil
        }
        model.makeToast(title: String(localized: "Directory copied to clipboard"), subTitle: subTitle)
    }

    var body: some View {
        Section {
            HStack {
                text
                Spacer()
                if let sharedUrl = makeSharedUrl(path: path) {
                    Button {
                        openInFilesApp(sharedUrl: sharedUrl)
                    } label: {
                        Image(systemName: "arrow.turn.up.right")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                } else {
                    Button {
                        copyPathToClipboard(path: path)
                    } label: {
                        Image(systemName: "document.on.document")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)
                }
            }
        }
    }
}

struct RecordingsSettingsView: View {
    let model: Model

    var body: some View {
        Form {
            RecordingsLocationView(model: model,
                                   text: Text("Default recordings directory"),
                                   path: model.recordingsStorage.defaultStorageDirectory())
            if let path = model.stream.recording.recordingPath {
                if let path = makeRecordingPath(recordingPath: path) {
                    RecordingsLocationView(model: model,
                                           text: Text("Current recordings directory"),
                                           path: path)
                } else {
                    Text("Current recordings directory unavailable")
                }
            }
            RecordingsLocationView(model: model,
                                   text: Text("Replays directory"),
                                   path: model.replaysStorage.defaultStorageDirectory())
        }
        .navigationTitle("Recordings")
    }
}
