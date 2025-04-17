import SwiftUI

private struct GoProLaunchLiveStreamSettingsView: View {
    @EnvironmentObject var model: Model
    var launchLiveStream: SettingsGoProLaunchLiveStream
    @Binding var name: String
    @State var qrCode: UIImage?

    private func generate() {
        qrCode = GoPro.generateLaunchLiveStream(isHero12Or13: launchLiveStream.isHero12Or13!)
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Name"),
                        value: name,
                        onSubmit: {
                            name = $0
                        }
                    )
                }
                Section {
                    Toggle("HERO 12/13", isOn: Binding(get: {
                        launchLiveStream.isHero12Or13!
                    }, set: { value in
                        launchLiveStream.isHero12Or13 = value
                        generate()
                    }))
                }
                if let qrCode {
                    Section {
                        QrCodeImageView(image: qrCode, height: metrics.size.height)
                    }
                }
            }
            .onChange(of: name) {
                launchLiveStream.name = $0
            }
            .onAppear {
                generate()
            }
            .navigationTitle("Launch live stream")
        }
    }
}

private struct GoProLaunchLiveStreamSettingsEntryView: View {
    var launchLiveStream: SettingsGoProLaunchLiveStream
    @State var name: String = ""

    var body: some View {
        NavigationLink {
            GoProLaunchLiveStreamSettingsView(launchLiveStream: launchLiveStream, name: $name)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(name)
                Spacer()
            }
        }
        .onAppear {
            name = launchLiveStream.name
        }
    }
}

private struct GoProWifiCredentialsSettingsView: View {
    @EnvironmentObject var model: Model
    var wifiCredentials: SettingsGoProWifiCredentials
    @Binding var name: String
    @Binding var ssid: String
    @Binding var password: String
    @State var qrCode: UIImage?

    private func generate() {
        qrCode = GoPro.generateWifiCredentialsQrCode(ssid: ssid, password: password)
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Name"),
                        value: name,
                        onSubmit: {
                            name = $0
                        }
                    )
                }
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "SSID"),
                            value: ssid,
                            onSubmit: {
                                ssid = $0
                            }
                        )
                    } label: {
                        TextItemView(name: String(localized: "SSID"), value: ssid)
                    }
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Password"),
                            value: password,
                            onSubmit: {
                                password = $0
                            }
                        )
                    } label: {
                        TextItemView(name: String(localized: "Password"), value: password)
                    }
                }
                if let qrCode {
                    Section {
                        QrCodeImageView(image: qrCode, height: metrics.size.height)
                    }
                }
            }
            .onChange(of: name) {
                wifiCredentials.name = $0
            }
            .onChange(of: ssid) {
                wifiCredentials.ssid = $0
                generate()
            }
            .onChange(of: password) {
                wifiCredentials.password = $0
                generate()
            }
            .onAppear {
                generate()
            }
            .navigationTitle("WiFi credentials")
        }
    }
}

private struct GoProWifiCredentialsSettingsEntryView: View {
    var wifiCredentials: SettingsGoProWifiCredentials
    @State var name: String = ""
    @State var ssid: String = ""
    @State var password: String = ""

    var body: some View {
        NavigationLink {
            GoProWifiCredentialsSettingsView(wifiCredentials: wifiCredentials,
                                             name: $name,
                                             ssid: $ssid,
                                             password: $password)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(name)
                Spacer()
            }
        }
        .onAppear {
            name = wifiCredentials.name
            ssid = wifiCredentials.ssid
            password = wifiCredentials.password
        }
    }
}

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

private struct GoProRtmpUrlView: View {
    @EnvironmentObject var model: Model
    var rtmpUrl: SettingsGoProRtmpUrl
    @Binding var type: SettingsDjiDeviceUrlType
    @Binding var serverStreamId: UUID
    @Binding var serverUrl: String
    @Binding var customUrl: String

