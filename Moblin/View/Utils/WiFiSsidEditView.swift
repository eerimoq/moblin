import CoreLocation
import SwiftUI

@MainActor
private class CurrentWiFiNetwork: NSObject, ObservableObject {
    @Published var ssid: String?
    @Published var locationDenied = false
    private let locationManager = CLLocationManager()

    override init() {
        super.init()
        locationManager.delegate = self
    }
}

extension CurrentWiFiNetwork: @preconcurrency CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationDenied = true
        default:
            fetchCurrentWiFiSsid { ssid in
                Task { @MainActor in
                    self.ssid = ssid
                }
            }
        }
    }
}

struct WiFiSsidEditView: View {
    @Environment(\.dismiss) private var dismiss
    @State var value: String
    let onSubmit: (String) -> Void
    @StateObject private var currentNetwork = CurrentWiFiNetwork()
    @State private var changed = false
    @State private var submitted = false

    private func submit() {
        submitted = true
        value = value.trim()
        onSubmit(value)
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $value)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .onChange(of: value) { _ in
                        changed = true
                    }
                    .onSubmit {
                        submit()
                        dismiss()
                    }
                    .submitLabel(.done)
                    .onDisappear {
                        if changed, !submitted {
                            submit()
                        }
                    }
            }
            if let currentSsid = currentNetwork.ssid {
                Section {
                    Button {
                        value = currentSsid
                        submit()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "wifi")
                            Text(currentSsid)
                            Spacer()
                            if currentSsid == value {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } header: {
                    Text("Current network")
                } footer: {
                    Text("The WiFi network this device is currently connected to.")
                }
            } else if currentNetwork.locationDenied {
                Section {
                    Text(
                        "Allow Moblin to access your location in iOS Settings to see the current WiFi network."
                    )
                }
            }
        }
        .navigationTitle("SSID")
        .onChange(of: currentNetwork.ssid) { ssid in
            if value.isEmpty, let ssid {
                value = ssid
            }
        }
    }
}
