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
        if goPro.launchLiveStream.first(where: { $0.id == model.goProLaunchLiveStreamSelection }) != nil {
            qrCode = GoPro.generateLaunchLiveStream()
        } else {
            qrCode = nil
        }
    }

    var body: some View {
        Section {
            if model.goProLaunchLiveStreamSelection != nil {
                Picker(selection: $model.goProLaunchLiveStreamSelection) {
                    ForEach(entries) { entry in
                        Text(entry.name)
                            .tag(entry.id as UUID?)
                    }
                } label: {
                    Text("Launch live stream")
                }
                .onChange(of: model.goProLaunchLiveStreamSelection) { value in
                    goPro.selectedLaunchLiveStream = value
                    generate()
                }
                if let qrCode {
                    QrCodeImageView(image: qrCode, height: height)
                }
            } else {
                Text("No launch live stream configured")
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
        Section {
            if model.goProWifiCredentialsSelection != nil {
                Picker(selection: $model.goProWifiCredentialsSelection) {
                    ForEach(entries) { entry in
                        Text(entry.name)
                            .tag(entry.id as UUID?)
                    }
                } label: {
                    Text("WiFi credentials")
                }
                .onChange(of: model.goProWifiCredentialsSelection) { value in
                    goPro.selectedWifiCredentials = value
                    generate()
                }
                if let qrCode {
                    QrCodeImageView(image: qrCode, height: height)
                }
            } else {
                Text("No WiFi credentials configured")
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
        Section {
            if model.goProRtmpUrlSelection != nil {
                Picker(selection: $model.goProRtmpUrlSelection) {
                    ForEach(entries) { entry in
                        Text(entry.name)
                            .tag(entry.id as UUID?)
                    }
                } label: {
                    Text("RTMP URL")
                }
                .onChange(of: model.goProRtmpUrlSelection) { value in
                    goPro.selectedRtmpUrl = value
                    generate()
                }
                if let qrCode {
                    QrCodeImageView(image: qrCode, height: height)
                }
            } else {
                Text("No RTMP URLs configured")
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

    private var goPro: SettingsGoPro {
        return model.database.goPro!
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                QuickButtonGoProLaunchLiveStreamView(height: metrics.size.height)
                QuickButtonGoProWifiCredentialsView(height: metrics.size.height)
                QuickButtonGoProRtmpUrlView(height: metrics.size.height)
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
