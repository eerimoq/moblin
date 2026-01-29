import SwiftUI

private struct PasswordView: View {
    @State var value: String
    let onSubmit: (String) -> Void
    @State private var changed = false
    @State private var submitted = false
    @Environment(\.dismiss) private var dismiss

    private func submit() {
        value = value.trim()
        submitted = true
        onSubmit(value)
        dismiss()
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
                    CopyToClipboardButtonView(text: value)
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
        model.reloadConnections()
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
                    model.reloadConnections()
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
        } footer: {
            Text("""
            Enable to allow an assistant to monitor and control this device from a \
            different device.
            """)
        }
        Section {
            Toggle("Reliable chat and events", isOn: $streamer.reliableChatAndEvents)
                .onChange(of: streamer.reliableChatAndEvents) { _ in
                    model.reloadRemoteControlStreamer()
                    model.reloadConnections()
                }
        } footer: {
            VStack(alignment: .leading) {
                Text("""
                Receive chat and events from the assistant instead of directly from the streaming platform.
                """)
                Text("")
                Text("Only works for Twitch.")
            }
        }
        Section {
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
        }
    }
}

private struct UrlsView: View {
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
                            UrlCopyView(url: "\(relay.baseUrl)/streamer/\(relay.bridgeId)",
                                        image: "globe")
                        } header: {
                            Text("Relay")
                        }
                    }
                    UrlsIpv4View(status: status, formatUrl: formatUrl)
                    UrlsIpv6View(status: status, formatUrl: formatUrl)
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
                    UrlsView(relay: streamer.relay,
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
    let model: Model
    @ObservedObject var remoteControlSettings: SettingsRemoteControl

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
                    StreamerView(remoteControlSettings: remoteControlSettings, streamer: streamer)
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

private func formatUrl(ip: String, port: UInt16) -> String {
    if port == 80 {
        return "http://\(ip)"
    } else {
        return "http://\(ip):\(port)"
    }
}

private struct WebUrlsView: View {
    @ObservedObject var web: SettingsRemoteControlWeb
    @ObservedObject var status: StatusOther

    private func format(ip: String) -> String {
        return formatUrl(ip: ip, port: web.port)
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    TextField("My device name", text: $web.deviceName)
                    if !web.deviceName.isEmpty {
                        UrlCopyView(
                            url: format(ip: makeMdnsHostname(deviceName: web.deviceName)),
                            image: "network"
                        )
                    }
                } header: {
                    Text("mDNS")
                } footer: {
                    Text("Copy your device name from iOS settings.")
                }
                UrlsIpv4View(status: status, formatUrl: format)
                UrlsIpv6View(status: status, formatUrl: format)
            }
            .navigationTitle("URLs")
        } label: {
            Text("URLs")
        }
    }
}

struct RemoteControlWebDefaultUrlView: View {
    @ObservedObject var web: SettingsRemoteControlWeb
    @ObservedObject var status: StatusOther
    let path: String

    private func format(ip: String) -> String {
        return formatUrl(ip: ip, port: web.port)
    }

    var body: some View {
        if !web.deviceName.isEmpty {
            UrlCopyView(
                url: format(ip: makeMdnsHostname(deviceName: web.deviceName)) + path,
                image: "network"
            )
        } else if let status = status.ipStatuses
            .first(where: {
                $0.ipType == .ipv4 && ($0.interfaceType == .wifi || $0.interfaceType == .wiredEthernet)
            })
        {
            UrlCopyView(
                url: format(ip: status.ipType.formatAddress(status.ip)),
                image: urlImage(interfaceType: status.interfaceType)
            )
        }
    }
}

struct RemoteControlSettingsWebView: View {
    let model: Model
    @ObservedObject var web: SettingsRemoteControlWeb

    private func submitPort(value: String) {
        guard let port = UInt16(value), port < UInt16.max else {
            return
        }
        web.port = port
        model.reloadRemoteControlWeb()
    }

    var body: some View {
        Section {
            Toggle("Enabled", isOn: $web.enabled)
                .onChange(of: web.enabled) { _ in
                    model.reloadRemoteControlWeb()
                }
        } footer: {
            Text("""
            Enable to monitor and control this device from another device using a web \
            browser. There is no authentication, nor encryption, so be careful.
            """)
        }
        Section {
            TextEditNavigationView(
                title: String(localized: "Server port"),
                value: String(web.port),
                onChange: isValidPort,
                onSubmit: submitPort,
                keyboardType: .numbersAndPunctuation,
                placeholder: "80"
            )
            .disabled(web.enabled)
        }
        if web.enabled {
            WebUrlsView(web: web, status: model.statusOther)
        }
    }
}

struct RemoteControlSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
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
            Section {
                NavigationLink {
                    PasswordView(
                        value: database.remoteControl.password,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemLocalizedView(
                        name: "Password",
                        value: database.remoteControl.password,
                        sensitive: true
                    )
                }
            } header: {
                Text("General")
            } footer: {
                Text("Used by both streamer and assistant.")
            }
            Section {
                NavigationLink {
                    Form {
                        RemoteControlSettingsStreamerView(
                            model: model,
                            streamer: database.remoteControl.streamer
                        )
                    }
                    .navigationTitle("Streamer")
                } label: {
                    Text("Streamer")
                }
                NavigationLink {
                    Form {
                        RemoteControlStreamersView(
                            model: model,
                            remoteControlSettings: database.remoteControl
                        )
                        Section {
                            ExternalUrlButtonView(
                                url: "https://moblin.mys-lang.org/moblin-remote-control-relay/assistant.html"
                            ) {
                                Text(String("Moblin Remote Control Assistant"))
                            }
                            ExternalUrlButtonView(url: "https://moblinremote.com/") {
                                Text(String("Moblin Remote Control"))
                            }
                        } header: {
                            Text("Websites")
                        } footer: {
                            Text("Alternatively, use a website as assistant.")
                        }
                    }
                    .navigationTitle("Assistant")
                } label: {
                    Text("Assistant")
                }
            }
            Section {
                NavigationLink {
                    Form {
                        RemoteControlSettingsWebView(
                            model: model,
                            web: database.remoteControl.web
                        )
                    }
                    .navigationTitle("Web")
                } label: {
                    Text("Web")
                }
            }
            if stream !== fallbackStream {
                ShortcutSectionView {
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
                }
            }
        }
        .navigationTitle("Remote control")
    }
}
