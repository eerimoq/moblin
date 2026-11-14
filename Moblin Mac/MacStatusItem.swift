import Foundation

@MainActor
@objc(MacStatusItemDelegate) protocol MacStatusItemDelegate: NSObjectProtocol {
    func macStatusItemToggleStream()
    func macStatusItemToggleRecording()
}

@MainActor
@objc(MacStatusItem) protocol MacStatusItem: NSObjectProtocol {
    func start(iconData: Data, delegate: MacStatusItemDelegate)
    func update(isLive: Bool,
                isRecording: Bool,
                statusTitle: String,
                streamTitle: String,
                recordingTitle: String)
    func stop()
}
