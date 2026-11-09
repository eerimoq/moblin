import SwiftUI

private struct PasswordView: View {
    @EnvironmentObject var model: Model
    @State var value: String
    let onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false
    @State private var message: String?

    private func isAllowedPassword(password: String) -> Bool {
        !password.isEmpty
    }

    private func submit() {
        value = value.trim()
        if isAllowedPassword(password: value) {
            submitted = true
            onSubmit(value)
        }
    }

    private func createMessage() -> String? {
        if isAllowedPassword(password: value) {
            nil
        } else {
            "Not long and random enough"
        }
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("", text: $value)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .onChange(of: value) { _ in
                            changed = true
                            message = createMessage()
                        }
                        .onSubmit {
                            submit()
                        }
                        .submitLabel(.done)
                        .onDisappear {
                            if changed, !submitted {
                                submit()
                            }
                        }
                        .disabled(model.isLive)
                    CopyToClipboardButtonView(text: value)
                }
            } footer: {
                if let message {
                    Text(message)
                        .foregroundStyle(.red)
                        .bold()
                }
            }
            Section {
                TextButtonView("Reset to default") {
                    value = "1234"
                    submit()
                }
                .disabled(model.isLive)
            }
        }
        .navigationTitle("Password")
    }
}

private struct RelayStreamerServerView: View {
    let server: MoblinkScannerStreamer
    @Binding var streamerUrl: String
    let submitUrl: (String) -> Void

    var body: some View {
        Section {
            List {
                ForEach(server.urls, id: \.self) { url in
                    Button {
                        streamerUrl = url
                        submitUrl(streamerUrl)
                    } label: {
                        Text(url)
                    }
                }
            }
        } header: {
            Text(server.name)
        }
    }
}

private struct RelayStreamerUrlView: View {
    let model: Model
    @Environment(\.dismiss) var dismiss
    @ObservedObject var moblink: Moblink
    @State var streamerUrl: String

    private func submitUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            streamerUrl = model.database.moblink.relay.url
            return
        }
        model.database.moblink.relay.url = value
        model.reloadMoblinkRelay()
        dismiss()
    }

    var body: some View {
        Form {
            Section {
                TextField(
                    String("ws://32.143.32.12:\(DefaultTcpPorts.remoteControlAssistant)"),
                    text: $streamerUrl
                )
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .submitLabel(.done)
                .onSubmit {
                    submitUrl(value: streamerUrl)
                }
            }
            if moblink.scannerDiscoveredStreamers.isEmpty {
                Text("No streamers discovered yet on your local network.")
            } else {
                List {
                    ForEach(moblink.scannerDiscoveredStreamers) { server in
                        RelayStreamerServerView(
                            server: server,
                            streamerUrl: $streamerUrl,
                            submitUrl: submitUrl
                        )
                    }
                }
            }
        }
        .navigationTitle("Streamer URL")
    }
}

private struct RelayView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var relay: SettingsMoblinkRelay
    @State var relayId = ""

    var body: some View {
        Section {
            Toggle("Enabled", isOn: $relay.enabled)
                .onChange(of: relay.enabled) { _ in
                    model.reloadMoblinkRelay()
                }
            NameEditView(name: $relay.name)
                .onChange(of: relay.name) { _ in
                    model.reloadMoblinkRelay()
                }
            Toggle(isOn: $relay.manual) {
                Text("Manual")
            }
            .onChange(of: relay.manual) { _ in
                model.reloadMoblinkRelay()
            }
            .disabled(model.isLive)
            if relay.manual {
                NavigationLink {
                    RelayStreamerUrlView(model: model, moblink: model.moblink, streamerUrl: relay.url)
                } label: {
                    TextItemLocalizedView(name: "Streamer URL", value: relay.url)
                }
            }
            TextButtonView("Reset id") {
                moblinkRelayResetId()
                model.reloadMoblinkRelay()
                relayId = getMoblinkRelayId()
            }
        } header: {
            Text("Relay")
        } footer: {
            VStack(alignment: .leading) {
                Text("""
                Enable this on the device you want to use as the extra bonding connection. The device \
                must have cellular data enabled.
                """)
                Text("")
                Text("ID: \(relayId)")
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .onAppear {
            relayId = getMoblinkRelayId()
        }
    }
}

private struct StreamerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var streamer: SettingsMoblinkStreamer

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            model.makePortErrorToast(port: value)
            return
        }
        streamer.port = port
        model.reloadMoblinkStreamer()
    }

    var body: some View {
        Section {
            Toggle(isOn: $streamer.enabled) {
                Text("Enabled")
            }
            .onChange(of: streamer.enabled) { _ in
                model.reloadMoblinkStreamer()
            }
            .disabled(model.isLive)
            TextEditNavigationView(
                title: String(localized: "Server port"),
                value: String(streamer.port),
                onChange: isValidPort,
                onSubmit: submitPort,
                keyboardType: .numbersAndPunctuation,
                placeholder: String(DefaultTcpPorts.moblinkStreamer)
            )
            .disabled(model.isLive)
        } header: {
            Text("Streamer")
        } footer: {
            Text("Enable this on your streaming device. Configure relay devices to connect to this device.")
        }
    }
}

