import SwiftUI

struct SrtClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var srtClient: SettingsSrtClient
    @State var numberOfEnabledStreams: Int = 0

    private func status() -> String {
        String(numberOfEnabledStreams)
    }

    private func deleteStream(at indexes: IndexSet) {
        srtClient.streams.remove(atOffsets: indexes)
        model.reloadSrtClient()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(srtClient.streams) { stream in
                            SrtClientStreamSettingsView(srtClient: srtClient, stream: stream)
                                .contextMenuDeleteButton {
                                    if let offsets = makeOffsets(srtClient.streams, stream.id) {
                                        deleteStream(at: offsets)
                                    }
                                }
                        }
                        .onDelete(perform: deleteStream)
                    }
                    CreateButtonView {
                        let stream = SettingsSrtClientStream()
                        stream.name = makeUniqueName(name: SettingsSrtClientStream.baseName,
                                                     existingNames: srtClient.streams)
                        srtClient.streams.append(stream)
                    }
                } header: {
                    Text("Streams")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
            .navigationTitle("SRT client")
        } label: {
            HStack {
                Text("SRT client")
                Spacer()
                GrayTextView(text: status())
            }
        }
        .onAppear {
            numberOfEnabledStreams = srtClient.streams.filter(\.enabled).count
        }
    }
}
