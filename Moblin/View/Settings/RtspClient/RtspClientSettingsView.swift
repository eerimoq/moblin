import SwiftUI

struct RtspClientSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtspClient: SettingsRtspClient

    var body: some View {
        Form {
            Section {
                List {
                    ForEach(rtspClient.streams) { stream in
                        RtspClientStreamSettingsView(rtspClient: rtspClient, stream: stream)
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
    }
}
