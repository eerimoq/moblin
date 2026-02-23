import SwiftUI

struct StreamWhipSettingsView: View {
    let model: Model
    let stream: SettingsStream
    @ObservedObject var whip: SettingsStreamWhip

    private func getBearerToken() -> String {
        guard let authorization = whip.headers.first(where: { $0.name == "Authorization" }) else {
            return ""
        }
        guard let match = authorization.value.prefixMatch(of: /Bearer (.*)/) else {
            return ""
        }
        return String(match.output.1)
    }

    private func setBearerToken(token: String) {
        let value = "Bearer \(token)"
        if let index = whip.headers.firstIndex(where: { $0.name == "Authorization" }) {
            whip.headers[index].value = value
        } else {
            whip.headers.append(SettingsHttpHeader(name: "Authorization", value: value))
        }
        model.reloadStreamIfEnabled(stream: stream)
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(title: String(localized: "Bearer token"),
                                       value: getBearerToken(),
                                       onSubmit: setBearerToken,
                                       sensitive: true)
                    .disabled(stream.enabled && model.isLive)
            }
            Section {
                Picker(selection: $whip.httpTransport) {
                    ForEach(SettingsStreamWhipHttpTransport.allCases, id: \.self) {
                        Text($0.toString())
                    }
                } label: {
                    Text("HTTP transport")
                }
                .disabled(stream.enabled && model.isLive)
                .onChange(of: whip.httpTransport) { _ in
                    model.reloadStreamIfEnabled(stream: stream)
                }
            } footer: {
                VStack(alignment: .leading) {
                    Text("Select \(SettingsStreamWhipHttpTransport.standard.toString()) to use standard WHIP.")
                    Text("")
                    Text("""
                         Select \(SettingsStreamWhipHttpTransport.remoteControl.toString()) to exchange \
                         connection establishment information via the remote control. Configure this device \
                         as remote control assistant, and the device you are streaming to as remote control \
                         streamer.
                         """)
                }
            }
        }
        .navigationTitle("WHIP")
    }
}
