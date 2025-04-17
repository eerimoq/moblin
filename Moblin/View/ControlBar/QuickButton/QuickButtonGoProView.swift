import SwiftUI

private struct PickerEntry: Identifiable {
    var id: UUID
    var name: String
}

private struct QuickButtonGoProLaunchLiveStreamView: View {
    @EnvironmentObject var model: Model
    var height: Double
    @State var qrCode: UIImage?
    @State var entries: [PickerEntry] = []

    private var goPro: SettingsGoPro {
        return model.database.goPro!
    }

    private func generate() {
        if let launchLiveStream = goPro.launchLiveStream
            .first(where: { $0.id == model.goProLaunchLiveStreamSelection })
        {
            qrCode = GoPro.generateLaunchLiveStream(isHero12Or13: launchLiveStream.isHero12Or13!)
        } else {
            qrCode = nil
        }
    }

    var body: some View {
        VStack {
            if model.goProLaunchLiveStreamSelection != nil {
                HStack {
                    Text("Launch live stream")
                    Spacer()
                    Picker("", selection: $model.goProLaunchLiveStreamSelection) {
                        ForEach(entries) { entry in
                            Text(entry.name)
                                .tag(entry.id as UUID?)
                        }
                    }
                    .onChange(of: model.goProLaunchLiveStreamSelection) { value in
                        goPro.selectedLaunchLiveStream = value
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
    @EnvironmentObject var model: Model
    var height: Double
    @State var qrCode: UIImage?
    @State var entries: [PickerEntry] = []

    private var goPro: SettingsGoPro {
        return model.database.goPro!
    }

    private func generate() {
        if let wifiCredentials = goPro.wifiCredentials.first(where: { $0.id == model.goProWifiCredentialsSelection }) {
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
            if model.goProWifiCredentialsSelection != nil {
                HStack {
                    Text("WiFi credentials")
                    Spacer()
                    Picker("", selection: $model.goProWifiCredentialsSelection) {
                        ForEach(entries) { entry in
                            Text(entry.name)
                                .tag(entry.id as UUID?)
                        }
                    }
                    .onChange(of: model.goProWifiCredentialsSelection) { value in
                        goPro.selectedWifiCredentials = value
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
    @EnvironmentObject var model: Model
    var height: Double
    @State var qrCode: UIImage?
    @State var entries: [PickerEntry] = []

    private var goPro: SettingsGoPro {
        return model.database.goPro!
    }

    private func generate() {
        if let rtmpUrl = goPro.rtmpUrls.first(where: { $0.id == model.goProRtmpUrlSelection }) {
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
            if model.goProRtmpUrlSelection != nil {
                HStack {
                    Text("RTMP URL")
                    Spacer()
                    Picker("", selection: $model.goProRtmpUrlSelection) {
                        ForEach(entries) { entry in
                            Text(entry.name)
                                .tag(entry.id as UUID?)
                        }
                    }
                    .onChange(of: model.goProRtmpUrlSelection) { value in
                        goPro.selectedRtmpUrl = value
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
    @EnvironmentObject var model: Model
    @State private var activeIndex: Int? = 0

    private var goPro: SettingsGoPro {
        return model.database.goPro!
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                if #available(iOS 17, *) {
                    VStack {
                        ScrollView(.horizontal) {
                            HStack {
                                Group {
                                    QuickButtonGoProLaunchLiveStreamView(height: metrics.size.height)
                                        .id(0)
                                    QuickButtonGoProWifiCredentialsView(height: metrics.size.height)
                                        .id(1)
                                    QuickButtonGoProRtmpUrlView(height: metrics.size.height)
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
                        IconAndTextView(image: "appletvremote.gen1", text: String(localized: "GoPro"))
                    }
                } header: {
                    Text("Shortcut")
                }
            }
            .navigationTitle("GoPro")
        }
    }
}
