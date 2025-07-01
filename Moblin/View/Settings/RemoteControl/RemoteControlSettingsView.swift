import SwiftUI

private struct PasswordView: View {
    @EnvironmentObject var model: Model
    @State var value: String
    var onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false
    @State private var message: String?

    private func submit() {
        value = value.trim()
        if isGoodPassword(password: value) {
            submitted = true
            onSubmit(value)
        }
    }

    private func createMessage() -> String? {
        if isGoodPassword(password: value) {
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
                        .foregroundColor(.red)
                        .bold()
                }
            }
            Section {
                Button {
                    value = randomGoodPassword()
                    submit()
                } label: {
                    HCenter {
                        Text("Generate")
                    }
                }
            }
        }
        .navigationTitle("Password")
    }
}

private struct RemoteControlSettingsStreamerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func submitStreamerUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        database.remoteControl.server.url = value
        model.reloadRemoteControlStreamer()
    }

    private func submitStreamerPreviewFps(value: Float) {
        database.remoteControl.server.previewFps = value
        model.setLowFpsImage()
    }

    private func formatStreamerPreviewFps(value: Float) -> String {
        return String(Int(value))
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                database.remoteControl.server.enabled
            }, set: { value in
                database.remoteControl.server.enabled = value
                model.reloadRemoteControlStreamer()
                model.objectWillChange.send()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "Assistant URL"),
                value: database.remoteControl.server.url,
                onSubmit: submitStreamerUrl,
                footers: [
                    String(
                        localized: "Enter assistant's address and port. For example ws://132.23.43.43:2345."
                    ),
                ],
                placeholder: "ws://32.143.32.12:2345"
            )
            HStack {
                Text("Preview FPS")
                SliderView(
                    value: database.remoteControl.server.previewFps,
                    minimum: 1,
                    maximum: 5,
                    step: 1,
                    onSubmit: submitStreamerPreviewFps,
                    width: 20,
                    format: formatStreamerPreviewFps
                )
            }
        } header: {
            Text("Streamer")
        } footer: {
            Text("""
            Enable to allow an assistant to monitor and control this device from a \
            different device.
            """)
        }
    }
}

private struct RemoteControlSettingsAssistantView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func submitAssistantPort(value: String) {
        guard let port = UInt16(value.trim()), port > 0 else {
            model.makePortErrorToast(port: value)
            return
        }
        database.remoteControl.client.port = port
        model.reloadRemoteControlAssistant()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                database.remoteControl.client.enabled
            }, set: { value in
                database.remoteControl.client.enabled = value
                model.reloadRemoteControlAssistant()
                model.objectWillChange.send()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "Server port"),
                value: String(database.remoteControl.client.port),
                onSubmit: submitAssistantPort,
                keyboardType: .numbersAndPunctuation,
                placeholder: "2345"
            )
        } header: {
            Text("Assistant")
        } footer: {
            Text("""
            Enable to let a streamer device connect to this device. Once connected, \
            this device can monitor and control the streamer device.
            """)
        }
    }
}

private struct RemoteControlSettingsRelayView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    private func submitAssistantRelayUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        database.remoteControl.client.relay.baseUrl = value
        model.reloadRemoteControlRelay()
    }

    private func submitAssistantRelayBridgeId(value: String) {
        guard !value.isEmpty else {
            return
        }
        database.remoteControl.client.relay.bridgeId = value
        model.reloadRemoteControlRelay()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                database.remoteControl.client.relay.enabled
            }, set: { value in
                database.remoteControl.client.relay.enabled = value
                model.reloadRemoteControlRelay()
                model.objectWillChange.send()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "Base URL"),
                value: database.remoteControl.client.relay.baseUrl,
                onSubmit: submitAssistantRelayUrl
            )
            TextEditNavigationView(
                title: String(localized: "Bridge id"),
                value: database.remoteControl.client.relay.bridgeId,
                onSubmit: submitAssistantRelayBridgeId
            )
        } header: {
            Text("Relay")
        } footer: {
            Text("Use a relay server when the assistant is behind CGNAT or similar.")
        }
    }
}

private struct UrlsView: View {
    let model: Model
    @ObservedObject var relay: SettingsRemoteControlServerRelay
    @Binding var port: UInt16
    let status: StatusOther

    private func formatUrl(ip: String) -> String {
        return "ws://\(ip):\(port)"
    }

    var body: some View {
        NavigationLink {
            Form {
                if relay.enabled {
                    Section {
                        UrlCopyView(model: model,
                                    url: "\(relay.baseUrl)/streamer/\(relay.bridgeId)",
                                    image: "globe")
                    } header: {
                        Text("Relay")
                    }
                }
                UrlsIpv4View(model: model, status: status, formatUrl: formatUrl)
                UrlsIpv6View(model: model, status: status, formatUrl: formatUrl)
            }
            .navigationTitle("URLs")
        } label: {
            Text("URLs")
        }
    }
}

struct RemoteControlSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var status: StatusOther
    @ObservedObject var client: SettingsRemoteControlAssistant

    private func submitPassword(value: String) {
        database.remoteControl.password = value.trim()
        model.reloadRemoteControlStreamer()
        model.reloadRemoteControlAssistant()
    }

    var body: some View {
        Form {
            Section {
                Text("Control and monitor Moblin from another device.")
            }
            Section {
                NavigationLink {
                    StreamObsRemoteControlSettingsView(stream: model.stream)
                } label: {
                    Toggle(isOn: Binding(get: {
                        model.stream.obsWebSocketEnabled
                    }, set: {
                        model.setObsRemoteControlEnabled(enabled: $0)
                    })) {
                        Label("OBS remote control", systemImage: "dot.radiowaves.left.and.right")
                    }
                }
            } header: {
                Text("Shortcut")
            }
            Section {
                NavigationLink {
                    PasswordView(
                        value: database.remoteControl.password!,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: database.remoteControl.password!,
                        sensitive: true
                    )
                }
            } header: {
                Text("General")
            } footer: {
                Text("Used by both streamer and assistant.")
            }
            RemoteControlSettingsStreamerView(database: database)
            RemoteControlSettingsAssistantView(database: database)
            RemoteControlSettingsRelayView(database: database)
            if client.enabled {
                Section {
                    UrlsView(model: model,
                             relay: client.relay,
                             port: $client.port,
                             status: status)
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enter one of the URLs as "Assistant URL" in the streamer device to \
                        connect to this device.
                        """)
                    }
                }
            }
        }
        .navigationTitle("Remote control")
    }
}
