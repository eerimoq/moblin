import SwiftUI

private struct QuickButtonGoProWifiCredentialsView: View {
    @EnvironmentObject var model: Model
    var height: Double
    @State var qrCode: UIImage?

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
                    ForEach(goPro.wifiCredentials) { wifiCredentials in
                        Text(wifiCredentials.name)
                            .tag(wifiCredentials.id as UUID?)
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
            generate()
        }
    }
}

private struct QuickButtonGoProRtmpUrlView: View {
    @EnvironmentObject var model: Model
    var height: Double
    @State var qrCode: UIImage?

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
                    ForEach(goPro.rtmpUrls) { rtmpUrl in
                        Text(rtmpUrl.name)
                            .tag(rtmpUrl.id as UUID?)
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
