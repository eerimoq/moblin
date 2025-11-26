import SwiftUI

private struct InterfaceViewUrl: View {
    @EnvironmentObject var model: Model
    let url: String
    let image: String

    var body: some View {
        HStack {
            Image(systemName: image)
            Text(url)
            Spacer()
            Button {
                UIPasteboard.general.string = url
                model.makeToast(title: "URL copied to clipboard")
            } label: {
                Image(systemName: "doc.on.doc")
            }
        }
    }
}

private struct InterfaceView: View {
    let ip: String
    let port: UInt16
    let image: String

    var body: some View {
        InterfaceViewUrl(url: "ws://\(ip):\(port)", image: image)
    }
}

private struct PasswordView: View {
    @EnvironmentObject var model: Model
    @State var value: String
    let onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false
    @State private var message: String?

    private func isAllowedPassword(password: String) -> Bool {
        return !password.isEmpty
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
            return nil
        } else {
            return "Not long and random enough"
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
                            if changed && !submitted {
                                submit()
                            }
                        }
                        .disabled(model.isLive)
                    Button {
                        UIPasteboard.general.string = value
                        model.makeToast(title: "Password copied to clipboard")
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var model: Model
    @ObservedObject var moblink: Moblink
    @Binding var streamerUrl: String

    private func submitUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        model.database.moblink.relay.url = value
        model.reloadMoblinkRelay()
        dismiss()
    }

    var body: some View {
        Form {
            Section {
                TextField("ws://32.143.32.12:2345", text: $streamerUrl)
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
                        RelayStreamerServerView(server: server, streamerUrl: $streamerUrl, submitUrl: submitUrl)
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
                    RelayStreamerUrlView(moblink: model.moblink, streamerUrl: $relay.url)
                } label: {
                    TextItemView(name: String(localized: "Streamer URL"), value: relay.url)
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
                placeholder: "7777"
            )
            .disabled(model.isLive)
        } header: {
            Text("Streamer")
        } footer: {
            Text("Enable this on your streaming device. Configure relay devices to connect to this device.")
        }
    }
}

private struct UrlsView: View {
    let model: Model
    @ObservedObject var status: StatusOther
    let port: UInt16

    private func formatUrl(ip: String) -> String {
        return "ws://\(ip):\(port)"
    }

    var body: some View {
        NavigationLink {
            Form {
                UrlsIpv4View(model: model, status: status, formatUrl: formatUrl)
                UrlsIpv6View(model: model, status: status, formatUrl: formatUrl)
            }
            .navigationTitle("URLs")
        } label: {
            Text("URLs")
        }
    }
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
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.moblink.password,
                        sensitive: true
                    )
                }
            } footer: {
                Text("Used by both relay and streamer devices. Copy the streamer's password to the relay device.")
            }
            RelayView(relay: model.database.moblink.relay)
            StreamerView(streamer: streamer)
            if streamer.enabled {
                Section {
                    UrlsView(model: model, status: status, port: streamer.port)
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
