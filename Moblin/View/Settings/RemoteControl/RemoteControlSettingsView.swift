import SwiftUI

private struct InterfaceViewUrl: View {
    @EnvironmentObject var model: Model
    var url: String
    var image: String

    var body: some View {
        HStack {
            Image(systemName: image)
            Text(url)
            Spacer()
            Button(action: {
                UIPasteboard.general.string = url
                model.makeToast(title: "URL copied to clipboard")
            }, label: {
                Image(systemName: "doc.on.doc")
            })
        }
    }
}

private struct InterfaceView: View {
    var ip: String
    var port: UInt16
    var image: String

    var body: some View {
        InterfaceViewUrl(url: "ws://\(ip):\(port)", image: image)
    }
}

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

    private func submitStreamerUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        model.database.remoteControl!.server.url = value
        model.reloadRemoteControlStreamer()
    }

    private func submitStreamerPreviewFps(value: Float) {
        model.database.remoteControl!.server.previewFps = value
        model.setLowFpsImage()
    }

    private func formatStreamerPreviewFps(value: Float) -> String {
        return String(Int(value))
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                model.database.remoteControl!.server.enabled
            }, set: { value in
                model.database.remoteControl!.server.enabled = value
                model.reloadRemoteControlStreamer()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "Assistant URL"),
                value: model.database.remoteControl!.server.url,
                onSubmit: submitStreamerUrl,
                footers: [
                    String(
                        localized: "Enter assistant's address and port. For example ws://132.23.43.43:2345."
                    ),
                ],
                keyboardType: .URL,
                placeholder: "ws://32.143.32.12:2345"
            )
            HStack {
                Text("Preview FPS")
                SliderView(
                    value: model.database.remoteControl!.server.previewFps!,
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

    private func submitAssistantPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.remoteControl!.client.port = port
        model.reloadRemoteControlAssistant()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                model.database.remoteControl!.client.enabled
            }, set: { value in
                model.database.remoteControl!.client.enabled = value
                model.reloadRemoteControlAssistant()
                model.objectWillChange.send()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "Server port"),
                value: String(model.database.remoteControl!.client.port),
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

    private func submitAssistantRelayUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        model.database.remoteControl!.client.relay!.baseUrl = value
        model.reloadRemoteControlRelay()
    }

    private func submitAssistantRelayBridgeId(value: String) {
        guard !value.isEmpty else {
            return
        }
        model.database.remoteControl!.client.relay!.bridgeId = value
        model.reloadRemoteControlRelay()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                model.database.remoteControl!.client.relay!.enabled
            }, set: { value in
                model.database.remoteControl!.client.relay!.enabled = value
                model.reloadRemoteControlRelay()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "Base URL"),
                value: model.database.remoteControl!.client.relay!.baseUrl,
                onSubmit: submitAssistantRelayUrl
            )
            TextEditNavigationView(
                title: String(localized: "Bridge id"),
                value: model.database.remoteControl!.client.relay!.bridgeId,
                onSubmit: submitAssistantRelayBridgeId
            )
        } header: {
            Text("Relay")
        } footer: {
            Text("Use a relay server when the assistant is behind CGNAT or similar.")
        }
    }
}

struct RemoteControlSettingsView: View {
    @EnvironmentObject var model: Model

    private func submitPassword(value: String) {
        model.database.remoteControl!.password = value.trim()
        model.reloadRemoteControlStreamer()
        model.reloadRemoteControlAssistant()
    }

    private func relayUrl() -> String {
        let relay = model.database.remoteControl!.client.relay!
        return "\(relay.baseUrl)/streamer/\(relay.bridgeId)"
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
                        model.stream.obsWebSocketEnabled!
                    }, set: {
                        model.setObsRemoteControlEnabled(enabled: $0)
                    })) {
                        IconAndTextView(
                            image: "dot.radiowaves.left.and.right",
                            text: String(localized: "OBS remote control")
                        )
                    }
                }
            } header: {
                Text("Shortcut")
            }
            Section {
                NavigationLink {
                    PasswordView(
                        value: model.database.remoteControl!.password!,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.remoteControl!.password!,
                        sensitive: true
                    )
                }
            } header: {
                Text("General")
            } footer: {
                Text("Used by both streamer and assistant.")
            }
            RemoteControlSettingsStreamerView()
            RemoteControlSettingsAssistantView()
            RemoteControlSettingsRelayView()
            if model.database.remoteControl!.client.enabled {
                Section {
                    List {
                        ForEach(model.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                            InterfaceView(
                                ip: status.ipType.formatAddress(status.ip),
                                port: model.database.remoteControl!.client.port,
                                image: urlImage(interfaceType: status.interfaceType)
                            )
                        }
                        InterfaceView(
                            ip: personalHotspotLocalAddress,
                            port: model.database.remoteControl!.client.port,
                            image: "personalhotspot"
                        )
                        ForEach(model.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                            InterfaceView(
                                ip: status.ipType.formatAddress(status.ip),
                                port: model.database.remoteControl!.client.port,
                                image: urlImage(interfaceType: status.interfaceType)
                            )
                        }
                        if model.database.remoteControl!.client.relay!.enabled {
                            InterfaceViewUrl(url: relayUrl(), image: "globe")
                        }
                    }
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
