import DeviceDiscoveryUI
import Network
import SwiftUI
import WiFiAware

private let serviceName = "_moblin._tcp"

@available(iOS 26, *)
func wiFiAwarePublishableService() -> WAPublishableService {
    return WAPublishableService.allServices[serviceName]!
}

@available(iOS 26, *)
func wiFiAwareSubscribableService() -> WASubscribableService {
    return WASubscribableService.allServices[serviceName]!
}

@available(iOS 26, *)
private struct PairedDevicesView: View {
    @State private var pairedDevices: [WAPairedDevice] = []

    var body: some View {
        Section {
            List(pairedDevices) { device in
                Text(device.displayName())
            }
        } header: {
            Text(String("Paired devices"))
        }
        .task {
            do {
                for try await updatedDeviceList in WAPairedDevice.allDevices {
                    pairedDevices = Array(updatedDeviceList.values)
                }
            } catch {}
        }
    }
}

@available(iOS 26.0, *)
private struct AdvertiseView: View {
    var body: some View {
        Section {
            DevicePairingView(.wifiAware(.connecting(
                to: wiFiAwarePublishableService(),
                from: .userSpecifiedDevices
            ))) {
                HCenter {
                    Text(String("Advertise"))
                }
            } fallback: {
                Text(String("Unavailable"))
            }
            .buttonStyle(.borderless)
        }
    }
}

@available(iOS 26.0, *)
private struct SearchView: View {
    var body: some View {
        Section {
            DevicePicker(.wifiAware(.connecting(
                to: .userSpecifiedDevices,
                from: wiFiAwareSubscribableService()
            ))) {
                logger.info("wifi-aware: Paired endpoint: \($0)")
            } label: {
                HCenter {
                    Text("Search")
                }
            } fallback: {
                Text(String("Unavailable"))
            }
            .buttonStyle(.borderless)
        }
    }
}

@available(iOS 26, *)
struct WiFiAwareSettingsView: View {
    let model: Model
    @ObservedObject var wiFiAware: SettingsWiFiAware

    var body: some View {
        Form {
            if WACapabilities.supportedFeatures.contains(.wifiAware) {
                Section {
                    Toggle("Enabled", isOn: $wiFiAware.enabled)
                        .onChange(of: wiFiAware.enabled) { _ in
                            model.wiFiAwareUpdated()
                        }
                }
                Section {
                    Picker(String("Role"), selection: $wiFiAware.role) {
                        ForEach(SettingsWiFiAwareRole.allCases, id: \.self) {
                            Text($0.toString())
                        }
                    }
                    .disabled(wiFiAware.enabled)
                }
                PairedDevicesView()
                AdvertiseView()
                SearchView()
            } else {
                Section {
                    Text(String("This device does not support WiFi Aware"))
                }
            }
        }
        .navigationTitle(String("WiFi Aware"))
    }
}

@available(iOS 26, *)
extension WAPairedDevice {
    func displayName() -> String {
        let deviceName = name ?? pairingInfo?.pairingName ?? "Unknown"
        let vendorName = pairingInfo?.vendorName ?? "Unknown"
        return "\(deviceName) (\(vendorName))"
    }
}
