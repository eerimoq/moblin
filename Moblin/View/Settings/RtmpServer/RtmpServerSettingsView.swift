import SwiftUI

struct RtmpServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtmpServer: SettingsRtmpServer

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()), port > 0 else {
            rtmpServer.portString = String(rtmpServer.port)
            model.makePortErrorToast(port: value)
            return
        }
        rtmpServer.port = port
        model.reloadRtmpServer()
    }

    var body: some View {
        Form {
            Section {
                Text("""
                The RTMP server allows Moblin to receive video streams over the network. \
                This allows the use of some drones and other cameras as sources.
                """)
            }
            Section {
                Toggle("Enabled", isOn: $rtmpServer.enabled)
                    .onChange(of: rtmpServer.enabled) { _ in
                        model.reloadRtmpServer()
                    }
            }
            if rtmpServer.enabled {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Disable the RTMP server to change its settings.")
                    }
                }
            }
            Section {
                TextEditBindingNavigationView(
                    title: String(localized: "Port"),
                    value: $rtmpServer.portString,
                    onSubmit: submitPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(rtmpServer.enabled)
            } footer: {
                Text("The TCP port the RTMP server listens for RTMP publishers on.")
            }
            Section {
                List {
                    let list = ForEach(rtmpServer.streams) { stream in
                        RtmpServerStreamSettingsView(
                            status: model.statusOther,
                            rtmpServer: rtmpServer,
                            stream: stream
                        )
                    }
                    if !rtmpServer.enabled {
                        list.onDelete { indexes in
                            rtmpServer.streams.remove(atOffsets: indexes)
                            model.reloadRtmpServer()
                            model.updateMicsListAsync()
                        }
                    } else {
                        list
                    }
                }
                CreateButtonView {
                    let stream = SettingsRtmpServerStream()
                    while true {
                        stream.streamKey = randomHumanString()
                        if model.getRtmpStream(streamKey: stream.streamKey) == nil {
                            break
                        }
                    }
                    rtmpServer.streams.append(stream)
                    model.updateMicsListAsync()
                }
                .disabled(model.rtmpServerEnabled())
            } header: {
                Text("Streams")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Each stream can receive video from one RTMP publisher, typically a drone.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
        }
        .navigationTitle("RTMP server")
    }
}
