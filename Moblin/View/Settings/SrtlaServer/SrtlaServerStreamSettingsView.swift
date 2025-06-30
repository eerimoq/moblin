import Network
import SwiftUI

private struct UrlsView: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let proto: String
    let port: UInt16
    let streamId: String

    private func title() -> String {
        return String(localized: "\(proto.uppercased()) URLs")
    }

    private func formatUrl(ip: String) -> String {
        var url = "\(proto)://\(ip):\(port)"
        if !streamId.isEmpty {
            url += "?streamid=\(streamId)"
        }
        return url
    }

    var body: some View {
        NavigationLink {
            Form {
                UrlsIpv4View(model: model, status: status, formatUrl: formatUrl)
                UrlsIpv6View(model: model, status: status, formatUrl: formatUrl)
            }
            .navigationTitle(title())
        } label: {
            Text(title())
        }
    }
}

struct SrtlaServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    @ObservedObject var srtlaServer: SettingsSrtlaServer
    @ObservedObject var stream: SettingsSrtlaServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
    }

    private func submitStreamId(value: String) {
        let streamId = value.trim()
        guard streamId.wholeMatch(of: /[a-zA-Z0-9]*/) != nil else {
            return
        }
        if model.getSrtlaStream(streamId: streamId) != nil {
            return
        }
        stream.streamId = streamId
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Name"),
                        value: stream.name,
                        onSubmit: submitName,
                        capitalize: true
                    )
                    .disabled(srtlaServer.enabled)
                    TextEditNavigationView(
                        title: String(localized: "Stream id"),
                        value: stream.streamId,
                        onSubmit: submitStreamId,
                        footers: [String(localized: "May only contain lower case letters.")]
                    )
                    .disabled(srtlaServer.enabled)
                } footer: {
                    Text("The stream name is shown in the list of cameras in scene settings.")
                }
                Section {
                    Toggle("Auto select mic", isOn: $stream.autoSelectMic)
                        .disabled(srtlaServer.enabled)
                } footer: {
                    Text("Automatically select the stream's audio as mic when connected.")
                }
                Section {
                    if srtlaServer.enabled {
                        UrlsView(
                            model: model,
                            status: status,
                            proto: "srt",
                            port: srtlaServer.srtPort,
                            streamId: stream.streamId
                        )
                        UrlsView(
                            model: model,
                            status: status,
                            proto: "srtla",
                            port: srtlaServer.srtlaPort,
                            streamId: stream.streamId
                        )
                    } else {
                        Text("Enable the SRT(LA) server to see URLs.")
                    }
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
