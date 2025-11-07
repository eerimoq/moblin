import SwiftUI

struct RtmpServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtmpServer: SettingsRtmpServer

    private func submitPort(value: String) {
        guard let port = UInt16(value) else {
            return
        }
        rtmpServer.port = port
        model.reloadRtmpServer()
    }

    private func status() -> String {
        if rtmpServer.enabled {
            return String(rtmpServer.streams.count)
        } else {
            return "0"
        }
    }

    var body: some View {
        NavigationLink {
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
                                .foregroundStyle(.blue)
                            Text("Disable the RTMP server to change its settings.")
                        }
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Port"),
                        value: String(rtmpServer.port),
                        onChange: isValidPort,
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
                        stream.name = makeUniqueName(name: SettingsRtmpServerStream.baseName,
                                                     existingNames: rtmpServer.streams)
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
        } label: {
            HStack {
                Text("RTMP server")
                Spacer()
                Text(status())
                    .foregroundStyle(.gray)
            }
        }
    }
}
