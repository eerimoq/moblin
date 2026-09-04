import AppKit

@MainActor
@objc(MoblinMacStatusItem)
final class MoblinMacStatusItem: NSObject, MacStatusItem {
    private var statusItem: NSStatusItem?
    private weak var delegate: MacStatusItemDelegate?
    private var icon: NSImage?
    private let statusMenuItem = NSMenuItem()
    private let streamMenuItem = NSMenuItem()
    private let recordingMenuItem = NSMenuItem()

    func start(iconData: Data, delegate: MacStatusItemDelegate) {
        self.delegate = delegate
        icon = NSImage(data: iconData)
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = makeMenu()
        self.statusItem = statusItem
    }

    func update(isLive: Bool,
                isRecording: Bool,
                statusTitle: String,
                streamTitle: String,
                recordingTitle: String)
    {
        statusItem?.button?.image = makeImage(isLive: isLive, isRecording: isRecording)
        statusMenuItem.title = statusTitle
        streamMenuItem.title = streamTitle
        recordingMenuItem.title = recordingTitle
    }

    func stop() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        delegate = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        streamMenuItem.target = self
        streamMenuItem.action = #selector(toggleStream)
        menu.addItem(streamMenuItem)
        recordingMenuItem.target = self
        recordingMenuItem.action = #selector(toggleRecording)
        menu.addItem(recordingMenuItem)
        return menu
    }

    private func makeImage(isLive: Bool, isRecording: Bool) -> NSImage? {
        guard let icon, icon.size.height > 0 else {
            return nil
        }
        let width = 18 * icon.size.width / icon.size.height
        let imageWidth = width + (isLive || isRecording ? 8 : 0)
        return NSImage(size: NSSize(width: imageWidth, height: 18), flipped: false) { _ in
            icon.draw(in: NSRect(x: 0, y: 0, width: width, height: 18))
            if isLive {
                drawDot(y: 8.5, fill: .systemRed)
            }
            if isRecording {
                drawDot(y: 0.5, fill: .textColor)
            }
            return true
        }
    }

    @objc private func toggleStream() {
        delegate?.macStatusItemToggleStream()
    }

    @objc private func toggleRecording() {
        delegate?.macStatusItemToggleRecording()
    }
}

private func drawDot(y: Double, fill: NSColor) {
    let rect = NSRect(x: 17, y: y, width: 5, height: 5)
    let path = NSBezierPath(ovalIn: rect)
    fill.setFill()
    path.fill()
}
