import NetworkExtension
import SwiftUI

private struct GoProLaunchLiveStreamSettingsView: View {
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var launchLiveStream: SettingsGoProLaunchLiveStream
    @State var qrCode: UIImage?

    private func generate() {
        qrCode = GoPro.generateLaunchLiveStream(isHero12Or13: launchLiveStream.isHero12Or13,
                                                resolution: launchLiveStream.resolution)
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    NameEditView(name: $launchLiveStream.name, existingNames: goPro.launchLiveStream)
                }
                Section {
                    Toggle("HERO 12/13", isOn: Binding(get: {
                        launchLiveStream.isHero12Or13
                    }, set: { value in
                        launchLiveStream.isHero12Or13 = value
                        generate()
                    }))
                    Picker("Resolution", selection: $launchLiveStream.resolution) {
                        ForEach(SettingsGoProLaunchLiveStreamResolution.allCases, id: \.self) { resolution in
                            Text(resolution.rawValue)
                        }
                    }
                    .onChange(of: launchLiveStream.resolution) { _ in
                        generate()
                    }
                }
                if let qrCode {
                    Section {
                        QrCodeImageView(image: qrCode, height: metrics.size.height)
                    }
                }
            }
            .onAppear {
                generate()
            }
            .navigationTitle("Launch live stream")
        }
    }
}

private struct GoProLaunchLiveStreamSettingsEntryView: View {
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var launchLiveStream: SettingsGoProLaunchLiveStream

    var body: some View {
        NavigationLink {
            GoProLaunchLiveStreamSettingsView(goPro: goPro, launchLiveStream: launchLiveStream)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(launchLiveStream.name)
                Spacer()
            }
        }
    }
}

private struct GoProWifiCredentialsSettingsView: View {
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var wifiCredentials: SettingsGoProWifiCredentials
    @State var qrCode: UIImage?

    private func generate() {
        qrCode = GoPro.generateWifiCredentialsQrCode(ssid: wifiCredentials.ssid, password: wifiCredentials.password)
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    NameEditView(name: $wifiCredentials.name, existingNames: goPro.wifiCredentials)
                }
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "SSID"),
                            value: wifiCredentials.ssid,
                            onSubmit: {
                                wifiCredentials.ssid = $0
                                generate()
                            }
                        )
                    } label: {
                        TextItemView(name: String(localized: "SSID"), value: wifiCredentials.ssid)
                    }
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "Password"),
                            value: wifiCredentials.password,
                            onSubmit: {
                                wifiCredentials.password = $0
                                generate()
                            }
                        )
                    } label: {
                        TextItemView(
                            name: String(localized: "Password"),
                            value: wifiCredentials.password,
                            sensitive: true
                        )
                    }
                }
                if let qrCode {
                    Section {
                        QrCodeImageView(image: qrCode, height: metrics.size.height)
                    }
                }
            }
            .onAppear {
                generate()
            }
            .navigationTitle("WiFi credentials")
            .onAppear {
                NEHotspotNetwork.fetchCurrent(completionHandler: { network in
                    if wifiCredentials.ssid.isEmpty, let network {
                        wifiCredentials.ssid = network.ssid
                        generate()
                    }
                })
            }
        }
    }
}

private struct GoProWifiCredentialsSettingsEntryView: View {
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var wifiCredentials: SettingsGoProWifiCredentials

    var body: some View {
        NavigationLink {
            GoProWifiCredentialsSettingsView(goPro: goPro, wifiCredentials: wifiCredentials)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(wifiCredentials.name)
                Spacer()
            }
        }
    }
}

private func rtmpStreamUrl(address: String, port: UInt16, streamKey: String) -> String {
    return "rtmp://\(address):\(port)\(rtmpServerApp)/\(streamKey)"
}

