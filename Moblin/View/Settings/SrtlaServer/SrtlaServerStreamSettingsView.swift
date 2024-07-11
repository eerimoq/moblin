import Network
import SwiftUI

private func srtlaStreamUrl(address: String, srtlaPort: UInt16, streamId: String) -> String {
    return "srtla://\(address):\(srtlaPort)?streamid=\(streamId)"
}

private struct InterfaceView: View {
    @EnvironmentObject var model: Model
    var srtlaPort: UInt16
    var streamId: String
    var image: String
    var ip: String

    private func streamUrl() -> String {
        return srtlaStreamUrl(address: ip, srtlaPort: srtlaPort, streamId: streamId)
    }

    var body: some View {
        HStack {
            if streamId.isEmpty {
                Text("Stream id missing")
            } else {
                Image(systemName: image)
                Text(streamUrl())
            }
            Spacer()
            Button(action: {
                UIPasteboard.general.string = streamUrl()
                model.makeToast(title: "URL copied to clipboard")
            }, label: {
                Image(systemName: "doc.on.doc")
            })
            .disabled(streamId.isEmpty)
        }
    }
}

struct SrtlaServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var srtlaPort: UInt16
    var stream: SettingsSrtlaServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.store()
        model.objectWillChange.send()
    }

    private func submitStreamId(value: String) {
        let streamId = value.trim()
        guard streamId.wholeMatch(of: /[a-z]*/) != nil else {
            return
        }
        if model.getSrtlaStream(streamId: streamId) != nil {
            return
        }
        stream.streamId = streamId
        model.store()
        model.reloadSrtlaServer()
        model.objectWillChange.send()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Name"),
                    value: stream.name,
                    onSubmit: submitName,
                    capitalize: true
                )
                .disabled(model.srtlaServerEnabled())
                TextEditNavigationView(
                    title: String(localized: "Stream id"),
                    value: stream.streamId,
                    onSubmit: submitStreamId,
                    footers: [String(localized: "May only contain lower case letters.")]
                )
                .disabled(model.srtlaServerEnabled())
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
                Toggle("Auto select mic", isOn: Binding(get: {
                    stream.autoSelectMic!
                }, set: { value in
                    stream.autoSelectMic = value
                    model.store()
                    model.reloadSrtlaServer()
                    model.objectWillChange.send()
                }))
                .disabled(model.srtlaServerEnabled())
            } footer: {
                Text("Automatically select the stream's audio as mic when connected.")
            }
            Section {
                if model.srtlaServerEnabled() {
                    List {
                        ForEach(model.ipStatuses, id: \.name) { status in
                            InterfaceView(
                                srtlaPort: srtlaPort,
                                streamId: stream.streamId,
                                image: urlImage(interfaceType: status.interfaceType),
                                ip: status.ip
                            )
                        }
                        InterfaceView(
                            srtlaPort: srtlaPort,
                            streamId: stream.streamId,
                            image: "personalhotspot",
                            ip: personalHotspotLocalAddress
                        )
                    }
                } else {
                    Text("Enable the SRT(LA) server to see URLs.")
                }
            } header: {
                Text("Publish URLs")
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Enter one of the URLs into the SRT(LA) publisher device to send video \
                    to this stream. Usually enter the WiFi or Personal Hotspot URL.
                    """)
                }
            }
        }
        .navigationTitle("Stream")
        .toolbar {
            SettingsToolbar()
        }
    }
}
