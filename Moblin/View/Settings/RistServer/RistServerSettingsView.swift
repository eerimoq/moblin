import SwiftUI

struct RistServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var ristServer: SettingsRistServer

    private func submitPort(value: String) {
        guard let port = UInt16(value) else {
            return
        }
        ristServer.port = port
        model.reloadRistServer()
    }

    private func status() -> String {
        if ristServer.enabled {
            return String(ristServer.streams.count)
        } else {
            return "0"
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Text("The RIST server allows Moblin to receive video streams over the network.")
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
                                .foregroundStyle(.blue)
                            Text("Disable the RIST server to change its settings.")
                        }
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Port"),
                        value: String(ristServer.port),
                        onChange: isValidPort,
                        onSubmit: submitPort,
                        keyboardType: .numbersAndPunctuation
                    )
                    .disabled(ristServer.enabled)
                } footer: {
                    Text("The UDP port the RIST server listens for RIST publishers on.")
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
                        stream.virtualDestinationPort = ristServer.makeUniqueVirtualDestinationPort()
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
        } label: {
            HStack {
                Text("RIST server")
                Spacer()
                Text(status())
                    .foregroundStyle(.gray)
            }
        }
    }
}
