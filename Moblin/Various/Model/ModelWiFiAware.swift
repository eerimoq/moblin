import WiFiAware

@available(iOS 26, *)
extension Model {
    func wiFiAwareUpdated() {
        stopWiFiAware()
        if database.wiFiAware.enabled, WACapabilities.supportedFeatures.contains(.wifiAware) {
            startWiFiAware()
        }
    }

    private func startWiFiAware() {
        switch database.wiFiAware.role {
        case .sender:
            wiFiAwareSenderTask = Task {
                do {
                    try await WiFiAwareSender.shared.browse()
                } catch {
                    logger.info("wifi: Sender error: \(error)")
                }
            }
        case .receiver:
            wiFiAwareReceiverTask = Task {
                do {
                    try await WiFiAwareReceiver.shared.listen()
                } catch {
                    logger.info("wifi: Receiver error: \(error)")
                }
            }
        }
    }

    private func stopWiFiAware() {
        wiFiAwareSenderTask?.cancel()
        wiFiAwareSenderTask = nil
        wiFiAwareReceiverTask?.cancel()
        wiFiAwareReceiverTask = nil
    }
}
