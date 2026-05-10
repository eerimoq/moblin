#if targetEnvironment(macCatalyst)
import AVFoundation
import ScreenCaptureKit

protocol MacScreenCaptureDelegate: AnyObject {
    func macScreenCaptureDidStart(latency: Double)
    func macScreenCaptureDidStop()
    func macScreenCaptureDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

@available(macCatalyst 18.2, *)
class MacScreenCapture: NSObject, @unchecked Sendable {
    static let shared = MacScreenCapture()
    weak var delegate: (any MacScreenCaptureDelegate)?
    private var stream: SCStream?

    func start(fps: Float64) {
        Task { @MainActor in
            await startInternal(fps: fps)
        }
    }

    func stop() {
        Task { @MainActor in
            await stopInternal()
        }
    }

    @MainActor
    private func startInternal(fps: Float64) async {
        do {
            let (filter, display) = try await makeContentFilter()
            let config = SCStreamConfiguration()
            config.captureResolution = .best
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(fps.rounded()))
            config.pixelFormat = kCVPixelFormatType_32BGRA
            let scale = Int(screenScale())
            config.width = display.width * scale
            config.height = display.height * scale
            logger.info("mac-screen-capture: \(Int(fps)) FPS, \(config.width)x\(config.height) pixels")
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: processorPipelineQueue)
            try await stream.startCapture()
            self.stream = stream
            delegate?.macScreenCaptureDidStart(latency: 0.1)
        } catch {
            logger.info("mac-screen-capture: Failed to start: \(error.localizedDescription)")
        }
    }

    private func stopInternal() async {
        do {
            try await stream?.stopCapture()
        } catch {
            logger.info("mac-screen-capture: Failed to stop: \(error.localizedDescription)")
        }
        stream = nil
        delegate?.macScreenCaptureDidStop()
    }

    private func makeContentFilter() async throws -> (SCContentFilter, SCDisplay) {
        while true {
            try await sleep(milliSeconds: 100)
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first else {
                continue
            }
            var excludedApplications = content.applications
                .filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            guard !excludedApplications.isEmpty else {
                continue
            }
            excludedApplications = []
            return (SCContentFilter(
                display: display,
                excludingApplications: excludedApplications,
                exceptingWindows: []
            ), display)
        }
    }
}

@available(macCatalyst 18.2, *)
extension MacScreenCapture: SCStreamOutput {
    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of _: SCStreamOutputType) {
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp + CMTime(seconds: 0.1)
        guard let sampleBuffer = sampleBuffer.replacePresentationTimeStamp(presentationTimeStamp) else {
            return
        }
        delegate?.macScreenCaptureDidOutputSampleBuffer(sampleBuffer)
    }
}

@available(macCatalyst 18.2, *)
extension MacScreenCapture: SCStreamDelegate {
    func stream(_: SCStream, didStopWithError error: any Error) {
        logger.info("mac-screen-capture: Stopped with error: \(error.localizedDescription)")
        delegate?.macScreenCaptureDidStop()
    }
}
#endif
