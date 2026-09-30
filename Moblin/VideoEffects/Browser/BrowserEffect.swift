import Collections
import MetalPetal
import SwiftUI
import Vision
import WebKit

struct WidgetCrop: @unchecked Sendable {
    let crop: SettingsWidgetCrop
    let sceneWidget: SettingsSceneWidget
}

private func createStyleSheetSource(styleSheet: String) -> String? {
    guard !styleSheet.isEmpty else {
        return nil
    }
    guard let styleSheetData = styleSheet.data(using: .utf8) else {
        logger.info("Failed to encode browser style sheet to UTF-8.")
        return nil
    }
    return """
    var style = document.createElement('style');
    style.type = 'text/css';
    style.innerHTML = window.atob('\(styleSheetData.base64EncodedString())');
    document.head.appendChild(style);
    """
}

private func videoScript() -> String {
    loadStringResource(name: "video", ext: "js")
}

@MainActor
private func addScript(_ configuration: WKWebViewConfiguration,
                       _ script: String,
                       _ injectionTime: WKUserScriptInjectionTime)
{
    configuration.userContentController.addUserScript(.init(
        source: script,
        injectionTime: injectionTime,
        forMainFrameOnly: false
    ))
}

final class BrowserEffect: VideoEffect, ObservableObject, @unchecked Sendable {
    let webView: WKWebView
    private var snapshot: EffectImageCgImage?
    private var snapshotQueue: Deque<EffectImageCgImage> = []
    let width: Double
    let height: Double
    private let url: URL
    private(set) var isLoaded: Bool
    @Published private(set) var layout: SettingsWidgetLayout?
    private let mode: SettingsWidgetBrowserMode
    private var baseFps: Double
    private var fps: Double
    private let snapshotTimer = MainTimer()
    private var snapshotInProgress = false
    private var nextSnapshotTime = ContinuousClock.now
    var startLoadingTime = ContinuousClock.now
    private let scale: Double
    private var sceneWidget: SettingsSceneWidget?
    private var crops: [WidgetCrop] = []
    private let server: BrowserEffectServer
    private let speechToText: Bool
    private var stopped = false
    private var suspended: Bool
    private let snapshotConfiguration: WKSnapshotConfiguration
    private let userContentController: WKUserContentController

