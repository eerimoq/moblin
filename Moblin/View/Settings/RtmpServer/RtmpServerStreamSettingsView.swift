import Network
import SwiftUI

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

private struct InterfaceView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var streamKey: String
    var image: String
    var ip: String

    private func streamUrl() -> String {
        return rtmpStreamUrl(address: ip, port: port, streamKey: streamKey)
    }

    var body: some View {
        HStack {
            if streamKey.isEmpty {
                Text("Stream key missing")
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
            .disabled(streamKey.isEmpty)
        }
    }
}

struct RtmpServerStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var stream: SettingsRtmpServerStream

    private func submitName(value: String) {
        stream.name = value.trim()
        model.store()
        model.objectWillChange.send()
    }

    private func submitStreamKey(value: String) {
        let streamKey = value.trim()
        if model.getRtmpStream(streamKey: streamKey) != nil {
            return
        }
        stream.streamKey = streamKey
        model.store()
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    func submitLatency(value: String) {
        guard let latency = Int32(value) else {
            return
        }
        guard latency > 0 else {
            return
        }
        stream.latency = latency
        model.store()
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    private func submitFps(value: String) {
        stream.fps = Double(value) ?? 29.97
        model.store()
        model.reloadRtmpServer()
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
                .disabled(model.rtmpServerEnabled())
                TextEditNavigationView(
                    title: String(localized: "Stream key"),
                    value: stream.streamKey,
                    onSubmit: submitStreamKey
                )
                .disabled(model.rtmpServerEnabled())
                TextEditNavigationView(
                    title: String(localized: "Latency"),
                    value: String(stream.latency!),
                    onSubmit: submitLatency,
                    footers: [String(localized: "Zero or more milliseconds.")],
                    keyboardType: .numbersAndPunctuation,
                    valueFormat: { "\($0) ms" }
                )
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
                Toggle("Auto select mic", isOn: Binding(get: {
                    stream.autoSelectMic!
                }, set: { value in
                    stream.autoSelectMic = value
                    model.store()
                    model.reloadRtmpServer()
                    model.objectWillChange.send()
                }))
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("Automatically select the stream's audio as mic when connected.")
            }
            Section {
                Toggle("Manual FPS", isOn: Binding(get: {
                    stream.manualFps!
                }, set: { value in
                    stream.manualFps = value
                    model.store()
                    model.reloadRtmpServer()
                    model.objectWillChange.send()
                }))
                .disabled(model.rtmpServerEnabled())
                if stream.manualFps! {
                    Picker("FPS", selection: Binding(get: {
                        String(stream.fps!)
                    }, set: submitFps)) {
                        ForEach(rtmpServerFpss, id: \.self) { fps in
                            Text(fps)
                        }
                    }
                    .disabled(model.rtmpServerEnabled())
                }
            } footer: {
                Text("""
                Enable manual FPS to force given FPS. This is needed when the publisher \
                does not provide accurate timestamps. B-frames does not work with manual \
                FPS.
                """)
            }
            Section {
                if model.rtmpServerEnabled() {
                    List {
                        ForEach(model.ipStatuses, id: \.name) { status in
                            InterfaceView(
                                port: port,
                                streamKey: stream.streamKey,
                                image: urlImage(interfaceType: status.interfaceType),
                                ip: status.ip
                            )
                        }
                        InterfaceView(
                            port: port,
                            streamKey: stream.streamKey,
                            image: "personalhotspot",
                            ip: personalHotspotLocalAddress
                        )
                    }
                } else {
                    Text("Enable the RTMP server to see URLs.")
                }
            } header: {
                Text("Publish URLs")
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Enter one of the URLs into the RTMP publisher device to send video \
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
