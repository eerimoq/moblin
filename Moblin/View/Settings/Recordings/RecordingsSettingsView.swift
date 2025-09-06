import SwiftUI

private struct RecordingsLocationView: View {
    let text: Text
    let path: URL

    private func openInFilesApp(path: URL) {
        guard let sharedUrl = URL(string: "shareddocuments://\(path.path())") else {
            return
        }
        UIApplication.shared.open(sharedUrl)
    }

    var body: some View {
        Section {
            Button {
                openInFilesApp(path: path)
            } label: {
                HCenter {
                    Image(systemName: "arrow.turn.up.right")
                    text
                }
            }
        }
    }
}

struct RecordingsSettingsView: View {
    let model: Model

    var body: some View {
        Form {
            RecordingsLocationView(text: Text("Show recordings in Files app"),
                                   path: model.recordingsStorage.defaultStorageDirectry())
            RecordingsLocationView(text: Text("Show replays in Files app"),
                                   path: model.replaysStorage.defaultStorageDirectry())
        }
        .navigationTitle("Recordings")
    }
}
