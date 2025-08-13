import Network
import SwiftUI

struct RtspClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var rtspClient: SettingsRtspClient
    @ObservedObject var stream: SettingsRtspClientStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: rtspClient.streams)
                }
                Section {
                    TextEditNavigationView(title: String(localized: "URL"),
                                           value: stream.url,
                                           onSubmit: {
                                               stream.url = $0
                                               model.reloadRtspClient()
                                           },
                                           footers: [
                                               "rtsp://1.2.3.4:554/stream",
                                               "rtsp://username:password@1.2.3.4/stream",
                                           ],
                                           placeholder: "rtsp://foo:bar@1.2.3.4/stream")
                }
                Section {
                    TextEditBindingNavigationView(
                        title: String(localized: "Latency"),
                        value: $stream.latencyString,
                        onSubmit: {
                            guard let latency = Int32($0) else {
                                stream.latencyString = String(stream.latency)
                                return
                            }
                            stream.latency = latency.clamped(to: 250 ... 10000)
                            stream.latencyString = String(stream.latency)
                            model.reloadRtspClient()
                        },
                        footers: [String(localized: "250 or more milliseconds. 2000 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
            }
            .navigationTitle("Stream")
        } label: {
            Toggle(isOn: $stream.enabled) {
                HStack {
                    Text(stream.name)
                }
            }
            .onChange(of: stream.enabled) { _ in
                model.reloadRtspClient()
            }
        }
    }
}
