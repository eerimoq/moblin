import SwiftUI

private struct PasswordView: View {
    @EnvironmentObject var model: Model
    @State var value: String
    let onSubmit: (String) -> Void
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
                        .foregroundStyle(.red)
                        .bold()
                }
            }
            Section {
                TextButtonView("Generate") {
                    value = randomGoodPassword()
                    submit()
                }
            }
        }
        .navigationTitle("Password")
    }
}

private struct RemoteControlSettingsStreamerView: View {
    let model: Model
    @ObservedObject var streamer: SettingsRemoteControlStreamer

    private func submitStreamerUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        streamer.url = value
        model.reloadRemoteControlStreamer()
    }

    private func submitStreamerPreviewFps(value: Float) {
        streamer.previewFps = value
        model.setLowFpsImage()
    }

    private func formatStreamerPreviewFps(value: Float) -> String {
        return String(Int(value))
    }

    var body: some View {
        Section {
            Toggle("Enabled", isOn: $streamer.enabled)
                .onChange(of: streamer.enabled) { _ in
                    model.reloadRemoteControlStreamer()
                }
            TextEditNavigationView(
                title: String(localized: "Assistant URL"),
                value: streamer.url,
                onChange: isValidWebSocketUrl,
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
                    value: streamer.previewFps,
                    minimum: 0,
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

private struct UrlsView: View {
    let model: Model
    @ObservedObject var relay: SettingsRemoteControlServerRelay
    @Binding var port: UInt16
    let status: StatusOther

    private func formatUrl(ip: String) -> String {
        return "ws://\(ip):\(port)"
    }

    var body: some View {
        Section {
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

private struct StreamerView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControlSettings: SettingsRemoteControl
    @ObservedObject var remoteControl: RemoteControl
    @ObservedObject var streamer: SettingsRemoteControlAssistant

    private func reloadIfEnabled() {
        guard streamer.id == remoteControlSettings.selectedStreamer else {
            return
        }
        let assistant = model.database.remoteControl.assistant
        assistant.enabled = streamer.enabled
        assistant.port = streamer.port
        assistant.relay.enabled = streamer.relay.enabled
        assistant.relay.baseUrl = streamer.relay.baseUrl
        assistant.relay.bridgeId = streamer.relay.bridgeId
        model.reloadRemoteControlRelay()
        model.reloadRemoteControlAssistant()
    }

    private func submitAssistantPort(value: String) {
        guard let port = UInt16(value) else {
            return
        }
        streamer.port = port
        reloadIfEnabled()
    }

    private func submitAssistantRelayUrl(value: String) {
        streamer.relay.baseUrl = value
        reloadIfEnabled()
    }

    private func changeAssistantRelayBridgeId(value: String) -> String? {
        guard !value.isEmpty else {
            return String(localized: "Empty")
        }
        return nil
    }

    private func submitAssistantRelayBridgeId(value: String) {
        streamer.relay.bridgeId = value
        reloadIfEnabled()
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    NameEditView(name: $streamer.name, existingNames: remoteControlSettings.streamers)
                }
                Section {
                    Toggle("Enabled", isOn: $streamer.enabled)
                        .onChange(of: streamer.enabled) { _ in
                            reloadIfEnabled()
                        }
                    TextEditNavigationView(
                        title: String(localized: "Server port"),
                        value: String(streamer.port),
                        onChange: isValidPort,
                        onSubmit: submitAssistantPort,
                        keyboardType: .numbersAndPunctuation,
                        placeholder: "2345"
                    )
                } header: {
                    Text("Assistant")
                }
                Section {
                    Toggle("Enabled", isOn: $streamer.relay.enabled)
                        .onChange(of: streamer.enabled) { _ in
                            reloadIfEnabled()
                        }
                    TextEditNavigationView(
                        title: String(localized: "Base URL"),
                        value: streamer.relay.baseUrl,
                        onChange: isValidWebSocketUrl,
                        onSubmit: submitAssistantRelayUrl
                    )
                    TextEditNavigationView(
                        title: String(localized: "Bridge id"),
                        value: streamer.relay.bridgeId,
                        onChange: changeAssistantRelayBridgeId,
                        onSubmit: submitAssistantRelayBridgeId,
                        sensitive: true
                    )
                } header: {
                    Text("Relay")
                } footer: {
                    Text("Use a relay server when the assistant is behind CGNAT or similar.")
                }
                if streamer.enabled {
                    UrlsView(model: model,
                             relay: streamer.relay,
                             port: $streamer.port,
                             status: model.statusOther)
                }
            }
            .navigationTitle("Streamer")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(streamer.name)
                Spacer()
            }
        }
    }
}

private struct StreamerItemView: View {
    @ObservedObject var streamer: SettingsRemoteControlAssistant

    var body: some View {
        Text(streamer.name)
            .tag(streamer.id as UUID?)
    }
}

struct RemoteControlStreamersView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var remoteControlSettings: SettingsRemoteControl
    @ObservedObject var remoteControl: RemoteControl

    private func onStreamerChanged() {
        let assistant = model.database.remoteControl.assistant
        if let streamer = remoteControlSettings.streamers
            .first(where: { $0.id == remoteControlSettings.selectedStreamer })
        {
            assistant.enabled = streamer.enabled
            assistant.port = streamer.port
            assistant.relay.enabled = streamer.relay.enabled
            assistant.relay.baseUrl = streamer.relay.baseUrl
            assistant.relay.bridgeId = streamer.relay.bridgeId
        } else {
            assistant.enabled = false
            assistant.relay.enabled = false
        }
        model.reloadRemoteControlRelay()
        model.reloadRemoteControlAssistant()
    }

    var body: some View {
        Section {
            Picker("Current streamer", selection: $remoteControlSettings.selectedStreamer) {
                Text("-- None --")
                    .tag(nil as UUID?)
                ForEach(remoteControlSettings.streamers) { streamer in
                    StreamerItemView(streamer: streamer)
                }
            }
            .onChange(of: remoteControlSettings.selectedStreamer) { _ in
                onStreamerChanged()
            }
        } footer: {
            Text("""
            Select a streamer. Once the streamer has connected to this device, \
            this device can monitor and control it.
            """)
        }
        Section {
            List {
                ForEach(remoteControlSettings.streamers) { streamer in
                    StreamerView(remoteControlSettings: remoteControlSettings,
                                 remoteControl: remoteControl,
                                 streamer: streamer)
                }
                .onDelete {
                    remoteControlSettings.streamers.remove(atOffsets: $0)
                    guard remoteControlSettings.selectedStreamer != nil else {
                        return
                    }
                    guard !remoteControlSettings.streamers
                        .contains(where: { $0.id == remoteControlSettings.selectedStreamer })
                    else {
                        return
                    }
                    remoteControlSettings.selectedStreamer = nil
                    onStreamerChanged()
                }
                .onMove { froms, to in
                    remoteControlSettings.streamers.move(fromOffsets: froms, toOffset: to)
                }
            }
            TextButtonView("Create") {
                let streamer = SettingsRemoteControlAssistant()
                streamer.name = makeUniqueName(name: SettingsRemoteControlAssistant.baseName,
                                               existingNames: remoteControlSettings.streamers)
                streamer.enabled = true
                streamer.port = 2345
                remoteControlSettings.streamers.append(streamer)
            }
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a streamer"))
        }
    }
}

