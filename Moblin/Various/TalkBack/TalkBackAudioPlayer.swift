import AVFoundation
import CoreMedia

class TalkBackAudioPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var isRunning = false

    init() {
        engine.attach(playerNode)
    }

    func start(format: AVAudioFormat) {
        guard !isRunning else {
            return
        }
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
            playerNode.play()
            isRunning = true
        } catch {
            logger.info("talk-back-audio-player: Failed to start engine: \(error)")
        }
    }

    func stop() {
        guard isRunning else {
            return
        }
        playerNode.stop()
        engine.stop()
        engine.detach(playerNode)
        engine.attach(playerNode)
        isRunning = false
    }

    func appendSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRunning else {
            return
        }
        guard let pcmBuffer = makePcmBuffer(from: sampleBuffer) else {
            return
        }
        playerNode.scheduleBuffer(pcmBuffer)
    }

    private func makePcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDescription = sampleBuffer.formatDescription,
              let asbd = formatDescription.audioStreamBasicDescription
        else {
            return nil
        }
        var mutableAsbd = asbd
        guard let format = AVAudioFormat(streamDescription: &mutableAsbd) else {
            return nil
        }
        let frameCount = AVAudioFrameCount(sampleBuffer.numSamples)
        guard frameCount > 0,
              let pcmBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)
        else {
            return nil
        }
        pcmBuffer.frameLength = frameCount
        var sizeNeeded = 0
        CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: &sizeNeeded,
            bufferListOut: nil,
            bufferListSize: 0,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: nil
        )
        guard sizeNeeded > 0 else {
            return nil
        }
        let listBytes = UnsafeMutableRawPointer.allocate(byteCount: sizeNeeded, alignment: 16)
        defer { listBytes.deallocate() }
        let list = listBytes.assumingMemoryBound(to: AudioBufferList.self)
        var blockBuffer: CMBlockBuffer?
        let status = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(
            sampleBuffer,
            bufferListSizeNeededOut: nil,
            bufferListOut: list,
            bufferListSize: sizeNeeded,
            blockBufferAllocator: nil,
            blockBufferMemoryAllocator: nil,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == noErr else {
            return nil
        }
        let srcList = UnsafeMutableAudioBufferListPointer(list)
        let dstList = UnsafeMutableAudioBufferListPointer(pcmBuffer.mutableAudioBufferList)
        for i in 0 ..< min(srcList.count, dstList.count) {
            guard let src = srcList[i].mData, let dst = dstList[i].mData else {
                continue
            }
            let byteCount = Int(min(srcList[i].mDataByteSize, dstList[i].mDataByteSize))
            dst.copyMemory(from: src, byteCount: byteCount)
        }
        return pcmBuffer
    }
}
