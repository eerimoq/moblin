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
                    value = randomGoodPassword()
                    submit()
                } label: {
                    HCenter {
                        Text("Generate")
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
        model.database.srtlaRelay!.client.url = value
        model.reloadSrtlaRelayClient()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                model.database.srtlaRelay!.client.enabled
            }, set: { value in
                model.database.srtlaRelay!.client.enabled = value
                model.reloadSrtlaRelayClient()
            })) {
                Text("Enabled")
            }
            NavigationLink {
                NameEditView(name: $name)
            } label: {
                TextItemView(name: String(localized: "Name"), value: name)
            }
            .onChange(of: name) { name in
                model.database.srtlaRelay!.client.name = name
                model.reloadSrtlaRelayClient()
            }
            TextEditNavigationView(
                title: String(localized: "Streamer URL"),
                value: model.database.srtlaRelay!.client.url,
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

    private func submitPort(value: String) {
        guard let port = UInt16(value.trim()) else {
            return
        }
        model.database.srtlaRelay!.server.port = port
        model.reloadSrtlaRelayServer()
    }

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                model.database.srtlaRelay!.server.enabled
            }, set: { value in
                model.database.srtlaRelay!.server.enabled = value
                model.reloadSrtlaRelayServer()
            })) {
                Text("Enabled")
            }
            .disabled(model.isLive)
            TextEditNavigationView(
                title: String(localized: "Server port"),
                value: String(model.database.srtlaRelay!.server.port),
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

struct SrtlaRelaySettingsView: View {
    @EnvironmentObject var model: Model

    private func submitPassword(value: String) {
        model.database.srtlaRelay!.password = value.trim()
        model.reloadSrtlaRelayClient()
        model.reloadSrtlaRelayServer()
    }

    var body: some View {
        Form {
            Section {
                Text("Use phones as additional SRTLA bonding connections.")
            }
            Section {
                NavigationLink {
                    PasswordView(
                        value: model.database.srtlaRelay!.password,
                        onSubmit: submitPassword
                    )
                } label: {
                    TextItemView(
                        name: String(localized: "Password"),
                        value: model.database.srtlaRelay!.password,
                        sensitive: true
                    )
                }
            } footer: {
                Text("Used by both relay and streamer.")
            }
            RelayView(name: model.database.srtlaRelay!.client.name)
            StreamerView()
            if model.database.srtlaRelay!.server.enabled {
                Section {
                    List {
                        ForEach(model.ipStatuses.filter { $0.interfaceType != .cellular }, id: \.name) { status in
                            InterfaceView(
                                ip: status.ip,
                                port: model.database.srtlaRelay!.server.port,
                                image: urlImage(interfaceType: status.interfaceType)
                            )
                        }
                        InterfaceView(
                            ip: personalHotspotLocalAddress,
                            port: model.database.srtlaRelay!.server.port,
                            image: "personalhotspot"
                        )
                    }
                } footer: {
                    VStack(alignment: .leading) {
                        Text("""
                        Enter one of the URLs as "Streamer URL" in the relay device to \
                        use it as an additional bonding connection.
                        """)
                    }
                }
            }
        }
        .navigationTitle("SRTLA relay")
    }
}
