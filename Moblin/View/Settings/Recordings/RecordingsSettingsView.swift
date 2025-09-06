import SwiftUI

private struct RecordingsSettingsSummaryView: View {
    @ObservedObject var database: RecordingsDatabase

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text(database.numberOfRecordingsString())
                    .font(.title2)
                Text("Total recordings")
                    .font(.subheadline)
            }
            Spacer()
            VStack {
                Text(database.totalSizeString())
                    .font(.title2)
                Text("Total size")
                    .font(.subheadline)
            }
            Spacer()
        }
    }
}

private struct RecordingsSettingsRecordingsView: View {
    let model: Model
    let recordingsStorage: RecordingsStorage
    @ObservedObject var database: RecordingsDatabase

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(database.recordings) { recording in
                        RecordingsRecordingSettingsView(model: model, recording: recording)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            database.recordings[index].url()?.remove()
                        }
                        database.recordings.remove(atOffsets: indexSet)
                        recordingsStorage.store()
                    }
                }
            } footer: {
                if !database.recordings.isEmpty {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a recording"))
                }
            }
        }
    }
}

struct RecordingsSettingsView: View {
    let model: Model

    private func openInFilesApp() {
        let recordingsDirectory = model.recordingsStorage.defaultStorageDirectry().path()
        guard let sharedUrl = URL(string: "shareddocuments://\(recordingsDirectory)") else {
            return
        }
        UIApplication.shared.open(sharedUrl)
    }

    var body: some View {
        Form {
            Section {
                Button {
                    openInFilesApp()
                } label: {
                    HCenter {
                        Image(systemName: "arrow.turn.up.right")
                        Text("Show in Files app")
                    }
                }
            }
        }
        .navigationTitle("Recordings")
    }
}
