#if targetEnvironment(macCatalyst)
import AVFoundation
import ScreenCaptureKit

protocol MacScreenCaptureDelegate: AnyObject {
    func macScreenCaptureDidStart()
    func macScreenCaptureDidStop()
    func macScreenCaptureDidOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

class MacScreenCapture: NSObject {
    weak var delegate: MacScreenCaptureDelegate?
    private var stream: SCStream?
    private var isRunning = false

    func start() {
        guard !isRunning else {
            return
        }
        Task {
            await startCapture()
        }
    }

    func stop() {
        guard isRunning else {
            return
        }
        Task {
            await stopCapture()
        }
    }

    private func startCapture() async {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first else {
                logger.info("mac-screen-capture: No displays found")
                return
            }
            let config = SCStreamConfiguration()
            config.width = display.width * 2
            config.height = display.height * 2
            config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
            config.pixelFormat = kCVPixelFormatType_32BGRA
            config.showsCursor = true
            let filter = SCContentFilter(
                display: display,
                excludingApplications: [],
                exceptingWindows: []
            )
            let stream = SCStream(filter: filter, configuration: config, delegate: self)
            try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: .global(qos: .userInteractive))
            try await stream.startCapture()
            self.stream = stream
            isRunning = true
            delegate?.macScreenCaptureDidStart()
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
        isRunning = false
        delegate?.macScreenCaptureDidStop()
    }
}

extension MacScreenCapture: SCStreamOutput {
    func stream(
        _: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        guard type == .screen else {
            return
        }
        guard sampleBuffer.isValid else {
            return
        }
        delegate?.macScreenCaptureDidOutputSampleBuffer(sampleBuffer)
    }
}

extension MacScreenCapture: SCStreamDelegate {
    func stream(_: SCStream, didStopWithError error: any Error) {
        logger.info("mac-screen-capture: Stopped with error: \(error.localizedDescription)")
        isRunning = false
        delegate?.macScreenCaptureDidStop()
    }
}
#endif
