import SwiftUI

struct WhepClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whepClient: SettingsWhepClient
    @ObservedObject var stream: SettingsWhepClientStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: whepClient.streams)
                        .disabled(stream.enabled)
                }
                Section {
                    NavigationLink {
                        UrlSettingsView(model: model,
                                        disabled: stream.enabled,
                                        url: $stream.url,
                                        value: stream.url,
                                        placeholder: "http://foo.com/whep",
                                        allowedSchemes: ["http", "https"],
                                        examples: [],
                                        onSubmitted: model.reloadWhepClient)
                    } label: {
                        TextItemLocalizedView(name: "URL", value: stream.url, sensitive: true)
                    }
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
                            model.reloadWhepClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 100 ms by default.")],
                        keyboardType: .numbersAndPunctuation,
                        valueFormat: { "\($0) ms" }
                    )
                    .disabled(stream.enabled)
                } footer: {
                    Text("The higher, the lower risk of stuttering.")
                }
                Section {
                    Toggle("Sync timestamps", isOn: $stream.syncTimestamps)
                        .onChange(of: stream.syncTimestamps) { _ in
                            model.reloadWhepClient()
                        }
                        .disabled(stream.enabled)
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
                model.reloadWhepClient()
            }
        }
    }
}