    @MainActor
    init(
        url: URL,
        styleSheet: String,
        widget: SettingsWidgetBrowser,
        moblinAccess: Bool,
        proxyServer: NWEndpoint?
    ) {
        scale = screenScale()
        self.url = url
        baseFps = Double(widget.baseFps)
        fps = baseFps
        isLoaded = false
        if widget.localOnly {
            mode = .audioOnly
        } else {
            mode = widget.mode
        }
        suspended = mode != .periodicAudioAndVideo
        speechToText = widget.speechToText
        width = Double(widget.width)
        height = Double(widget.height)
        snapshotConfiguration = WKSnapshotConfiguration()
        snapshotConfiguration.snapshotWidth = NSNumber(value: width / scale)
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        if let source = createStyleSheetSource(styleSheet: styleSheet) {
            addScript(configuration, source, .atDocumentEnd)
        }
        addScript(configuration, videoScript(), .atDocumentStart)
        configuration.setHttpProxy(endpoint: proxyServer)
        userContentController = configuration.userContentController
        server = BrowserEffectServer(configuration: configuration, moblinAccess: moblinAccess)
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height),
                            configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        super.init()
        server.webView = webView
        server.delegate = self
    }

    deinit {
        let userContentController = userContentController
        DispatchQueue.main.async {
            userContentController.removeAllScriptMessageHandlers()
        }
    }

    override func isEnabled() -> Bool {
        mode != .audioOnly && (snapshot != nil || !snapshotQueue.isEmpty)
    }

    @MainActor
    func sendChatMessage(post: ChatPost) {
        server.sendChatMessage(post: post)
    }

    @MainActor
    func sendSpeechToText(position: Int, text: String) {
        guard speechToText else {
            return
        }
        server.sendSpeechToText(position: position, text: text)
    }

    @MainActor
    func sendSpeechToTextClear() {
        guard speechToText else {
            return
        }
        server.sendSpeechToTextClear()
    }

    var host: String {
        url.host() ?? "?"
    }

    @MainActor
    var progress: Int {
        Int(100 * webView.estimatedProgress)
    }

    @MainActor
    func stop() {
        stopTakeSnapshots()
    }

    @MainActor
    func reload() {
        webView.reload()
    }

    @MainActor
    func setSceneWidget(sceneWidget: SettingsSceneWidget?, crops: [WidgetCrop]) {
        layout = sceneWidget?.layout
        stopTakeSnapshots()
        if sceneWidget != nil || !crops.isEmpty {
            setSceneWidgetEnabled(sceneWidget: sceneWidget, crops: crops)
        } else if isLoaded {
            setSceneWidgetLoaded()
        }
    }

    @MainActor
    func setProxyServer(endpoint: NWEndpoint?) {
        webView.configuration.setHttpProxy(endpoint: endpoint)
        reload()
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let snapshot = nextSnapshot()?.getCiImage() else {
            return image
        }
        var image = image
        if let sceneWidget {
            image = applyEffectsResizeMirrorMove(snapshot, sceneWidget, false, image.extent, info)
                .composited(over: image)
        }
        for crop in crops {
            let y = Int(snapshot.extent.height) - crop.crop.y - crop.crop.height
            image = snapshot
                .cropped(to: CGRect(x: crop.crop.x,
                                    y: y,
                                    width: crop.crop.width,
                                    height: crop.crop.height))
                .translated(x: -Double(crop.crop.x), y: Double(y))
                .resizeMirror(crop.sceneWidget.layout, image.extent.size, false)
                .move(crop.sceneWidget.layout, image.extent.size)
                .cropped(to: image.extent)
                .composited(over: image)
        }
        return image
    }

    override func executeMetalPetal(_ image: MTIImage, _ info: VideoEffectInfo) -> MTIImage {
        guard let snapshot = nextSnapshot()?.getMetalPetalImage() else {
            return image
        }
        var image = image
        if let sceneWidget {
            image = applyEffectsResizeMirrorMoveMetalPetal(snapshot,
                                                           sceneWidget,
                                                           false,
                                                           image,
                                                           info)
        }
        for crop in crops {
            let contentRegion = CGRect(x: crop.crop.x,
                                       y: crop.crop.y,
                                       width: crop.crop.width,
                                       height: crop.crop.height)
            image = snapshot.resizeMirrorMoveComposited(crop.sceneWidget.layout,
                                                        false,
                                                        image,
                                                        .init(contentRegion: contentRegion))
        }
        return image
    }

    private func nextSnapshot() -> EffectImageCgImage? {
        if let snapshot = snapshotQueue.popFirst() {
            self.snapshot = snapshot
        }
        return snapshot
    }

    private func clearSnapshots() {
        snapshot = nil
        snapshotQueue.removeAll()
    }

    @MainActor
    private func setSceneWidgetEnabled(sceneWidget: SettingsSceneWidget?, crops: [WidgetCrop]) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
            self.crops = crops
        }
        if !isLoaded {
            startLoadingTime = .now
            webView.load(URLRequest(url: url))
            server.enable()
            isLoaded = true
        }
        stopped = false
        startTakeSnapshots()
    }

    @MainActor
    private func setSceneWidgetLoaded() {
        processorPipelineQueue.async {
            self.clearSnapshots()
        }
        webView.loadHTMLString("<html></html>", baseURL: nil)
        server.disable()
        isLoaded = false
    }

    @MainActor
    private func startTakeSnapshots() {
        guard !suspended else {
            return
        }
        resumeTakeSnapshots()
    }

    @MainActor
    private func stopTakeSnapshots() {
        stopped = true
        snapshotTimer.stop()
    }

    @MainActor
    private func suspendTakeSnapshots() {
        suspended = true
        snapshotTimer.stop()
        processorPipelineQueue.async { [weak self] in
            self?.clearSnapshots()
        }
    }

    @MainActor
    private func resumeTakeSnapshots() {
        suspended = false
        guard !stopped else {
            return
        }
        nextSnapshotTime = .now
        scheduleSnapshot()
    }

    @MainActor
    private func scheduleSnapshot() {
        guard !snapshotInProgress else {
            return
        }
        let now = ContinuousClock.now
        let interval = Duration.seconds(1 / fps)
        nextSnapshotTime = max(nextSnapshotTime + interval, now - interval)
        let timeout = max(now.duration(to: nextSnapshotTime).seconds, 0)
        snapshotTimer.startSingleShot(timeout: timeout) { [weak self] in
            self?.takeSnapshot()
        }
    }

    @MainActor
    private func takeSnapshot() {
        snapshotInProgress = true
        webView.takeSnapshot(with: snapshotConfiguration) { [weak self] image, _ in
            guard let self else {
                return
            }
            snapshotInProgress = false
            guard !stopped, !suspended else {
                return
            }
            scheduleSnapshot()
            guard let snapshot = image?.cgImage?.toEffectImage() else {
                return
            }
            processorPipelineQueue.async {
                self.snapshotQueue.append(snapshot)
                if self.snapshotQueue.count > 2 {
                    self.snapshotQueue.removeFirst()
                }
            }
        }
    }
}

extension BrowserEffect: BrowserEffectServerDelegate {
    func browserEffectServerVideoPlaying() {
        fps = 30
        if mode != .audioOnly {
            resumeTakeSnapshots()
        }
    }

    func browserEffectServerVideoEnded() {
        fps = baseFps
        if mode == .periodicAudioAndVideo {
            resumeTakeSnapshots()
        } else {
            suspendTakeSnapshots()
        }
    }
}
