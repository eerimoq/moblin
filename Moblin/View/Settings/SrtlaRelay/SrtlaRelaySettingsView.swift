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
                        .foregroundColor(.red)
                        .bold()
                }
            }
            Section {
                Button {
                    value = "1234"
                    submit()
                } label: {
                    HCenter {
                        Text("Reset to default")
                    }
                }
                .disabled(model.isLive)
            }
        }
        .navigationTitle("Password")
    }
}

private struct RelayUrlsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            List {
                ForEach(model.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                    InterfaceView(
                        ip: status.ipType.formatAddress(status.ip),
                        port: model.database.srtlaRelay!.server.port,
                        image: urlImage(interfaceType: status.interfaceType)
                    )
                }
                InterfaceView(
                    ip: personalHotspotLocalAddress,
                    port: model.database.srtlaRelay!.server.port,
                    image: "personalhotspot"
                )
                ForEach(model.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                    InterfaceView(
                        ip: status.ipType.formatAddress(status.ip),
                        port: model.database.srtlaRelay!.server.port,
                        image: urlImage(interfaceType: status.interfaceType)
                    )
                }
            }
        } footer: {
            VStack(alignment: .leading) {
                Text("""
                Enter one of the URL:s as "Streamer URL" in the relay device to \
                use it as an additional bonding connection.
                """)
            }
        }
    }
}

private struct RelayView: View {
    @EnvironmentObject var model: Model
    @State var enabled: Bool
    @State var name: String
    @State var port: UInt16
    @State var password: String

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.srtlaRelay!.server.port = port
        model.reloadSrtlaRelayRelay()
    }

    private func submitPassword(value: String) {
        model.database.srtlaRelay!.server.password = value.trim()
        model.reloadSrtlaRelayRelay()
    }

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enabled) {
                    Text("Enabled")
                }
                .onChange(of: enabled) { value in
                    model.database.srtlaRelay!.server.enabled = value
                    model.reloadSrtlaRelayRelay()
                }
            } footer: {
                Text("""
                Enable this on the device you want to use as the extra bonding connection. The device \
                must have cellular data enabled.
                """)
            }
            Section {
                NavigationLink {
                    NameEditView(name: $name)
                } label: {
                    TextItemView(name: String(localized: "Name"), value: name)
                }
                .onChange(of: name) { name in
                    model.database.srtlaRelay!.server.name = name
                    model.reloadSrtlaRelayRelay()
                }
                NavigationLink {
                    PasswordView(
                        value: model.database.srtlaRelay!.server.password!,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.srtlaRelay!.server.password!,
                        sensitive: true
                    )
                }
                TextEditNavigationView(
                    title: String(localized: "Server port"),
                    value: String(model.database.srtlaRelay!.server.port),
                    onSubmit: submitPort,
                    keyboardType: .numbersAndPunctuation,
                    placeholder: "7777"
                )
            }
            if enabled {
                RelayUrlsView()
            }
        }
        .navigationTitle("Relay")
    }
}

private struct StreamerServerView: View {
    @EnvironmentObject var model: Model
    var server: SettingsSrtlaRelayClientServer

    private func submitUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        server.url = value
        model.reloadSrtlaRelayStreamer()
    }

    private func submitPassword(value: String) {
        server.password = value.trim()
        model.reloadSrtlaRelayStreamer()
    }

    var body: some View {
        Form {
            Section {
                TextEditNavigationView(
                    title: String(localized: "Relay URL"),
                    value: server.url,
                    onSubmit: submitUrl,
                    footers: [
                        String(
                            localized: "Enter relay's websocket URL. For example ws://132.23.43.43:2345."
                        ),
                    ],
                    keyboardType: .URL,
                    placeholder: "ws://32.143.32.12:2345"
                )
                TextEditNavigationView(
                    title: String(localized: "Password"),
                    value: server.password,
                    onSubmit: submitPassword
                )
            }
        }.navigationTitle(server.name)
    }
}

private struct StreamerView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Toggle(isOn: Binding(get: {
                    model.database.srtlaRelay!.client.enabled
                }, set: { value in
                    model.database.srtlaRelay!.client.enabled = value
                    model.reloadSrtlaRelayStreamer()
                })) {
                    Text("Enabled")
                }
                .disabled(model.isLive)
            } footer: {
                Text("Enable this on your streaming device. Add relay devices to connect to.")
            }
            Section {
                List {
                    ForEach(model.database.srtlaRelay!.client.servers!) { server in
                        NavigationLink {
                            StreamerServerView(server: server)
                        } label: {
                            Toggle(isOn: Binding(get: {
                                server.enabled
                            }, set: {
                                server.enabled = $0
                                model.reloadSrtlaRelayStreamer()
                            })) {
                                Text(server.name)
                            }
                        }
                    }
                    .onDelete(perform: { offsets in
                        model.database.srtlaRelay!.client.servers!.remove(atOffsets: offsets)
                        model.objectWillChange.send()
                    })
                }
                AddButtonView {
                    model.database.srtlaRelay!.client.servers!.append(SettingsSrtlaRelayClientServer())
                    model.objectWillChange.send()
                }
            } header: {
                Text("Relays")
            }
        }.navigationTitle("Streamer")
    }
}

struct SrtlaRelaySettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                Text("""
                Use phones as additional SRTLA bonding connections. Install Moblink on Android \
                phones to use them.
                """)
            }
            NavigationLink {
                StreamerView()
            } label: {
                Text("Streamer")
            }
            NavigationLink {
                RelayView(
                    enabled: model.database.srtlaRelay!.server.enabled,
                    name: model.database.srtlaRelay!.server.name!,
                    port: model.database.srtlaRelay!.server.port,
                    password: model.database.srtlaRelay!.server.password!
                )
            } label: {
                Text("Relay")
            }
        }
        .navigationTitle("Moblink")
    }
}
