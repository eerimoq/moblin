import SwiftUI

struct RtspClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtspClient: SettingsRtspClient
    @State var numberOfEnabledStreams: Int = 0

    private func status() -> String {
        String(numberOfEnabledStreams)
    }

    private func deleteStream(at indexes: IndexSet) {
        rtspClient.streams.remove(atOffsets: indexes)
        model.reloadRtspClient()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(rtspClient.streams) { stream in
                            RtspClientStreamSettingsView(rtspClient: rtspClient, stream: stream)
                                .contextMenuDeleteButton {
                                    if let offsets = makeOffsets(rtspClient.streams, stream.id) {
                                        deleteStream(at: offsets)
                                    }
                                }
                        }
                        .onDelete(perform: deleteStream)
                    }
                    CreateButtonView {
                        let stream = SettingsRtspClientStream()
                        stream.name = makeUniqueName(name: SettingsRtspClientStream.baseName,
                                                     existingNames: rtspClient.streams)
                        rtspClient.streams.append(stream)
                    }
                } header: {
                    Text("Streams")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
            .navigationTitle("RTSP client")
        } label: {
            HStack {
                Text("RTSP client")
                Spacer()
                GrayTextView(text: status())
            }
        }
        .onAppear {
            numberOfEnabledStreams = rtspClient.streams.filter(\.enabled).count
        }
    }
}
