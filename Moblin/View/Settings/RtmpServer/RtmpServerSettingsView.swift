import SwiftUI

struct RtmpServerSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.rtmpServer!.port = port
        model.store()
        model.reloadRtmpServer()
    }

    var body: some View {
        Form {
            Text("""
            The RTMP server receives video over the network, enabling Moblin to \
            receive video from for example a drone and use it as a camera source.
            """)
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.rtmpServer!.enabled
                }, set: { value in
                    model.database.rtmpServer!.enabled = value
                    model.store()
                    model.reloadRtmpServer()
                }))
            }
            Section {
                NavigationLink(destination: TextEditView(
                    title: String(localized: "Port"),
                    value: String(model.database.rtmpServer!.port),
                    onSubmit: submitPort
                )) {
                    TextItemView(
                        name: String(localized: "Port"),
                        value: String(model.database.rtmpServer!.port)
                    )
                }
            } footer: {
                Text("The TCP port the RTMP server listens for RTMP publishers on.")
            }
            Section {
                List {
                    ForEach(model.database.rtmpServer!.streams) { stream in
                        NavigationLink(destination: RtmpServerStreamSettingsView(
                            port: model.database.rtmpServer!.port,
                            stream: stream
                        )) {
                            Text(stream.name)
                        }
                    }
                    .onDelete(perform: { indexes in
                        model.database.rtmpServer!.streams.remove(atOffsets: indexes)
                        model.store()
                        model.reloadRtmpServer()
                    })
                }
                CreateButtonView(action: {
                    model.database.rtmpServer!.streams.append(SettingsRtmpServerStream())
                    model.store()
                    model.objectWillChange.send()
                })
            } header: {
                Text("Streams")
            } footer: {
                Text("Each stream can receive video from one RTMP publisher, typically a drone.")
            }
        }
        .navigationTitle("RTMP server")
        .toolbar {
            SettingsToolbar()
        }
    }
}
