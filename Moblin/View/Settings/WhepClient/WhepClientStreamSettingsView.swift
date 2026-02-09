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
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "URL"),
                        value: stream.url,
                        onSubmit: {
                            stream.url = $0
                            model.reloadWhepClient()
                        },
                        footers: [
                            "https://example.com/whep/myStream",
                            "http://192.168.1.10:8080/whep/myStream",
                        ],
                        placeholder: "https://example.com/whep/myStream"
                    )
                }
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Latency"),
                        value: String(stream.latency),
                        onChange: {
                            guard let latency = Int32($0) else {
                                return String(localized: "Not a number")
                            }
                            guard latency >= 250 else {
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
                model.reloadWhepClient()
            }
        }
    }
}

