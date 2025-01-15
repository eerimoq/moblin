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

private struct RelayView: View {
    @EnvironmentObject var model: Model
    @State var name: String

    private func submitUrl(value: String) {
        guard isValidWebSocketUrl(url: value) == nil else {
            return
        }
        model.database.moblink!.client.url = value
        model.reloadMoblinkClient()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                model.database.moblink!.client.enabled
            }, set: { value in
                model.database.moblink!.client.enabled = value
                model.reloadMoblinkClient()
            })) {
                Text("Enabled")
            }
            NavigationLink {
                NameEditView(name: $name)
            } label: {
                TextItemView(name: String(localized: "Name"), value: name)
            }
            .onChange(of: name) { name in
                model.database.moblink!.client.name = name
                model.reloadMoblinkClient()
            }
            TextEditNavigationView(
                title: String(localized: "Streamer URL"),
                value: model.database.moblink!.client.url,
                onSubmit: submitUrl,
                footers: [
                    String(
                        localized: "Enter streamer's websocket URL. For example ws://132.23.43.43:2345."
                    ),
                ],
                keyboardType: .URL,
                placeholder: "ws://32.143.32.12:2345"
            )
        } header: {
            Text("Relay")
        } footer: {
            Text("""
            Enable this on the device you want to use as the extra bonding connection. The device \
            must have cellular data enabled.
            """)
        }
    }
}

private struct StreamerView: View {
    @EnvironmentObject var model: Model
    @Binding var enabled: Bool

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.moblink!.server.port = port
        model.reloadMoblinkServer()
    }

    var body: some View {
        Section {
            Toggle(isOn: $enabled) {
                Text("Enabled")
            }
            .onChange(of: enabled) { value in
                model.database.moblink!.server.enabled = value
                model.reloadMoblinkServer()
            }
            .disabled(model.isLive)
            TextEditNavigationView(
                title: String(localized: "Server port"),
                value: String(model.database.moblink!.server.port),
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

struct MoblinkSettingsView: View {
    @EnvironmentObject var model: Model
    @State var streamerEnabled: Bool

    private func submitPassword(value: String) {
        model.database.moblink!.password = value.trim()
        model.reloadMoblinkClient()
        model.reloadMoblinkServer()
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
                        value: model.database.moblink!.password,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.moblink!.password
                    )
                }
            } footer: {
                Text("Used by both relay and streamer devices. Copy the streamer's password to the relay device.")
            }
            RelayView(name: model.database.moblink!.client.name)
            StreamerView(enabled: $streamerEnabled)
            if streamerEnabled {
                Section {
                    List {
                        ForEach(model.ipStatuses.filter { $0.ipType == .ipv4 }) { status in
                            InterfaceView(
                                ip: status.ipType.formatAddress(status.ip),
                                port: model.database.moblink!.server.port,
                                image: urlImage(interfaceType: status.interfaceType)
                            )
                        }
                        InterfaceView(
                            ip: personalHotspotLocalAddress,
                            port: model.database.moblink!.server.port,
                            image: "personalhotspot"
                        )
                        ForEach(model.ipStatuses.filter { $0.ipType == .ipv6 }) { status in
                            InterfaceView(
                                ip: status.ipType.formatAddress(status.ip),
                                port: model.database.moblink!.server.port,
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
        .navigationTitle("Moblink")
    }
}
