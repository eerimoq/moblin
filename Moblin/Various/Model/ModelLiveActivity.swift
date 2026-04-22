import ActivityKit
import Foundation

#if !targetEnvironment(macCatalyst)

extension Model {
    func startLiveActivity() {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }
        guard liveActivity == nil else {
            return
        }
        liveActivity = try? Activity.request(
            attributes: LiveActivityAttributes(),
            content: .init(state: makeState(), staleDate: nil)
        )
    }

    func stopLiveActivity() {
        let semaphore = DispatchSemaphore(value: 0)
        Task {
            await liveActivity?.end(nil, dismissalPolicy: .immediate)
            semaphore.signal()
        }
        semaphore.wait()
        liveActivity = nil
    }

    func updateLiveActivity() {
        let state = makeState()
        Task {
            await liveActivity?.update(.init(state: state, staleDate: nil))
        }
    }

    private func makeState() -> LiveActivityAttributes.ContentState {
        var functions: [LiveActionFunction] = []
        if isLive {
            functions.append(LiveActionFunction(image: "livephoto",
                                                text: String(localized: "Live")))
        }
        if isRecording {
            functions.append(LiveActionFunction(image: "record.circle",
                                                text: String(localized: "Recording")))
        }
        if database.chat.background {
            functions.append(LiveActionFunction(image: "bubble.left",
                                                text: String(localized: "Background chat")))
        }
        if database.moblink.relay.enabled {
            functions.append(LiveActionFunction(
                image: "app.connected.to.app.below.fill",
                text: String(localized: "Moblink relay")
            ))
        }
        if database.catPrinters.backgroundPrinting {
            functions.append(LiveActionFunction(image: "pawprint",
                                                text: String(localized: "Background printing")))
        }
        if functions.count <= 3 {
            return LiveActivityAttributes.ContentState(functions: functions, showEllipsis: false)
        } else {
            return LiveActivityAttributes.ContentState(functions: Array(functions.prefix(2)),
                                                       showEllipsis: true)
        }
    }
}

#else

extension Model {
    func startLiveActivity() {}

    func stopLiveActivity() {}

    func updateLiveActivity() {}
}

#endif
