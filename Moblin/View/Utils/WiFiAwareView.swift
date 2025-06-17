#if canImport(DeviceDiscoveryUI)
    import DeviceDiscoveryUI
    import Network
    import SwiftUI
    import WiFiAware

    private let serviceName = "_moblin._udp"

    @available(iOS 26.0, *)
    struct WiFiAwarePublisherView: View {
        private let service = WAPublishableService.allServices[serviceName]!

        var body: some View {
            DevicePairingView(.wifiAware(.connecting(to: service, from: .selected([])))) {
                Text("Wi-Fi Aware publish")
            } fallback: {
                Text("Wi-Fi Aware unavailable")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
    }

    @available(iOS 26.0, *)
    struct WiFiAwareSubscriberView: View {
        private let service = WASubscribableService.allServices[serviceName]!

        var body: some View {
            DevicePicker(.wifiAware(.connecting(to: .selected([]), from: service))) { endpoint in
                logger.info("Paired Endpoint: \(endpoint)")
            } label: {
                Text("Wi-Fi Aware subscribe")
            } fallback: {
                Text("Wi-Fi Aware unavailable")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.extraLarge)
        }
    }
#endif
