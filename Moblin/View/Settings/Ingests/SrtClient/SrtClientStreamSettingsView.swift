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
                        UrlSettingsView(model: model,
                                        disabled: false,
                                        url: $stream.url,
                                        value: stream.url,
                                        placeholder: "srt://192.168.1.100:4000",
                                        allowedSchemes: ["srt"],
                                        examples: [],
                                        onSubmitted: model.reloadSrtClient)
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: isValidIngestLatency,
                        onSubmit: {
                            guard let latency = Int32($0) else {
                                return
                            }
                            stream.latency = latency
                            model.reloadSrtClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 2000 ms by default.")],
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
                model.reloadSrtClient()
            }
        }
    }
}