private func drawMoblinkCard(context: GraphicsContext, time: Double) {
    let blue = Color(red: 0x2F / 255, green: 0x7C / 255, blue: 0xF6 / 255)
    var serverPath = Path()
    serverPath.move(to: CGPoint(x: 44, y: 54))
    serverPath.addCurve(to: CGPoint(x: 116, y: 26),
                        control1: CGPoint(x: 44, y: 34),
                        control2: CGPoint(x: 100, y: 38))
    serverPath.move(to: CGPoint(x: 130, y: 66))
    serverPath.addLine(to: CGPoint(x: 130, y: 26))
    serverPath.move(to: CGPoint(x: 216, y: 54))
    serverPath.addCurve(to: CGPoint(x: 144, y: 26),
                        control1: CGPoint(x: 216, y: 34),
                        control2: CGPoint(x: 160, y: 38))
    strokeTradingCardDash(context: context,
                          path: serverPath,
                          color: blue,
                          lineWidth: 2,
                          dash: 4,
                          gap: 4,
                          time: time)
    var hotspotPath = Path()
    hotspotPath.move(to: CGPoint(x: 80, y: 90))
    hotspotPath.addLine(to: CGPoint(x: 64, y: 90))
    strokeTradingCardDash(context: context,
                          path: hotspotPath,
                          color: Color(red: 0x0D / 255, green: 0x7A / 255, blue: 0x30 / 255),
                          lineWidth: 2.5,
                          dash: 4,
                          gap: 4,
                          time: time)
    var moblinkPath = Path()
    moblinkPath.move(to: CGPoint(x: 180, y: 90))
    moblinkPath.addLine(to: CGPoint(x: 196, y: 90))
    strokeTradingCardDash(context: context,
                          path: moblinkPath,
                          color: blue,
                          lineWidth: 2.5,
                          dash: 4,
                          gap: 4,
                          time: time)
    context.fill(Path(ellipseIn: CGRect(x: 144 - 1.6, y: 21 - 1.6, width: 3.2, height: 3.2)),
                 with: .color(Color(red: 0x4C / 255, green: 0xD9 / 255, blue: 0x64 / 255)
                     .opacity(tradingCardPulseOpacity(time: time))))
}

struct MoblinkSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: StatusOther
    @ObservedObject var streamer: SettingsMoblinkStreamer

    private func submitPassword(value: String) {
        model.database.moblink.password = value.trim()
        model.reloadMoblinkRelay()
        model.reloadMoblinkStreamer()
    }

    var body: some View {
        Form {
            Section {
                TradingCardView(name: "Moblink",
                                background: Color(red: 0xE0 / 255, green: 0xE4 / 255, blue: 0xEC / 255),
                                draw: drawMoblinkCard)
            }
            Section {
                Text("""
                Use phones as additional SRTLA and RIST bonding connections. Install Moblink on Android \
                phones to use them.
                """)
            }
            Section {
                NavigationLink {
                    PasswordView(
                        value: model.database.moblink.password,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemLocalizedView(
                        name: "Password",
                        value: model.database.moblink.password,
                        sensitive: true
                    )
                }
            } footer: {
                Text(
                    "Used by both relay and streamer devices. Copy the streamer's password to the relay device."
                )
            }
            RelayView(relay: model.database.moblink.relay)
            StreamerView(streamer: streamer)
            if streamer.enabled {
                Section {
                    UrlsView(status: status,
                             formatUrl: { "ws://\($0):\(streamer.port)" })
                } footer: {
                    Text("""
                    Enter one of the URL:s as "Streamer URL" in the relay device to \
                    use it as an additional bonding connection.
                    """)
                }
            }
        }
        .navigationTitle("Moblink")
    }
}
