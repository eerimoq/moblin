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