struct RemoteControlSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var status: StatusOther
    @ObservedObject var assistant: SettingsRemoteControlAssistant
    @Binding var stream: SettingsStream

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
            if stream !== fallbackStream {
                Section {
                    NavigationLink {
                        StreamObsRemoteControlSettingsView(stream: stream)
                    } label: {
                        Toggle(isOn: $stream.obsWebSocketEnabled) {
                            Label("OBS remote control", systemImage: "dot.radiowaves.left.and.right")
                        }
                        .onChange(of: stream.obsWebSocketEnabled) { _ in
                            model.obsWebSocketEnabledUpdated()
                        }
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            Section {
                NavigationLink {
                    PasswordView(
                        value: database.remoteControl.password,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: database.remoteControl.password,
                        sensitive: true
                    )
                }
            } header: {
                Text("General")
            } footer: {
                Text("Used by both streamer and assistant.")
            }
            RemoteControlSettingsStreamerView(model: model, streamer: database.remoteControl.streamer)
            Section {
                NavigationLink {
                    Form {
                        RemoteControlStreamersView(remoteControlSettings: database.remoteControl,
                                                   remoteControl: model.remoteControl)
                    }
                    .navigationTitle("Assistant")
                } label: {
                    Text("Assistant")
                }
            }
        }
        .navigationTitle("Remote control")
    }
}