    private func serverUrls() -> [String] {
        guard let stream = model.getRtmpStream(id: serverStreamId) else {
            return []
        }
        var serverUrls: [String] = []
        for status in model.ipStatuses.filter({ $0.ipType == .ipv4 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: model.database.rtmpServer!.port,
                streamKey: stream.streamKey
            ))
        }
        serverUrls.append(rtmpStreamUrl(
            address: personalHotspotLocalAddress,
            port: model.database.rtmpServer!.port,
            streamKey: stream.streamKey
        ))
        for status in model.ipStatuses.filter({ $0.ipType == .ipv6 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: model.database.rtmpServer!.port,
                streamKey: stream.streamKey
            ))
        }
        return serverUrls
    }

    var body: some View {
        Section {
            Picker("Type", selection: $type) {
                ForEach(SettingsDjiDeviceUrlType.allCases, id: \.self) {
                    Text($0.toString())
                        .tag($0)
                }
            }
            if type == .server {
                if model.database.rtmpServer!.streams.isEmpty {
                    Text("No RTMP server streams exists")
                } else {
                    Picker("Stream", selection: $serverStreamId) {
                        ForEach(model.database.rtmpServer!.streams) { stream in
                            Text(stream.name)
                                .tag(stream.id)
                        }
                    }
                    .onChange(of: serverStreamId) { _ in
                        serverUrl = serverUrls().first ?? ""
                    }
                    Picker("URL", selection: $serverUrl) {
                        ForEach(serverUrls(), id: \.self) {
                            Text($0)
                                .tag($0)
                        }
                    }
                    if !model.database.rtmpServer!.enabled {
                        Text("⚠️ The RTMP server is not enabled")
                    }
                }
            } else if type == .custom {
                TextEditNavigationView(
                    title: String(localized: "URL"),
                    value: customUrl,
                    onSubmit: {
                        customUrl = $0
                    }
                )
            }
        } header: {
            Text("RTMP")
        } footer: {
            Text("""
            Select \(String(localized: "Server")) if you want the GoPro camera to stream to \
            Moblin's RTMP server on this device. Select \(String(localized: "Custom")) to \
            make the GoPro camera stream to any destination.
            """)
        }
        .onAppear {
            let streams = model.database.rtmpServer!.streams
            if !streams.isEmpty {
                if !streams.contains(where: { $0.id == serverStreamId }) {
                    serverStreamId = streams.first!.id
                }
                if !serverUrls().contains(where: { $0 == serverUrl }) {
                    serverUrl = serverUrls().first ?? ""
                }
            }
        }
        Section {
            NavigationLink {
                RtmpServerSettingsView()
            } label: {
                Text("RTMP server")
            }
        } header: {
            Text("Shortcut")
        }
    }
}

private struct GoProRtmpUrlSettingsView: View {
    @EnvironmentObject var model: Model
    var rtmpUrl: SettingsGoProRtmpUrl
    @Binding var name: String
    @Binding var type: SettingsDjiDeviceUrlType
    @Binding var serverStreamId: UUID
    @Binding var serverUrl: String
    @Binding var customUrl: String
    @State var qrCode: UIImage?

    private func generate() {
        switch type {
        case .server:
            qrCode = GoPro.generateRtmpUrlQrCode(url: serverUrl)
        case .custom:
            qrCode = GoPro.generateRtmpUrlQrCode(url: customUrl)
        }
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    TextEditNavigationView(
                        title: String(localized: "Name"),
                        value: name,
                        onSubmit: {
                            name = $0
                        }
                    )
                }
                GoProRtmpUrlView(
                    rtmpUrl: rtmpUrl,
                    type: $type,
                    serverStreamId: $serverStreamId,
                    serverUrl: $serverUrl,
                    customUrl: $customUrl
                )
                if let qrCode {
                    Section {
                        QrCodeImageView(image: qrCode, height: metrics.size.height)
                    }
                }
            }
            .onChange(of: name) {
                rtmpUrl.name = $0
            }
            .onChange(of: type) {
                rtmpUrl.type = $0
                generate()
            }
            .onChange(of: serverStreamId) {
                rtmpUrl.serverStreamId = $0
            }
            .onChange(of: serverUrl) {
                rtmpUrl.serverUrl = $0
                generate()
            }
            .onChange(of: customUrl) {
                rtmpUrl.customUrl = $0
                generate()
            }
            .onAppear {
                generate()
            }
            .navigationTitle("RTMP URL")
        }
    }
}

private struct GoProRtmpUrlSettingsEntryView: View {
    var rtmpUrl: SettingsGoProRtmpUrl
    @State var name: String = ""
    @State var type: SettingsDjiDeviceUrlType = .server
    @State var serverStreamId = UUID()
    @State var serverUrl = ""
    @State var customUrl = ""

    var body: some View {
        NavigationLink {
            GoProRtmpUrlSettingsView(
                rtmpUrl: rtmpUrl,
                name: $name,
                type: $type,
                serverStreamId: $serverStreamId,
                serverUrl: $serverUrl,
                customUrl: $customUrl
            )
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(name)
                Spacer()
            }
        }
        .onAppear {
            name = rtmpUrl.name
            type = rtmpUrl.type
            serverStreamId = rtmpUrl.serverStreamId
            serverUrl = rtmpUrl.serverUrl
            customUrl = rtmpUrl.customUrl
        }
    }
}

