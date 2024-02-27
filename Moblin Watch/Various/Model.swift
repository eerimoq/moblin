import Foundation
import WatchConnectivity

class Model: NSObject, ObservableObject {
    func setup() {
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        } else {
            print("Not good!")
        }
    }
}

extension Model: WCSessionDelegate {
    func session(
        _: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error _: Error?
    ) {
        switch activationState {
        case .activated:
            print("Connectivity activated")
        case .inactive:
            print("Connectivity inactive")
        case .notActivated:
            print("Connectivity not activated")
        default:
            print("Connectivity unknown state")
        }
    }

    func session(_: WCSession, didReceiveMessage message: [String: Any]) {
        for entry in message {
            print("Got: \(entry.key) \(entry.value)")
        }
    }
}
