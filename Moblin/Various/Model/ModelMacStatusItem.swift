import Foundation
import UIKit

#if targetEnvironment(macCatalyst)

extension Model: MacStatusItemDelegate {
    func setupMacStatusItem() {
        guard let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("MoblinMac.bundle"),
              let bundle = Bundle(url: url),
              bundle.load(),
              let principalClass = bundle.principalClass as? NSObject.Type,
              let statusItem = principalClass.init() as? MacStatusItem,
              let iconData = UIImage(named: "AppIconNoBackground")?.pngData()
        else {
            logger.info("mac-status-item: Failed to load helper bundle")
            return
        }
        macStatusItem = statusItem
        statusItem.start(iconData: iconData, delegate: self)
        updateMacStatusItem()
    }

    func updateMacStatusItem() {
        macStatusItem?.update(
            isLive: isLive,
            isRecording: isRecording,
            statusTitle: makeMacStatusItemStatusTitle(),
            streamTitle: isLive ? String(localized: "Stop live stream") : String(localized: "Go Live"),
            recordingTitle: isRecording ? String(localized: "Stop recording") :
                String(localized: "Start recording")
        )
    }

    func stopMacStatusItem() {
        macStatusItem?.stop()
        macStatusItem = nil
    }

    func macStatusItemToggleStream() {
        toggleStream()
    }

    func macStatusItemToggleRecording() {
        toggleRecording()
    }

    private func makeMacStatusItemStatusTitle() -> String {
        var titles: [String] = []
        if isLive {
            titles.append(String(localized: "Live"))
        }
        if isRecording {
            titles.append(String(localized: "Recording"))
        }
        if titles.isEmpty {
            titles.append(String(localized: "Idle"))
        }
        return titles.joined(separator: ", ")
    }
}

#else

extension Model {
    func setupMacStatusItem() {}

    func updateMacStatusItem() {}

    func stopMacStatusItem() {}
}

#endif
