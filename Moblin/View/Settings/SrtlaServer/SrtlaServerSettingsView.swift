import SwiftUI

struct SrtlaServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var srtlaServer: SettingsSrtlaServer

    private func submitSrtPort(value: String) {
        guard let port = UInt16(value.trim()), port > 0 else {
            srtlaServer.srtPortString = String(srtlaServer.srtPort)
            model.makePortErrorToast(port: value)
            return
        }
        srtlaServer.srtPort = port
        model.reloadSrtlaServer()
    }

    private func submitSrtlaPort(value: String) {
        guard let port = UInt16(value.trim()), port > 0 else {
            srtlaServer.srtlaPortString = String(srtlaServer.srtlaPort)
            model.makePortErrorToast(port: value)
            return
        }
        srtlaServer.srtlaPort = port
        model.reloadSrtlaServer()
    }

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $srtlaServer.enabled)
                    .onChange(of: srtlaServer.enabled) { _ in
                        model.reloadSrtlaServer()
                    }
            }
            if srtlaServer.enabled {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Disable the SRT(LA) server to change its settings.")
                    }
                }
            }
            Section {
                TextEditBindingNavigationView(
                    title: String(localized: "SRT port"),
                    value: $srtlaServer.srtPortString,
                    onSubmit: submitSrtPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(srtlaServer.enabled)
            } footer: {
                Text("The UDP port the SRT(LA) server listens for SRT publishers on.")
            }
            Section {
                TextEditBindingNavigationView(
                    title: String(localized: "SRTLA port"),
                    value: $srtlaServer.srtlaPortString,
                    onSubmit: submitSrtlaPort,
                    keyboardType: .numbersAndPunctuation
                )
                .disabled(srtlaServer.enabled)
            } footer: {
                VStack(alignment: .leading) {
                    Text("The UDP port the SRT(LA) server listens for SRTLA publishers on.")
                    Text("")
                    Text("The UDP port \(srtlaServer.srtlaSrtPort()) will also be used.")
                }
            }
            Section {
                List {
                    let list = ForEach(srtlaServer.streams) { stream in
                        SrtlaServerStreamSettingsView(
                            status: model.statusOther,
                            srtlaServer: srtlaServer,
                            stream: stream
                        )
                    }
                    if !model.srtlaServerEnabled() {
                        list.onDelete { indexes in
                            srtlaServer.streams.remove(atOffsets: indexes)
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
                    srtlaServer.streams.append(stream)
                }
                .disabled(srtlaServer.enabled)
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
