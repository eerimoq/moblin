import SwiftUI

private func isValidWhipClientUrl(_ url: String) -> String? {
    if url.isEmpty {
        return nil
    }
    if url.hasPrefix("whip://") || url.hasPrefix("whips://") {
        return nil
    }
    return String(localized: "Must start with whip:// or whips://")
}

struct WhipClientStreamSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var whipClient: SettingsWhipClient
    @ObservedObject var stream: SettingsWhipClientStream

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $stream.name, existingNames: whipClient.streams)
                }
                Section {
                    TextEditNavigationView(title: String(localized: "URL"),
                                           value: stream.url,
                                           onChange: isValidWhipClientUrl,
                                           onSubmit: {
                                               stream.url = $0
                                               model.reloadWhipClient()
                                           },
                                           footers: [
                                               "whip://1.2.3.4:8888/whip/stream/my-key",
                                               "whips://example.com/whip/stream/my-key",
                                           ],
                                           placeholder: "whip://1.2.3.4:8888/whip/stream/my-key")
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
                            model.reloadWhipClient()
                        },
                        footers: [String(localized: "5 or more milliseconds. 100 ms by default.")],
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
                model.reloadWhipClient()
                model.updateMicsListAsync()
            }
        }
    }
}
