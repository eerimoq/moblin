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
                            database.recordings[index].url().remove()
                        }
                        database.recordings.remove(atOffsets: indexSet)
                        recordingsStorage.store()
                    }
                }
            } footer: {
                if !database.recordings.isEmpty {
                    SwipeLeftToDeleteHelpView(kind: "a recording")
                }
            }
        }
    }
}

struct RecordingsSettingsView: View {
    let model: Model

    var body: some View {
        VStack {
            RecordingsSettingsSummaryView(database: model.recordingsStorage.database)
            RecordingsSettingsRecordingsView(model: model,
                                             recordingsStorage: model.recordingsStorage,
                                             database: model.recordingsStorage.database)
        }
        .navigationTitle("Recordings")
    }
}
