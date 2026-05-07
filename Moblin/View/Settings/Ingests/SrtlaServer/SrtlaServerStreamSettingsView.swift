import Network
import SwiftUI

struct SrtlaServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    @ObservedObject var srtlaServer: SettingsSrtlaServer
    @ObservedObject var stream: SettingsSrtlaServerStream

    private func changeStreamId(value: String) -> String? {
        let streamId = value.trim()
        guard streamId.wholeMatch(of: /[a-zA-Z0-9]*/) != nil else {
            return String(localized: "Bad character")
        }
        guard model.getSrtlaStream(streamId: streamId) == nil else {
            return String(localized: "Already in use")
        }
        return nil
    }

    private func submitStreamId(value: String) {
        let streamId = value.trim()
        guard streamId.wholeMatch(of: /[a-zA-Z0-9]*/) != nil else {
            return
        }
        guard model.getSrtlaStream(streamId: streamId) == nil else {
            return
        }
        stream.streamId = streamId
    }

    private func formatUrl(proto: String, ip: String, port: UInt16) -> String {
        var url = "\(proto)://\(ip):\(port)"
        if !stream.streamId.isEmpty {
            url += "?streamid=\(stream.streamId)"
        }
        return url
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: srtlaServer.streams)
                        .disabled(srtlaServer.enabled)
                    TextEditNavigationView(
                        title: String(localized: "Stream id"),
                        value: stream.streamId,
                        onChange: changeStreamId,
                        onSubmit: submitStreamId,
                        footers: [String(localized: "May only contain lower case letters.")]
                    )
                    .disabled(srtlaServer.enabled)
                } footer: {
                    Text("The stream name is shown in the list of cameras in scene settings.")
                }
                Section {
                    UrlsView(
                        status: status,
                        title: String(localized: "SRT URLs"),
                        formatUrl: { formatUrl(proto: "srt", ip: $0, port: srtlaServer.srtPort) }
                    )
                    UrlsView(
                        status: status,
                        title: String(localized: "SRTLA URLs"),
                        formatUrl: { formatUrl(proto: "srtla", ip: $0, port: srtlaServer.srtlaPort) }
                    )
                } header: {
                    Text("Publish URLs")
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enter one of the URLs into the SRT(LA) publisher device to send video \
                        to this stream. Usually enter the WiFi or Personal Hotspot URL.
                        """)
                    }
                }
            }
            .navigationTitle("Stream")
        } label: {
            HStack {
                if model.isSrtlaStreamConnected(streamId: stream.streamId) {
                    Image(systemName: "cable.connector")
                } else {
                    Image(systemName: "cable.connector.slash")
                }
                Text(stream.name)
                Spacer()
            }
        }
    }
}
