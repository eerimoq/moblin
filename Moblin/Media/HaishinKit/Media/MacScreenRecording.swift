#if targetEnvironment(macCatalyst)
import AVFoundation
import ScreenCaptureKit

protocol MacScreenRecordingDelegate: AnyObject {
    func macScreenRecordingDidStart(latency: Double)
    func macScreenRecordingDidStop()
    func macScreenRecordingDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

@available(macCatalyst 18.2, *)
class MacScreenRecording: NSObject {
    static let shared = MacScreenRecording()
    weak var delegate: MacScreenRecordingDelegate?
    private var stream: SCStream?

    func start(fps: Float64) {
        Task {
            await startInternal(fps: fps)
        }
    }

    func stop() {
        Task {
            await stopInternal()
        }
    }

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
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: processorPipelineQueue)
            try await stream.startCapture()
            self.stream = stream
            delegate?.macScreenRecordingDidStart(latency: 0.1)
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
        delegate?.macScreenRecordingDidStop()
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
extension MacScreenRecording: SCStreamOutput {
    func stream(_: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of _: SCStreamOutputType) {
        let presentationTimeStamp = sampleBuffer.presentationTimeStamp + CMTime(seconds: 0.1)
        guard let sampleBuffer = sampleBuffer.replacePresentationTimeStamp(presentationTimeStamp) else {
            return
        }
        delegate?.macScreenRecordingDidOutputSampleBuffer(sampleBuffer)
    }
}

@available(macCatalyst 18.2, *)
extension MacScreenRecording: SCStreamDelegate {
    func stream(_: SCStream, didStopWithError error: any Error) {
        logger.info("mac-screen-capture: Stopped with error: \(error.localizedDescription)")
        delegate?.macScreenRecordingDidStop()
    }
}
#endif
