import SwiftUI

struct SrtlaServerSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitSrtPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.srtlaServer!.srtPort = port
        model.store()
        model.reloadSrtlaServer()
    }

    private func submitSrtlaPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.srtlaServer!.srtlaPort = port
        model.store()
        model.reloadSrtlaServer()
    }

    var body: some View {
        Form {
            Section {
                Text("⚠️ Does not yet work.")
            }
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    model.database.srtlaServer!.enabled
                }, set: { value in
                    model.database.srtlaServer!.enabled = value
                    model.store()
                    model.reloadSrtlaServer()
                    model.objectWillChange.send()
                }))
            }
            if model.srtlaServerEnabled() {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Disable the SRT(LA) server to change its settings.")
                    }
                }
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "SRT port"),
                    value: String(model.database.srtlaServer!.srtPort),
                    onSubmit: submitSrtPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(model.srtlaServerEnabled())
            } footer: {
                Text("The UDP port the SRT(LA) server listens for SRT publishers on.")
            }
            Section {
                TextEditNavigationView(
                    title: String(localized: "SRTLA port"),
                    value: String(model.database.srtlaServer!.srtlaPort),
                    onSubmit: submitSrtlaPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(model.srtlaServerEnabled())
            } footer: {
                Text("The UDP port the SRT(LA) server listens for SRTLA publishers on.")
            }
            Section {
                List {
                    let list = ForEach(model.database.srtlaServer!.streams) { stream in
                        NavigationLink(destination: SrtlaServerStreamSettingsView(
                            srtlaPort: model.database.srtlaServer!.srtlaPort,
                            stream: stream
                        )) {
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
                    if !model.srtlaServerEnabled() {
                        list.onDelete(perform: { indexes in
                            model.database.srtlaServer!.streams.remove(atOffsets: indexes)
                            model.store()
                            model.reloadSrtlaServer()
                        })
                    } else {
                        list
                    }
                }
                CreateButtonView(action: {
                    model.database.srtlaServer!.streams.append(SettingsSrtlaServerStream())
                    model.store()
                    model.objectWillChange.send()
                })
                .disabled(model.srtlaServerEnabled())
            } header: {
                Text("Streams")
            } footer: {
                VStack(alignment: .leading) {
                    Text("Each stream can receive video from one SRT(LA) publisher.")
                    Text("")
                    SwipeLeftToDeleteHelpView(kind: String(localized: "a stream"))
                }
            }
        }
        .navigationTitle("SRT(LA) server")
        .toolbar {
            SettingsToolbar()
        }
    }
}
