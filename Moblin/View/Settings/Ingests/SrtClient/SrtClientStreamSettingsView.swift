import SwiftUI

struct SrtClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var srtClient: SettingsSrtClient
    @ObservedObject var stream: SettingsSrtClientStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: srtClient.streams)
                }
                Section {
                    NavigationLink {
                        UrlSettingsView(
                            disabled: false,
                            url: $stream.url,
                            value: stream.url,
                            placeholder: "srt://192.168.1.100:4000",
                            allowedSchemes: ["srt"],
                            examples: [
                                (
                                    "BELABOX cloud",
                                    "srt://eu.srt.belabox.net:4001?streamid=P3Kd229fslEWF3SGRQAsd"
                                ),
                            ],
                            onSubmitted: model.reloadSrtClient
                        )
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: isValidIngestLatency,
                        onSubmit: { value in
                            guard let latency = Int32(value) else { return }
                            stream.latency = latency
                            model.reloadSrtClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 500 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                    CameraProcessingDelayEditView(value: stream.intrinsicDelay) {
                        stream.intrinsicDelay = $0
                        model.reloadSrtClient()
                    }
                }
            }
            .navigationTitle("Stream")
        } label: {
            Toggle(isOn: $stream.enabled) {
                Text(stream.name)
            }
            .onChange(of: stream.enabled) { _ in
                model.reloadSrtClient()
            }
        }
    }
}
