import SwiftUI

struct SrtlaServerSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var srtlaServer: SettingsSrtlaServer

    private func submitSrtPort(value: String) {
        guard let port = UInt16(value) else {
            return
        }
        srtlaServer.srtPort = port
        model.reloadSrtlaServer()
    }

    private func submitSrtlaPort(value: String) {
        guard let port = UInt16(value) else {
            return
        }
        srtlaServer.srtlaPort = port
        model.reloadSrtlaServer()
    }

    private func status() -> String {
        if srtlaServer.enabled {
            return String(srtlaServer.streams.count)
        } else {
            return "0"
        }
    }

    private func deleteStream(at indexes: IndexSet) {
        srtlaServer.streams.remove(atOffsets: indexes)
        model.reloadSrtlaServer()
        model.updateMicsListAsync()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Toggle("Enabled", isOn: $srtlaServer.enabled)
                        .onChange(of: srtlaServer.enabled) { _ in
                            model.reloadSrtlaServer()
                        }
                }
                if srtlaServer.enabled {
                    InfoBannerView(text: "Disable the SRT(LA) server to change its settings.")
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "SRT port"),
                        value: String(srtlaServer.srtPort),
                        onChange: isValidPort,
                        onSubmit: submitSrtPort,
                        keyboardType: .numbersAndPunctuation
                    )
                    .disabled(srtlaServer.enabled)
                } footer: {
                    Text("The UDP port the SRT(LA) server listens for SRT publishers on.")
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "SRTLA port"),
                        value: String(srtlaServer.srtlaPort),
                        onChange: isValidPort,
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
                            .contextMenuDeleteButton(disabled: model.srtlaServerEnabled()) {
                                if let index = srtlaServer.streams
                                    .firstIndex(where: { $0.id == stream.id })
                                {
                                    deleteStream(at: IndexSet(integer: index))
                                }
                            }
                        }
                        if !model.srtlaServerEnabled() {
                            list.onDelete(perform: deleteStream)
                        } else {
                            list
                        }
                    }
                    CreateButtonView {
                        let stream = SettingsSrtlaServerStream()
                        stream.name = makeUniqueName(name: SettingsSrtlaServerStream.baseName,
                                                     existingNames: srtlaServer.streams)
                        while true {
                            stream.streamId = randomHumanString()
                            if model.getSrtlaStream(streamId: stream.streamId) == nil {
                                break
                            }
                        }
                        srtlaServer.streams.append(stream)
                        model.updateMicsListAsync()
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
        } label: {
            HStack {
                Text("SRT(LA) server")
                Spacer()
                GrayTextView(text: status())
            }
        }
    }
}