private struct GoProLaunchLiveStream: View {
    @EnvironmentObject var model: Model

    var goPro: SettingsGoPro {
        model.database.goPro!
    }

    var body: some View {
        Section {
            List {
                ForEach(goPro.launchLiveStream) { launchLiveStream in
                    GoProLaunchLiveStreamSettingsEntryView(launchLiveStream: launchLiveStream)
                }
                .onMove(perform: { froms, to in
                    goPro.launchLiveStream.move(fromOffsets: froms, toOffset: to)
                })
                .onDelete(perform: { offsets in
                    goPro.launchLiveStream.remove(atOffsets: offsets)
                    if !goPro.launchLiveStream.contains(where: { $0.id == goPro.selectedLaunchLiveStream }) {
                        goPro.selectedLaunchLiveStream = goPro.launchLiveStream.first?.id
                        model.goProLaunchLiveStreamSelection = goPro.selectedLaunchLiveStream
                    }
                })
            }
            CreateButtonView {
                let launchLiveStream = SettingsGoProLaunchLiveStream()
                if goPro.launchLiveStream.isEmpty {
                    goPro.selectedLaunchLiveStream = launchLiveStream.id
                    model.goProLaunchLiveStreamSelection = goPro.selectedLaunchLiveStream
                }
                goPro.launchLiveStream.append(launchLiveStream)
                model.objectWillChange.send()
            }
        } header: {
            Text("Launch live streams")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "an entry"))
        }
    }
}

private struct GoProWifiCredentials: View {
    @EnvironmentObject var model: Model

    var goPro: SettingsGoPro {
        model.database.goPro!
    }

    var body: some View {
        Section {
            List {
                ForEach(goPro.wifiCredentials) { wifiCredentials in
                    GoProWifiCredentialsSettingsEntryView(wifiCredentials: wifiCredentials)
                }
                .onMove(perform: { froms, to in
                    goPro.wifiCredentials.move(fromOffsets: froms, toOffset: to)
                })
                .onDelete(perform: { offsets in
                    goPro.wifiCredentials.remove(atOffsets: offsets)
                    if !goPro.wifiCredentials.contains(where: { $0.id == goPro.selectedWifiCredentials }) {
                        goPro.selectedWifiCredentials = goPro.wifiCredentials.first?.id
                        model.goProWifiCredentialsSelection = goPro.selectedWifiCredentials
                    }
                })
            }
            CreateButtonView {
                let wifiCredentials = SettingsGoProWifiCredentials()
                if goPro.wifiCredentials.isEmpty {
                    goPro.selectedWifiCredentials = wifiCredentials.id
                    model.goProWifiCredentialsSelection = goPro.selectedWifiCredentials
                }
                goPro.wifiCredentials.append(wifiCredentials)
                model.objectWillChange.send()
            }
        } header: {
            Text("WiFi credentials")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "an entry"))
        }
    }
}

private struct GoProRtmpUrls: View {
    @EnvironmentObject var model: Model

    var goPro: SettingsGoPro {
        model.database.goPro!
    }

    var body: some View {
        Section {
            List {
                ForEach(goPro.rtmpUrls) { rtmpUrl in
                    GoProRtmpUrlSettingsEntryView(rtmpUrl: rtmpUrl)
                }
                .onMove(perform: { froms, to in
                    goPro.rtmpUrls.move(fromOffsets: froms, toOffset: to)
                })
                .onDelete(perform: { offsets in
                    goPro.rtmpUrls.remove(atOffsets: offsets)
                    if !goPro.rtmpUrls.contains(where: { $0.id == goPro.selectedRtmpUrl }) {
                        goPro.selectedRtmpUrl = goPro.rtmpUrls.first?.id
                        model.goProRtmpUrlSelection = goPro.selectedRtmpUrl
                    }
                })
            }
            CreateButtonView {
                let rtmpUrl = SettingsGoProRtmpUrl()
                if goPro.rtmpUrls.isEmpty {
                    goPro.selectedRtmpUrl = rtmpUrl.id
                    model.goProRtmpUrlSelection = goPro.selectedRtmpUrl
                }
                goPro.rtmpUrls.append(rtmpUrl)
                model.objectWillChange.send()
            }
        } header: {
            Text("RTMP URLs")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "an entry"))
        }
    }
}

struct GoProSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    Image("GoPro")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 130)
                }
            }
            GoProLaunchLiveStream()
            GoProWifiCredentials()
            GoProRtmpUrls()
        }
        .navigationTitle("GoPro")
    }
}
