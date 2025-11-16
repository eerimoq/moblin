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

final class BrowserEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    let webView: WKWebView
    private var snapshot: CIImage?
    private let videoSize: CGSize
    let width: Double
    let height: Double
    let url: URL
    var isLoaded: Bool
    let audioOnly: Bool
    var fps: Float
    private let snapshotTimer = SimpleTimer(queue: .main)
    var startLoadingTime = ContinuousClock.now
    private let scale: Double
    private var sceneWidget: SettingsSceneWidget?
    private var crops: [WidgetCrop] = []
    private let settingName: String
    private let server: BrowserEffectServer
    private var stopped = false

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
        fps = widget.fps
        isLoaded = false
        audioOnly = widget.audioOnly
        if audioOnly {
            width = 1
            height = 1
        } else {
            width = Double(widget.width)
            height = Double(widget.height)
        }
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = false
        configuration.mediaTypesRequiringUserActionForPlayback = []
        if let source = createStyleSheetSource(styleSheet: styleSheet) {
            configuration.userContentController.addUserScript(.init(
                source: source,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: false
            ))
        }
        server = BrowserEffectServer()
        if moblinAccess {
            server.addScript(configuration: configuration)
        }
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height),
                            configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        super.init()
        server.webView = webView
    }

    deinit {
        stopTakeSnapshots()
    }

    override func getName() -> String {
        return "\(settingName) browser widget"
    }

    override func isEnabled() -> Bool {
        return !audioOnly
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
        isLoaded = false
    }

    private func startTakeSnapshots() {
        guard !stopped else {
            return
        }
        snapshotTimer.startSingleShot(timeout: Double(1 / fps)) { [weak self] in
            guard let self else {
                return
            }
            guard !self.audioOnly else {
                return
            }
            let configuration = WKSnapshotConfiguration()
            configuration.snapshotWidth = NSNumber(value: self.width / self.scale)
            self.webView.takeSnapshot(with: configuration) { [weak self] image, error in
                guard let self else {
                    return
                }
                guard !self.stopped else {
                    return
                }
                self.startTakeSnapshots()
                if let error {
                    logger.warning("Browser snapshot error: \(error)")
                } else if let image {
                    processorPipelineQueue.async {
                        self.snapshot = CIImage(image: image)
                    }
                } else {
                    logger.warning("No browser image")
                }
            }
        }
    }

    private func stopTakeSnapshots() {
        stopped = true
        snapshotTimer.stop()
    }
}
