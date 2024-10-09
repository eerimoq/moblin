import AVFoundation
import MetalPetal
import SwiftUI
import UIKit
import Vision
import WebKit

private let browserQueue = DispatchQueue(label: "com.eerimoq.widget.browser")

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
    private var overlay: CIImage?
    private var layersMetalPetal: [MTILayer] = []
    private var image: UIImage?
    private let videoSize: CGSize
    private var x: Double
    private var y: Double
    let width: Double
    let height: Double
    let url: URL
    var isLoaded: Bool
    let audioOnly: Bool
    var fps: Float
    private var scaleToFitVideo: Bool
    private var snapshotTimer: Timer?
    var startLoadingTime = ContinuousClock.now
    private var scale = UIScreen().scale
    private var defaultEnabled = true
    private var crops: [WidgetCrop] = []
    private var cropsMetalPetal: [WidgetCrop] = []
    private let settingName: String

    init(
        url: URL,
        styleSheet: String,
        widget: SettingsWidgetBrowser,
        videoSize: CGSize,
        settingName: String
    ) {
        scaleToFitVideo = widget.scaleToFitVideo!
        self.url = url
        self.videoSize = videoSize
        self.settingName = settingName
        fps = widget.fps!
        isLoaded = false
        x = .nan
        y = .nan
        audioOnly = widget.audioOnly!
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
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height),
                            configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        super.init()
    }

    override func getName() -> String {
        return "\(settingName) browser widget"
    }

    var host: String {
        url.host() ?? "?"
    }

    var progress: Int {
        Int(100 * webView.estimatedProgress)
    }

    deinit {
        stopTakeSnapshots()
    }

    func stop() {
        stopTakeSnapshots()
    }

    func reload() {
        webView.reload()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?, crops: [WidgetCrop]) {
        let enabled = !(sceneWidget == nil && crops.isEmpty)
        if enabled {
            if let sceneWidget {
                x = toPixels(sceneWidget.x, videoSize.width)
                y = toPixels(sceneWidget.y, videoSize.height)
                defaultEnabled = sceneWidget.enabled
            } else {
                x = 0
                y = 0
                defaultEnabled = false
            }
            self.crops = crops.map { WidgetCrop(
                position: .init(x: toPixels($0.position.x, videoSize.width),
                                y: toPixels($0.position.y, videoSize.height)),
                crop: .init(
                    x: $0.crop.origin.x,
                    y: height - $0.crop.height - $0.crop.origin.y,
                    width: $0.crop.width,
                    height: $0.crop.height
                )
            ) }
            cropsMetalPetal = crops.map { WidgetCrop(
                position: .init(x: toPixels($0.position.x, videoSize.width) + $0.crop.width / 2,
                                y: toPixels($0.position.y, videoSize.height) + $0.crop.height / 2),
                crop: .init(
                    x: $0.crop.minX,
                    y: $0.crop.minY,
                    width: $0.crop.width,
                    height: $0.crop.height
                )
            ) }
            if !isLoaded {
                startLoadingTime = .now
                webView.load(URLRequest(url: url))
                isLoaded = true
            }
        } else if isLoaded {
            x = .nan
            y = .nan
            image = nil
            overlay = nil
            layersMetalPetal.removeAll()
            webView.loadHTMLString("<html></html>", baseURL: nil)
            isLoaded = false
        }
        stopTakeSnapshots()
        if enabled {
            startTakeSnapshots()
        }
    }

    private func startTakeSnapshots() {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: Double(1 / fps), repeats: false, block: { _ in
            guard !self.audioOnly else {
                return
            }
            let configuration = WKSnapshotConfiguration()
            if self.scaleToFitVideo {
                configuration.snapshotWidth = NSNumber(value: self.videoSize.width / self.scale)
            } else {
                configuration.snapshotWidth = NSNumber(value: self.width / self.scale)
            }
            self.webView.takeSnapshot(with: configuration) { image, error in
                self.startTakeSnapshots()
                if let error {
                    logger.warning("Browser snapshot error: \(error)")
                } else if let image {
                    self.setImage(image: image)
                } else {
                    logger.warning("No browser image")
                }
            }
        })
    }

    private func stopTakeSnapshots() {
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    func setImage(image: UIImage) {
        browserQueue.sync {
            self.image = image
        }
    }

    private func moveDefault(image: CIImage) -> CIImage {
        if scaleToFitVideo {
            return image
        }
        return image.transformed(by: CGAffineTransform(
            translationX: x,
            y: videoSize.height - height - y
        ))
    }

    private func getImage() -> CIImage? {
        var newImage: UIImage?
        browserQueue.sync {
            if self.image != nil {
                newImage = self.image
                self.image = nil
            }
        }
        guard let newImage else {
            return nil
        }
        guard x != .nan && y != .nan else {
            return nil
        }
        return CIImage(image: newImage)
    }

    private func updateOverlay() {
        guard let image = getImage() else {
            return
        }
        overlay = image
        if defaultEnabled {
            overlay = moveDefault(image: image)
        }
        for (i, crop) in crops.enumerated() {
            var cropped = image.cropped(to: crop.crop)
            cropped = cropped.transformed(by: CGAffineTransform(
                translationX: -crop.crop.origin.x,
                y: -crop.crop.origin.y
            ))
            cropped = cropped.transformed(by: CGAffineTransform(
                translationX: crop.position.x,
                y: videoSize.height - crop.crop.height - crop.position.y
            ))
            if i == 0 && !defaultEnabled {
                overlay = cropped
            } else {
                let filter = CIFilter.sourceOverCompositing()
                filter.inputImage = cropped
                filter.backgroundImage = overlay
                overlay = filter.outputImage
            }
        }
    }

    private func positionDefaultMetalPetal(image _: MTIImage) -> CGPoint {
        if scaleToFitVideo {
            return .init(x: videoSize.width / 2, y: videoSize.height / 2)
        }
        return .init(x: width / 2 + x, y: height / 2 + y)
    }

    private func updateOverlayMetalPetal() {
        guard let newImage = getImage() else {
            return
        }
        layersMetalPetal.removeAll()
        let image = MTIImage(ciImage: newImage, isOpaque: true)
        if defaultEnabled {
            let position = positionDefaultMetalPetal(image: image)
            layersMetalPetal.append(.init(content: image, position: position))
        }
        for crop in cropsMetalPetal {
            guard let cropped = image.cropped(to: crop.crop) else {
                continue
            }
            layersMetalPetal.append(.init(content: cropped, position: crop.position))
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        updateOverlay()
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }

    override func executeMetalPetal(_ image: MTIImage?, _: VideoEffectInfo) -> MTIImage? {
        updateOverlayMetalPetal()
        guard let image, !layersMetalPetal.isEmpty else {
            return image
        }
        let filter = MTIMultilayerCompositingFilter()
        filter.inputBackgroundImage = image
        filter.layers = layersMetalPetal
        return filter.outputImage
    }
}
