import SwiftUI

private struct RecordingsSettingsSummaryView: View {
    @EnvironmentObject var model: Model

    var recordingsStorage: RecordingsStorage {
        model.recordingsStorage
    }

    var body: some View {
        HStack {
            Spacer()
            VStack {
                Text(recordingsStorage.numberOfRecordingsString())
                    .font(.title2)
                Text("Total recordings")
                    .font(.subheadline)
            }
            Spacer()
            VStack {
                Text(recordingsStorage.totalSizeString())
                    .font(.title2)
                Text("Total size")
                    .font(.subheadline)
            }
            Spacer()
        }
    }
}

private struct RecordingsSettingsRecordingsView: View {
    @EnvironmentObject var model: Model
    @State var isPresentingBrowse = false

    var recordingsStorage: RecordingsStorage {
        model.recordingsStorage
    }

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(recordingsStorage.database.recordings) { recording in
                        NavigationLink {
                            RecordingsRecordingSettingsView(
                                recording: recording,
                                description: recording.description ?? ""
                            )
                        } label: {
                            HStack {
                                if let image = createThumbnail(path: recording.url()) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 90)
                                } else {
                                    Image(systemName: "photo")
                                }
                                VStack(alignment: .leading) {
                                    Text(recording.startTime.formatted())
                                    Text(recording.length().formatWithSeconds())
                                    Text(recording.subTitle())
                                        .font(.footnote)
                                }
                            }
                        }
                    }
                    .onDelete(perform: { indexSet in
                        for index in indexSet {
                            recordingsStorage.database.recordings[index].url().remove()
                        }
                        recordingsStorage.database.recordings.remove(atOffsets: indexSet)
                        recordingsStorage.store()
                    })
                }
            }
        }
    }
}

struct RecordingsSettingsView: View {
    var body: some View {
        VStack {
            RecordingsSettingsSummaryView()
            RecordingsSettingsRecordingsView()
        }
        .navigationTitle("Recordings")
    }
}
