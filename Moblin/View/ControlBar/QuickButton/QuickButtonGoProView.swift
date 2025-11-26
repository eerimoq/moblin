import SwiftUI

private struct PickerEntry: Identifiable {
    var id: UUID
    var name: String
}

private struct QuickButtonGoProLaunchLiveStreamView: View {
    @ObservedObject var goProState: GoProState
    @ObservedObject var goPro: SettingsGoPro
    let height: Double
    @State var qrCode: UIImage?
    @State var entries: [PickerEntry] = []

    private func generate() {
        if let launchLiveStream = goPro.launchLiveStream
            .first(where: { $0.id == goProState.launchLiveStreamSelection })
        {
            qrCode = GoPro.generateLaunchLiveStream(isHero12Or13: launchLiveStream.isHero12Or13,
                                                    resolution: launchLiveStream.resolution)
        } else {
            qrCode = nil
        }
    }

    var body: some View {
        VStack {
            if goProState.launchLiveStreamSelection != nil {
                HStack {
                    Text("Launch live stream")
                    Spacer()
                    Picker("", selection: $goProState.launchLiveStreamSelection) {
                        ForEach(entries) { entry in
                            Text(entry.name)
                                .tag(entry.id as UUID?)
                        }
                    }
                    .onChange(of: goProState.launchLiveStreamSelection) {
                        goPro.selectedLaunchLiveStream = $0
                        generate()
                    }
                }
                if let qrCode {
                    Divider()
                    QrCodeImageView(image: qrCode, height: height)
                }
            } else {
                Text("Press the shortcut below to create launch live streams.")
            }
        }
        .onAppear {
            entries = goPro.launchLiveStream.map { .init(id: $0.id, name: $0.name) }
            generate()
        }
    }
}

private struct QuickButtonGoProWifiCredentialsView: View {
    @ObservedObject var goProState: GoProState
    @ObservedObject var goPro: SettingsGoPro
    var height: Double
    @State var qrCode: UIImage?
    @State var entries: [PickerEntry] = []

    private func generate() {
        if let wifiCredentials = goPro.wifiCredentials.first(where: { $0.id == goProState.wifiCredentialsSelection }) {
            qrCode = GoPro.generateWifiCredentialsQrCode(
                ssid: wifiCredentials.ssid,
                password: wifiCredentials.password
            )
        } else {
            qrCode = nil
        }
    }

    var body: some View {
        VStack {
            if goProState.wifiCredentialsSelection != nil {
                HStack {
                    Text("WiFi credentials")
                    Spacer()
                    Picker("", selection: $goProState.wifiCredentialsSelection) {
                        ForEach(entries) { entry in
                            Text(entry.name)
                                .tag(entry.id as UUID?)
                        }
                    }
                    .onChange(of: goProState.wifiCredentialsSelection) {
                        goPro.selectedWifiCredentials = $0
                        generate()
                    }
                }
                if let qrCode {
                    Divider()
                    QrCodeImageView(image: qrCode, height: height)
                }
            } else {
                Text("Press the shortcut below to create WiFi credentials.")
            }
        }
        .onAppear {
            entries = goPro.wifiCredentials.map { .init(id: $0.id, name: $0.name) }
            generate()
        }
    }
}

private struct QuickButtonGoProRtmpUrlView: View {
    @ObservedObject var goProState: GoProState
    @ObservedObject var goPro: SettingsGoPro
    var height: Double
    @State var qrCode: UIImage?
    @State var entries: [PickerEntry] = []

    private func generate() {
        if let rtmpUrl = goPro.rtmpUrls.first(where: { $0.id == goProState.rtmpUrlSelection }) {
            switch rtmpUrl.type {
            case .server:
                qrCode = GoPro.generateRtmpUrlQrCode(url: rtmpUrl.serverUrl)
            case .custom:
                qrCode = GoPro.generateRtmpUrlQrCode(url: rtmpUrl.customUrl)
            }
        } else {
            qrCode = nil
        }
    }

    var body: some View {
        VStack {
            if goProState.rtmpUrlSelection != nil {
                HStack {
                    Text("RTMP URL")
                    Spacer()
                    Picker("", selection: $goProState.rtmpUrlSelection) {
                        ForEach(entries) { entry in
                            Text(entry.name)
                                .tag(entry.id as UUID?)
                        }
                    }
                    .onChange(of: goProState.rtmpUrlSelection) {
                        goPro.selectedRtmpUrl = $0
                        generate()
                    }
                }
                if let qrCode {
                    Divider()
                    QrCodeImageView(image: qrCode, height: height)
                }
            } else {
                Text("Press the shortcut below to create RTMP URLs.")
            }
        }
        .onAppear {
            entries = goPro.rtmpUrls.map { .init(id: $0.id, name: $0.name) }
            generate()
        }
    }
}

struct QuickButtonGoProView: View {
    let goProState: GoProState
    let goPro: SettingsGoPro
    @State private var activeIndex: Int? = 0

    var body: some View {
        GeometryReader { metrics in
            Form {
                if #available(iOS 17, *) {
                    VStack {
                        ScrollView(.horizontal) {
                            HStack {
                                Group {
                                    QuickButtonGoProLaunchLiveStreamView(
                                        goProState: goProState,
                                        goPro: goPro,
                                        height: metrics.size.height
                                    )
                                    .id(0)
                                    QuickButtonGoProWifiCredentialsView(
                                        goProState: goProState,
                                        goPro: goPro,
                                        height: metrics.size.height
                                    )
                                    .id(1)
                                    QuickButtonGoProRtmpUrlView(goProState: goProState,
                                                                goPro: goPro,
                                                                height: metrics.size.height)
                                        .id(2)
                                }
                                .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $activeIndex)
                        .scrollIndicators(.never)
                        HStack {
                            ForEach(0 ..< 3) { index in
                                Button {
                                    withAnimation {
                                        activeIndex = index
                                    }
                                } label: {
                                    Image(systemName: activeIndex == index ? "circle.fill" : "circle")
                                        .font(.system(size: 10))
                                        .padding([.bottom], 10)
                                }
                            }
                        }
                    }
                }
                Section {
                    NavigationLink {
                        GoProSettingsView()
                    } label: {
                        Label("GoPro", systemImage: "appletvremote.gen1")
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            .navigationTitle("GoPro")
        }
    }
}
