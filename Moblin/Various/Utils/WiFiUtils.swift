import Foundation
import NetworkExtension

#if targetEnvironment(macCatalyst)
private func fetchCurrentWiFiSsidCoreWlan() -> String? {
    guard dlopen("/System/Library/Frameworks/CoreWLAN.framework/CoreWLAN", RTLD_NOW) != nil,
          let clientClass = NSClassFromString("CWWiFiClient") as? NSObject.Type
    else {
        return nil
    }
    let client = clientClass.perform(NSSelectorFromString("sharedWiFiClient"))?.takeUnretainedValue()
    let interface = client?.perform(NSSelectorFromString("interface"))?.takeUnretainedValue()
    return interface?.perform(NSSelectorFromString("ssid"))?.takeUnretainedValue() as? String
}
#endif

@MainActor
func fetchCurrentWiFiSsid(onCompleted: @escaping @MainActor (String?) -> Void) {
    #if targetEnvironment(macCatalyst)
    onCompleted(fetchCurrentWiFiSsidCoreWlan())
    #else
    NEHotspotNetwork.fetchCurrent { network in
        let ssid = network?.ssid
        DispatchQueue.main.async {
            onCompleted(ssid)
        }
    }
    #endif
}
