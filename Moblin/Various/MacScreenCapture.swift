#if targetEnvironment(macCatalyst)

import AVFoundation
import ScreenCaptureKit

protocol MacScreenCaptureDelegate: AnyObject {
    func macScreenCaptureDidStart(latency: Double)
    func macScreenCaptureDidStop()
    func macScreenCaptureDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

@available(macCatalyst 18.2, *)
class MacScreenCapture: NSObject {
    static let shared = MacScreenCapture()
    weak var delegate: MacScreenCaptureDelegate?
    private var stream: SCStream?

    func start() {
        Task {
            await startCapture()
        }
    }

    func stop() {
        Task {
            await stopCapture()
        }
    }

    private func startCapture() async {
        do {
            let filter = try await makeContentFilter()
            let config = SCStreamConfiguration()
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: processorPipelineQueue)
            try await stream.startCapture()
            self.stream = stream
            delegate?.macScreenCaptureDidStart(latency: 0.1)
        } catch {
            logger.info("mac-screen-capture: Failed to start: \(error.localizedDescription)")
        }
    }

    private func stopCapture() async {
        do {
            try await stream?.stopCapture()
        } catch {
            logger.info("mac-screen-capture: Failed to stop: \(error.localizedDescription)")
        }
        stream = nil
        delegate?.macScreenCaptureDidStop()
    }

    private func makeContentFilter() async throws -> SCContentFilter {
        while true {
            try await sleep(milliSeconds: 100)
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first else {
                continue
            }
            let excludedApplications = content.applications
                .filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
            guard !excludedApplications.isEmpty else {
                continue
            }
            return SCContentFilter(
                display: display,
                excludingApplications: excludedApplications,
                exceptingWindows: []
            )
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
