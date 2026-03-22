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
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: {
                            guard let latency = Int32($0) else {
                                return String(localized: "Not a number")
                            }
                            guard latency >= 5 else {
                                return String(localized: "Too small")
                            }
                            guard latency <= 10000 else {
                                return String(localized: "Too big")
                            }
                            return nil
                        },
                        onSubmit: {
                            guard let latency = Int32($0) else {
                                return
                            }
                            stream.latency = latency
                            model.reloadRtspClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 2000 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                    .disabled(stream.syncEnabled)
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
                Section {
                    Toggle("Sync", isOn: $stream.syncEnabled)
                } footer: {
                    Text("""
                    Enable to synchronize this stream with other ingests \
                    using H.265 SEI timecodes. When enabled, the latency \
                    setting is not used.
                    """)
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
