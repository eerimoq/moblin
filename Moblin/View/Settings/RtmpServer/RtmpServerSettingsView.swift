import SwiftUI

struct RtmpServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()), port > 0 else {
            model.makePortErrorToast(port: value)
            return
        }
        database.rtmpServer.port = port
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
                Toggle("Enabled", isOn: Binding(get: {
                    database.rtmpServer.enabled
                }, set: { value in
                    database.rtmpServer.enabled = value
                    model.reloadRtmpServer()
                    model.objectWillChange.send()
                }))
            }
            if model.rtmpServerEnabled() {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Disable the RTMP server to change its settings.")
                    }
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "Port"),
                    value: String(database.rtmpServer.port),
                    onSubmit: submitPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("The TCP port the RTMP server listens for RTMP publishers on.")
            }
            Section {
                List {
                    let list = ForEach(database.rtmpServer.streams) { stream in
                        NavigationLink {
                            RtmpServerStreamSettingsView(
                                status: model.statusOther,
                                port: database.rtmpServer.port,
                                stream: stream
                            )
                        } label: {
                            HStack {
                                if model.isRtmpStreamConnected(streamKey: stream.streamKey) {
                                    Image(systemName: "cable.connector")
                                } else {
                                    Image(systemName: "cable.connector.slash")
                                }
                                Text(stream.name)
                                Spacer()
                            }
                        }
                    }
                    if !model.rtmpServerEnabled() {
                        list.onDelete { indexes in
                            database.rtmpServer.streams.remove(atOffsets: indexes)
                            model.reloadRtmpServer()
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
                    database.rtmpServer.streams.append(stream)
                    model.objectWillChange.send()
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
