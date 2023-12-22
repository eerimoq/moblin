import SwiftUI

struct RecordingsSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack {
            let recordings = model.recordingsStorage.listRecordings()
            if recordings.isEmpty {
                HStack {
                    Spacer()
                    Text("No recordings.")
                        .padding([.top], 20)
                    Spacer()
                }
            } else {
                Form {
                    Section {
                        ForEach(recordings.reversed()) { recording in
                            NavigationLink(
                                destination: RecordingsRecordingSettingsView(recording: recording)
                            ) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text(recording.title())
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
