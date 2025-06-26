import SwiftUI

struct SrtlaServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func submitSrtPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        database.srtlaServer.srtPort = port
        model.reloadSrtlaServer()
    }

    private func submitSrtlaPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        database.srtlaServer.srtlaPort = port
        model.reloadSrtlaServer()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: Binding(get: {
                    database.srtlaServer.enabled
                }, set: { value in
                    database.srtlaServer.enabled = value
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
                    value: String(database.srtlaServer.srtPort),
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
                    value: String(database.srtlaServer.srtlaPort),
                    onSubmit: submitSrtlaPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(model.srtlaServerEnabled())
            } footer: {
                VStack(alignment: .leading) {
                    Text("The UDP port the SRT(LA) server listens for SRTLA publishers on.")
                    Text("")
                    Text("The UDP port \(database.srtlaServer.srtlaSrtPort()) will also be used.")
                }
            }
            Section {
                List {
                    let list = ForEach(database.srtlaServer.streams) { stream in
                        NavigationLink {
                            SrtlaServerStreamSettingsView(
                                srtlaPort: database.srtlaServer.srtlaPort,
                                stream: stream
                            )
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
                    if !model.srtlaServerEnabled() {
                        list.onDelete { indexes in
                            database.srtlaServer.streams.remove(atOffsets: indexes)
                            model.reloadSrtlaServer()
                        }
                    } else {
                        list
                    }
                }
                CreateButtonView {
                    let stream = SettingsSrtlaServerStream()
                    while true {
                        stream.streamId = randomHumanString()
                        if model.getSrtlaStream(streamId: stream.streamId) == nil {
                            break
                        }
                    }
                    database.srtlaServer.streams.append(stream)
                    model.objectWillChange.send()
                }
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
    }
}