private struct GoProRtmpUrlSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var status: StatusOther
    @ObservedObject var rtmpUrl: SettingsGoProRtmpUrl
    @State var qrCode: UIImage?

    private func generate() {
        switch rtmpUrl.type {
        case .server:
            qrCode = GoPro.generateRtmpUrlQrCode(url: rtmpUrl.serverUrl)
        case .custom:
            qrCode = GoPro.generateRtmpUrlQrCode(url: rtmpUrl.customUrl)
        }
    }

    private func serverUrls() -> [String] {
        guard let stream = model.getRtmpStream(id: rtmpUrl.serverStreamId) else {
            return []
        }
        var serverUrls: [String] = []
        for status in status.ipStatuses.filter({ $0.ipType == .ipv4 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: model.database.rtmpServer.port,
                streamKey: stream.streamKey
            ))
        }
        serverUrls.append(rtmpStreamUrl(
            address: personalHotspotLocalAddress,
            port: model.database.rtmpServer.port,
            streamKey: stream.streamKey
        ))
        for status in status.ipStatuses.filter({ $0.ipType == .ipv6 }) {
            serverUrls.append(rtmpStreamUrl(
                address: status.ipType.formatAddress(status.ip),
                port: model.database.rtmpServer.port,
                streamKey: stream.streamKey
            ))
        }
        return serverUrls
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    NameEditView(name: $rtmpUrl.name, existingNames: goPro.rtmpUrls)
                }
                Section {
                    Picker("Type", selection: $rtmpUrl.type) {
                        ForEach(SettingsDjiDeviceUrlType.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    .onChange(of: rtmpUrl.type) { _ in
                        generate()
                    }
                    if rtmpUrl.type == .server {
                        if model.database.rtmpServer.streams.isEmpty {
                            Text("No RTMP server streams exists")
                        } else {
                            Picker("Stream", selection: $rtmpUrl.serverStreamId) {
                                ForEach(model.database.rtmpServer.streams) { stream in
                                    Text(stream.name)
                                        .tag(stream.id)
                                }
                            }
                            .onChange(of: rtmpUrl.serverStreamId) { _ in
                                rtmpUrl.serverUrl = serverUrls().first ?? ""
                            }
                            Picker("URL", selection: $rtmpUrl.serverUrl) {
                                ForEach(serverUrls(), id: \.self) {
                                    Text($0)
                                        .tag($0)
                                }
                            }
                            if !model.database.rtmpServer.enabled {
                                Text("⚠️ The RTMP server is not enabled")
                            }
                        }
                    } else if rtmpUrl.type == .custom {
                        TextEditNavigationView(
                            title: String(localized: "URL"),
                            value: rtmpUrl.customUrl,
                            onSubmit: {
                                rtmpUrl.customUrl = $0
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
                    let streams = model.database.rtmpServer.streams
                    if !streams.isEmpty {
                        if !streams.contains(where: { $0.id == rtmpUrl.serverStreamId }) {
                            rtmpUrl.serverStreamId = streams.first!.id
                        }
                        if !serverUrls().contains(where: { $0 == rtmpUrl.serverUrl }) {
                            rtmpUrl.serverUrl = serverUrls().first ?? ""
                        }
                    }
                }
                Section {
                    RtmpServerSettingsView(rtmpServer: model.database.rtmpServer)
                } header: {
                    Text("Shortcut")
                }
                if let qrCode {
                    Section {
                        QrCodeImageView(image: qrCode, height: metrics.size.height)
                    }
                }
            }
            .onChange(of: rtmpUrl.serverUrl) { _ in
                generate()
            }
            .onChange(of: rtmpUrl.customUrl) { _ in
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
    @ObservedObject var goPro: SettingsGoPro
    let status: StatusOther
    @ObservedObject var rtmpUrl: SettingsGoProRtmpUrl

    var body: some View {
        NavigationLink {
            GoProRtmpUrlSettingsView(goPro: goPro, status: status, rtmpUrl: rtmpUrl)
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(rtmpUrl.name)
                Spacer()
            }
        }
    }
}

private struct GoProLaunchLiveStream: View {
    @EnvironmentObject var model: Model
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var goProState: GoProState

    var body: some View {
        Section {
            List {
                ForEach(goPro.launchLiveStream) { launchLiveStream in
                    GoProLaunchLiveStreamSettingsEntryView(goPro: goPro, launchLiveStream: launchLiveStream)
                }
                .onMove { froms, to in
                    goPro.launchLiveStream.move(fromOffsets: froms, toOffset: to)
                }
                .onDelete { offsets in
                    goPro.launchLiveStream.remove(atOffsets: offsets)
                    if !goPro.launchLiveStream.contains(where: { $0.id == goPro.selectedLaunchLiveStream }) {
                        goPro.selectedLaunchLiveStream = goPro.launchLiveStream.first?.id
                        goProState.launchLiveStreamSelection = goPro.selectedLaunchLiveStream
                    }
                }
            }
            CreateButtonView {
                let launchLiveStream = SettingsGoProLaunchLiveStream()
                launchLiveStream.name = makeUniqueName(name: SettingsGoProLaunchLiveStream.baseName,
                                                       existingNames: goPro.launchLiveStream)
                if goPro.launchLiveStream.isEmpty {
                    goPro.selectedLaunchLiveStream = launchLiveStream.id
                    goProState.launchLiveStreamSelection = goPro.selectedLaunchLiveStream
                }
                goPro.launchLiveStream.append(launchLiveStream)
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
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var goProState: GoProState

    var body: some View {
        Section {
            List {
                ForEach(goPro.wifiCredentials) { wifiCredentials in
                    GoProWifiCredentialsSettingsEntryView(goPro: goPro, wifiCredentials: wifiCredentials)
                }
                .onMove { froms, to in
                    goPro.wifiCredentials.move(fromOffsets: froms, toOffset: to)
                }
                .onDelete { offsets in
                    goPro.wifiCredentials.remove(atOffsets: offsets)
                    if !goPro.wifiCredentials.contains(where: { $0.id == goPro.selectedWifiCredentials }) {
                        goPro.selectedWifiCredentials = goPro.wifiCredentials.first?.id
                        goProState.wifiCredentialsSelection = goPro.selectedWifiCredentials
                    }
                }
            }
            CreateButtonView {
                let wifiCredentials = SettingsGoProWifiCredentials()
                wifiCredentials.name = makeUniqueName(name: SettingsGoProWifiCredentials.baseName,
                                                      existingNames: goPro.wifiCredentials)
                if goPro.wifiCredentials.isEmpty {
                    goPro.selectedWifiCredentials = wifiCredentials.id
                    goProState.wifiCredentialsSelection = goPro.selectedWifiCredentials
                }
                goPro.wifiCredentials.append(wifiCredentials)
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
    @ObservedObject var status: StatusOther
    @ObservedObject var goPro: SettingsGoPro
    @ObservedObject var goProState: GoProState

    var body: some View {
        Section {
            List {
                ForEach(goPro.rtmpUrls) { rtmpUrl in
                    GoProRtmpUrlSettingsEntryView(goPro: goPro, status: status, rtmpUrl: rtmpUrl)
                }
                .onMove { froms, to in
                    goPro.rtmpUrls.move(fromOffsets: froms, toOffset: to)
                }
                .onDelete { offsets in
                    goPro.rtmpUrls.remove(atOffsets: offsets)
                    if !goPro.rtmpUrls.contains(where: { $0.id == goPro.selectedRtmpUrl }) {
                        goPro.selectedRtmpUrl = goPro.rtmpUrls.first?.id
                        goProState.rtmpUrlSelection = goPro.selectedRtmpUrl
                    }
                }
            }
            CreateButtonView {
                let rtmpUrl = SettingsGoProRtmpUrl()
                rtmpUrl.name = makeUniqueName(name: SettingsGoProRtmpUrl.baseName, existingNames: goPro.rtmpUrls)
                if goPro.rtmpUrls.isEmpty {
                    goPro.selectedRtmpUrl = rtmpUrl.id
                    goProState.rtmpUrlSelection = goPro.selectedRtmpUrl
                }
                goPro.rtmpUrls.append(rtmpUrl)
            }
        } header: {
            Text("RTMP URLs")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a URL"))
        }
    }
}

struct GoProSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            Section {
                HCenter {
                    IntegrationImageView(imageName: "GoPro")
                }
            }
            GoProLaunchLiveStream(goPro: model.database.goPro, goProState: model.goPro)
            GoProWifiCredentials(goPro: model.database.goPro, goProState: model.goPro)
            GoProRtmpUrls(status: model.statusOther, goPro: model.database.goPro, goProState: model.goPro)
        }
        .navigationTitle("GoPro")
    }
}
