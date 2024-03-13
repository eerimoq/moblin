import Network
import SwiftUI

private struct InterfaceView: View {
    @EnvironmentObject var model: Model
    var port: UInt16
    var streamKey: String
    var image: String
    var ip: String

    private func streamUrl(address: String) -> String {
        return rtmpStreamUrl(address: address, port: port, streamKey: streamKey)
    }

    var body: some View {
        HStack {
            if streamKey.isEmpty {
                Text("Stream key missing")
            } else {
                Image(systemName: image)
                Text(streamUrl(address: ip))
            }
            Spacer()
            Button(action: {
                UIPasteboard.general.string = streamUrl(address: ip)
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
        guard latency >= 0 else {
            return
        }
        stream.latency = latency
        model.store()
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    func submitFps(value: String) {
        guard let fps = Double(value) else {
            return
        }
        guard fps >= 0 && fps <= 1000 else {
            return
        }
        stream.fps = fps
        model.store()
        model.reloadRtmpServer()
        model.objectWillChange.send()
    }

    private func urlImage(interfaceType: NWInterface.InterfaceType) -> String {
        switch interfaceType {
        case .other:
            return "questionmark"
        case .wifi:
            return "wifi"
        case .cellular:
            return "antenna.radiowaves.left.and.right"
        case .wiredEthernet:
            return "cable.connector"
        case .loopback:
            return "questionmark"
        @unknown default:
            return "questionmark"
        }
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
                    footer: Text("Zero or more milliseconds."),
                    valueFormat: { "\($0) ms" }
                )
                .disabled(model.rtmpServerEnabled())
                TextEditNavigationView(
                    title: String(localized: "FPS"),
                    value: String(stream.fps!),
                    onSubmit: submitFps,
                    footer: Text("""
                    Force given FPS, or set to 0 to use the publisher's FPS. B-frames \
                    does not work with forced FPS. Forced FPS is typically needed for DJI drones.
                    """)
                )
                .disabled(model.rtmpServerEnabled())
            } footer: {
                Text("The stream name is shown in the list of cameras in scene settings.")
            }
            Section {
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
                        ip: "172.20.10.1"
                    )
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
