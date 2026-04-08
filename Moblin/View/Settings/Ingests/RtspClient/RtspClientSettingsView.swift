import SwiftUI

struct RtspClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtspClient: SettingsRtspClient
    @State var numberOfEnabledStreams: Int = 0

    private func status() -> String {
        return String(numberOfEnabledStreams)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    List {
                        ForEach(rtspClient.streams) { stream in
                            RtspClientStreamSettingsView(rtspClient: rtspClient, stream: stream)
                                .contextMenu {
                                    Button(role: .destructive) {
                                        rtspClient.streams.removeAll { $0.id == stream.id }
                                        model.reloadRtspClient()
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                        .onDelete { indexes in
                            rtspClient.streams.remove(atOffsets: indexes)
                            model.reloadRtspClient()
                        }
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
            numberOfEnabledStreams = rtspClient.streams.filter { $0.enabled }.count
        }
    }
}
