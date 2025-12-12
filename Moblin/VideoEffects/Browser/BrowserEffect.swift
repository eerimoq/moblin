import AVFoundation
import SwiftUI
import UIKit
import Vision
import WebKit

struct WidgetCrop {
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
    return loadStringResource(name: "video", ext: "js")
}

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

final class BrowserEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    let webView: WKWebView
    private var snapshot: CIImage?
    private let videoSize: CGSize
    let width: Double
    let height: Double
    private let url: URL
    private(set) var isLoaded: Bool
    private let audioAndVideoOnly: Bool
    private var baseFps: Double
    private var fps: Double
    private let snapshotTimer = SimpleTimer(queue: .main)
    var startLoadingTime = ContinuousClock.now
    private let scale: Double
    private var sceneWidget: SettingsSceneWidget?
    private var crops: [WidgetCrop] = []
    private let settingName: String
    private let server: BrowserEffectServer
    private var stopped = false
    private var suspended = false
    private let snapshotConfiguration: WKSnapshotConfiguration

    init(
        url: URL,
        styleSheet: String,
        widget: SettingsWidgetBrowser,
        videoSize: CGSize,
        settingName: String,
        moblinAccess: Bool
    ) {
        if isMac() {
            scale = 2
        } else {
            scale = UIScreen().scale
        }
        self.url = url
        self.videoSize = videoSize
        self.settingName = settingName
        baseFps = Double(widget.baseFps)
        fps = baseFps
        isLoaded = false
        audioAndVideoOnly = widget.audioAndVideoOnly
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
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        stopTakeSnapshots()
    }

    override func getName() -> String {
        return "\(settingName) browser widget"
    }

    override func isEnabled() -> Bool {
        return snapshot != nil
    }

    func sendChatMessage(post: ChatPost) {
        server.sendChatMessage(post: post)
    }

    var host: String {
        url.host() ?? "?"
    }

    var progress: Int {
        Int(100 * webView.estimatedProgress)
    }

    func stop() {
        stopTakeSnapshots()
    }

    func reload() {
        webView.reload()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?, crops: [WidgetCrop]) {
        stopTakeSnapshots()
        if sceneWidget != nil || !crops.isEmpty {
            setSceneWidgetEnabled(sceneWidget: sceneWidget, crops: crops)
        } else if isLoaded {
            setSceneWidgetLoaded()
        }
    }

    override func execute(_ image: CIImage, _ info: VideoEffectInfo) -> CIImage {
        guard let snapshot else {
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

    private func setSceneWidgetLoaded() {
        processorPipelineQueue.async {
            self.snapshot = nil
        }
        webView.loadHTMLString("<html></html>", baseURL: nil)
        server.disable()
        isLoaded = false
    }

    private func startTakeSnapshots() {
        guard !stopped, !audioAndVideoOnly else {
            return
        }
        resumeTakeSnapshots()
    }

    private func stopTakeSnapshots() {
        stopped = true
        snapshotTimer.stop()
    }

    private func suspendTakeSnapshots() {
        suspended = true
        snapshotTimer.stop()
        processorPipelineQueue.async { [weak self] in
            self?.snapshot = nil
        }
    }

    private func resumeTakeSnapshots() {
        suspended = false
        takeSnapshots(takeSnapshotTime: 0)
    }

    private func takeSnapshots(takeSnapshotTime: Double) {
        snapshotTimer.startSingleShot(timeout: max(1 / fps - takeSnapshotTime, 0.001)) { [weak self] in
            guard let self else {
                return
            }
            let takeSnapshotBeginTime = ContinuousClock.now
            self.webView.takeSnapshot(with: snapshotConfiguration) { [weak self] image, _ in
                guard let self, !stopped, !suspended else {
                    return
                }
                let takeSnapshotTime = takeSnapshotBeginTime.duration(to: .now)
                takeSnapshots(takeSnapshotTime: takeSnapshotTime.seconds)
                guard let image else {
                    return
                }
                processorPipelineQueue.async {
                    self.snapshot = CIImage(image: image)
                }
            }
        }
    }
}

extension BrowserEffect: BrowserEffectServerDelegate {
    func browserEffectServerVideoPlaying() {
        fps = 30
        resumeTakeSnapshots()
    }

    func browserEffectServerVideoEnded() {
        fps = baseFps
        guard audioAndVideoOnly else {
            return
        }
        suspendTakeSnapshots()
    }
}
