import SwiftUI

struct RecordingsSettingsView: View {
    @EnvironmentObject var model: Model

    var recordingsStorage: RecordingsStorage {
        model.recordingsStorage
    }

    var body: some View {
        VStack {
            let recordings = recordingsStorage.listRecordings()
            if recordings.isEmpty {
                HStack {
                    Spacer()
                    Text("No recordings.")
                        .padding([.top], 20)
                    Spacer()
                }
            } else {
                VStack {
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
                    Form {
                        Section {
                            ForEach(recordings.reversed()) { recording in
                                NavigationLink(
                                    destination: RecordingsRecordingSettingsView(recording: recording)
                                ) {
                                    HStack {
                                        Image(systemName: "photo")
                                        VStack(alignment: .leading) {
                                            Text(recording.title())
                                            Text(recording.subTitle())
                                                .font(.footnote)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Spacer()
        }
        .navigationTitle("Recordings")
        .toolbar {
            SettingsToolbar()
        }
    }
}
