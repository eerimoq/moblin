import AVFoundation
import HaishinKit
import SwiftUI
import UIKit
import WebKit

private let browserQueue = DispatchQueue(label: "com.eerimoq.widget.browser")

final class BrowserEffect: VideoEffect {
    private let filter = CIFilter.sourceOverCompositing()
    let webView: WKWebView
    private var overlay: CIImage?
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

    init(url: URL, widget: SettingsWidgetBrowser, videoSize: CGSize) {
        scaleToFitVideo = widget.scaleToFitVideo!
        self.url = url
        self.videoSize = videoSize
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
        configuration.mediaTypesRequiringUserActionForPlayback = []
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: width, height: height),
                            configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        // super.init()
        // logger.debug("browser-widget: \(host): Init")
    }

    var host: String {
        url.host() ?? "?"
    }

    var progress: Int {
        Int(100 * webView.estimatedProgress)
    }

    deinit {
        // logger.debug("browser-widget: \(host): Deinit")
        stopTakeSnapshots()
    }

    func stop() {
        stopTakeSnapshots()
    }

    func reload() {
        webView.reload()
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget?) {
        if let sceneWidget {
            x = (videoSize.width * sceneWidget.x) / 100
            y = (videoSize.height * sceneWidget.y) / 100
            if !isLoaded {
                webView.load(URLRequest(url: url))
                isLoaded = true
            }
        } else if isLoaded {
            x = .nan
            y = .nan
            image = nil
            overlay = nil
            // logger.debug("browser-widget: \(self.host): Loading empty page")
            webView.loadHTMLString("<html></html>", baseURL: nil)
            isLoaded = false
        }
        stopTakeSnapshots()
        if sceneWidget != nil {
            startTakeSnapshots()
        }
    }

    private func startTakeSnapshots() {
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: Double(1 / fps), repeats: true, block: { _ in
            // if self.webView.isLoading {
            // logger.debug("browser-widget: \(self.host): \(self.progress)% loaded")
            // }
            guard !self.audioOnly else {
                return
            }
            let configuration = WKSnapshotConfiguration()
            // Why is scale needed? Is it always 3? Probably makes resolution 1/3 of actual.
            if self.scaleToFitVideo {
                configuration.snapshotWidth = NSNumber(value: self.videoSize.width / 3)
            } else {
                configuration.snapshotWidth = NSNumber(value: self.width / 3)
            }
            self.webView.takeSnapshot(with: configuration) { image, error in
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

    private func updateOverlay() {
        var newImage: UIImage?
        browserQueue.sync {
            if self.image != nil {
                newImage = self.image
                self.image = nil
            }
        }
        guard let newImage else {
            return
        }
        guard x != .nan && y != .nan else {
            return
        }
        overlay = CIImage(image: newImage)
        if !scaleToFitVideo && overlay != nil {
            overlay = overlay!.transformed(by: CGAffineTransform(
                translationX: x,
                y: videoSize.height - height - y
            ))
        }
    }

    override func execute(_ image: CIImage, info _: CMSampleBuffer?) -> CIImage {
        updateOverlay()
        filter.inputImage = overlay
        filter.backgroundImage = image
        return filter.outputImage ?? image
    }
}
