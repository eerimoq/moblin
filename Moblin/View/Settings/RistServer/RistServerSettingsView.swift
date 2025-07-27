import SwiftUI

struct RistServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var ristServer: SettingsRistServer

    var body: some View {
        Form {
            Section {
                Text("""
                The RIST server allows Moblin to receive video streams over the network.
                """)
            }
            Section {
                Toggle("Enabled", isOn: $ristServer.enabled)
                    .onChange(of: ristServer.enabled) { _ in
                        model.reloadRistServer()
                    }
            }
            if ristServer.enabled {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Disable the RIST server to change its settings.")
                    }
                }
            }
            Section {
                List {
                    let list = ForEach(ristServer.streams) { stream in
                        RistServerStreamSettingsView(
                            status: model.statusOther,
                            ristServer: ristServer,
                            stream: stream
                        )
                    }
                    if !ristServer.enabled {
                        list.onDelete { indexes in
                            ristServer.streams.remove(atOffsets: indexes)
                            model.reloadRistServer()
                            model.updateMicsListAsync()
                        }
                    } else {
                        list
                    }
                }
                CreateButtonView {
                    let stream = SettingsRistServerStream()
                    stream.name = makeUniqueName(name: SettingsRistServerStream.baseName,
                                                 existingNames: ristServer.streams)
                    ristServer.streams.append(stream)
                    model.updateMicsListAsync()
                }
                .disabled(model.ristServerEnabled())
            } header: {
                Text("Streams")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Each stream can receive video from one RIST publisher.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
        }
        .navigationTitle("RIST server")
    }
}
