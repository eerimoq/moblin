import SwiftUI

private struct GoProWiFiCredentialsSettingsView: View {
    @State var ssid: String
    @State var password: String
    @State var qrCode: UIImage?

    private func generate() {
        qrCode = generateQrCode(from: "!MJOIN=\"\(ssid):\(password)\"")
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "SSID"),
                            value: ssid,
                            onSubmit: {
                                ssid = $0
                                generate()
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
                                generate()
                            }
                        )
                    } label: {
                        TextItemView(name: String(localized: "Password"), value: password)
                    }
                }
                if let qrCode {
                    Section {
                        HStack {
                            Spacer()
                            Image(uiImage: qrCode)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(maxHeight: metrics.size.height)
                            Spacer()
                        }
                    }
                }
            }
            .onAppear {
                generate()
            }
            .navigationTitle("WiFi credentials")
        }
    }
}

private struct GoProRtmpUrlSettingsView: View {
    @State var url: String
    @State var qrCode: UIImage?

    private func generate() {
        qrCode = generateQrCode(from: "!MRTMP=\"\(url)\"")
    }

    var body: some View {
        GeometryReader { metrics in
            Form {
                Section {
                    NavigationLink {
                        TextEditView(
                            title: String(localized: "URL"),
                            value: url,
                            placeholder: "rtmp://1.2.3.4:222/app/1",
                            onSubmit: {
                                url = $0
                                generate()
                            }
                        )
                    } label: {
                        TextItemView(name: String(localized: "URL"), value: url)
                    }
                }
                if let qrCode {
                    Section {
                        HStack {
                            Spacer()
                            Image(uiImage: qrCode)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(maxHeight: metrics.size.height)
                            Spacer()
                        }
                    }
                }
            }
            .onAppear {
                generate()
            }
            .navigationTitle("RTMP URL")
        }
    }
}

struct GoProSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Form {
            NavigationLink {
                GoProWiFiCredentialsSettingsView(ssid: "Qvist", password: "maxierik")
            } label: {
                Text("WiFi credentials")
            }
            NavigationLink {
                GoProRtmpUrlSettingsView(url: "rtmp://1.2.3/3/4")
            } label: {
                Text("RTMP URL")
            }
        }
        .navigationTitle("GoPro")
    }
}
