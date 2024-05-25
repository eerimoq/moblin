import ReplayKit

class SampleHandler: RPBroadcastSampleHandler {
    var sampleBufferSender = SampleBufferSender()

    override func broadcastStarted(withSetupInfo _: [String: NSObject]?) {
        sampleBufferSender.start(appGroup: moblinAppGroup)
    }

    override func broadcastPaused() {}

    override func broadcastResumed() {}

    override func broadcastFinished() {
        sampleBufferSender.stop()
    }

    override func processSampleBuffer(
        _ sampleBuffer: CMSampleBuffer,
        with sampleBufferType: RPSampleBufferType
    ) {
        switch sampleBufferType {
        case RPSampleBufferType.video:
            sampleBufferSender.send(sampleBuffer, sampleBufferType)
        case RPSampleBufferType.audioApp:
            sampleBufferSender.send(sampleBuffer, sampleBufferType)
        case RPSampleBufferType.audioMic:
            break
        default:
            break
        }
    }
}
