import SwiftUI

struct WhipServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whipServer: SettingsWhipServer

    private func submitPort(value: String) {
        guard let port = UInt16(value) else {
            return
        }
        whipServer.port = port
        model.reloadWhipServer()
    }

    private func status() -> String {
        if whipServer.enabled {
            return String(whipServer.streams.count)
        } else {
            return "0"
        }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Text("The WHIP server allows Moblin to receive video streams over the network.")
                }
                Section {
                    Toggle("Enabled", isOn: $whipServer.enabled)
                        .onChange(of: whipServer.enabled) { _ in
                            model.reloadWhipServer()
                        }
                }
                if whipServer.enabled {
                    Section {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Disable the WHIP server to change its settings.")
                        }
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Port"),
                        value: String(whipServer.port),
                        onChange: isValidPort,
                        onSubmit: submitPort,
                        keyboardType: .numbersAndPunctuation
                    )
                    .disabled(whipServer.enabled)
                } footer: {
                    Text("The TCP port the WHIP server listens for WHIP streams on.")
                }
                Section {
                    List {
                        let list = ForEach(whipServer.streams) { stream in
                            WhipServerStreamSettingsView(
                                status: model.statusOther,
                                whipServer: whipServer,
                                stream: stream
                            )
                        }
                        if !whipServer.enabled {
                            list.onDelete { indexes in
                                whipServer.streams.remove(atOffsets: indexes)
                                model.reloadWhipServer()
                                model.updateMicsListAsync()
                            }
                        } else {
                            list
                        }
                    }
                    CreateButtonView {
                        let stream = SettingsWhipServerStream()
                        stream.name = makeUniqueName(name: SettingsWhipServerStream.baseName,
                                                     existingNames: whipServer.streams)
                        while true {
                            stream.streamKey = randomHumanString()
                            if model.getWhipStream(streamKey: stream.streamKey) == nil {
                                break
                            }
                        }
                        whipServer.streams.append(stream)
                        model.updateMicsListAsync()
                    }
                    .disabled(whipServer.enabled)
                } header: {
                    Text("Streams")
                } footer: {
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
            .navigationTitle("WHIP server")
        } label: {
            HStack {
                Text("WHIP server")
                Spacer()
                GrayTextView(text: status())
            }
        }
    }
}
