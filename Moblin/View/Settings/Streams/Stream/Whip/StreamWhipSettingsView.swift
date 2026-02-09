import SwiftUI

struct StreamWhipSettingsView: View {
    @EnvironmentObject var model: Model
    let stream: SettingsStream

    private func iceServersString() -> String {
        stream.whip.iceServers.joined(separator: "\n")
    }

    private func parseIceServers(_ value: String) -> [String] {
        value
            .split(whereSeparator: { $0 == "\n" || $0 == "," })
            .map { String($0).trim() }
            .filter { !$0.isEmpty }
    }

    var body: some View {
        Form {
            Section {
                MultiLineTextFieldNavigationView(
                    title: String(localized: "ICE servers"),
                    value: iceServersString(),
                    onSubmit: { value in
                        stream.whip.iceServers = parseIceServers(value)
                        model.reloadStreamIfEnabled(stream: stream)
                    },
                    footers: [
                        String(localized: "Enter STUN/TURN URLs, one per line."),
                        String(localized: "Example: stun:stun.l.google.com:19302"),
                        String(localized: "Note: Custom ICE servers may be ignored depending on WHIP backend."),
                    ]
                )

                NavigationLink {
                    TextEditView(
                        title: String(localized: "Max retries"),
                        value: String(stream.whip.maxRetryCount),
                        keyboardType: .numberPad
                    ) { value in
                        guard let retry = Int(value), retry >= 0, retry <= 20 else {
                            return
                        }
                        stream.whip.maxRetryCount = retry
                        model.reloadStreamIfEnabled(stream: stream)
                    }
                } label: {
                    TextItemView(
                        name: String(localized: "Max retries"),
                        value: String(stream.whip.maxRetryCount),
                        color: .gray
                    )
                }
                .disabled(stream.enabled && model.isLive)
            }
        }
        .navigationTitle("WHIP")
    }
}

