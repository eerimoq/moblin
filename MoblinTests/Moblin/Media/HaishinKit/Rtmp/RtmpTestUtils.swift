import AVFoundation
@testable import Moblin
import Testing

final class RtmpModelMock {
    private let disconnected = MessageQueue<RtmpDisconnectReason>()
    private let connected = MessageQueue<Void>()
    private let lock = NSLock()
    private var disconnectedReasons: [RtmpDisconnectReason] = []

    func getDisconnectedReasons() -> [RtmpDisconnectReason] {
        lock.withLock { disconnectedReasons }
    }

    func waitForDisconnected() async -> RtmpDisconnectReason {
        await disconnected.get()
    }

    func waitForConnected() async {
        await connected.get()
    }
}

extension RtmpModelMock: RtmpStreamDelegate {
    func rtmpStreamConnected(_: RtmpStream) {
        logger.info("rtmp-test: Connected")
        connected.put(())
    }

    func rtmpStreamDisconnected(_: RtmpStream, reason: RtmpDisconnectReason) {
        logger.info("rtmp-test: Disconnected \(reason)")
        lock.withLock { disconnectedReasons.append(reason) }
        disconnected.put(reason)
    }
}

extension RtmpModelMock: ProcessorDelegate {
    func streamAudioLevel(audioLevel _: Float, numberOfAudioChannels _: Int, sampleRate _: Double) {}

    func streamBuiltinAudioNumberOfChannels(numberOfChannels _: Int) {}

    func streamLowFpsImage(lowFpsImage _: Data?, frameNumber _: UInt64) {}

    func streamVideoAttachCameraError() {}

    func streamVideoCaptureSessionError(_: String) {}

    func streamVideoBufferedVideoReady(cameraId _: UUID) {}

    func streamVideoBufferedVideoRemoved(cameraId _: UUID) {}

    func streamVideoFps(fps _: Int) {}

    func streamVideoEncoderResolution(resolution _: CGSize) {}

    func streamRecorderInitSegment(data _: Data) {}

    func streamRecorderDataSegment(segment _: Moblin.RecorderDataSegment) {}

    func streamRecorderFinished() {}

    func streamAudio(sampleBuffer _: CMSampleBuffer) {}

    func streamNoTorch() {}

    func streamPhotoTaken() {}

    func streamSetZoomX(x _: Float) {}

    func streamSetExposureBias(bias _: Float) {}

    func streamSelectedFps(auto _: Bool) {}
}

func makeAacFormat() -> AVAudioFormat {
    makeAudioFormat(formatId: kAudioFormatMPEG4AAC,
                    formatFlags: UInt32(MPEG4ObjectID.AAC_LC.rawValue),
                    framesPerPacket: 1024)
}

func makeOpusFormat() -> AVAudioFormat {
    makeAudioFormat(formatId: kAudioFormatOpus, formatFlags: 0, framesPerPacket: 960)
}

private func makeAudioFormat(formatId: AudioFormatID,
                             formatFlags: AudioFormatFlags,
                             framesPerPacket: UInt32) -> AVAudioFormat
{
    var description = AudioStreamBasicDescription(
        mSampleRate: 48000,
        mFormatID: formatId,
        mFormatFlags: formatFlags,
        mBytesPerPacket: 0,
        mFramesPerPacket: framesPerPacket,
        mBytesPerFrame: 0,
        mChannelsPerFrame: 2,
        mBitsPerChannel: 0,
        mReserved: 0
    )
    return AVAudioFormat(streamDescription: &description)!
}

func makeAudioBuffer(format: AVAudioFormat, payload: Data) -> AVAudioCompressedBuffer {
    let buffer = AVAudioCompressedBuffer(format: format, packetCapacity: 1, maximumPacketSize: 64)
    payload.withUnsafeBytes { buffer.data.copyMemory(from: $0.baseAddress!, byteCount: payload.count) }
    buffer.byteLength = UInt32(payload.count)
    buffer.packetCount = 1
    return buffer
}

func makeH264FormatDescription() throws -> CMFormatDescription {
    let sps: [UInt8] = [0x67, 0x42, 0x00, 0x0A, 0xF8, 0x41, 0xA2]
    let pps: [UInt8] = [0x68, 0xCE, 0x38, 0x80]
    var formatDescription: CMFormatDescription?
    let status = sps.withUnsafeBufferPointer { sps in
        pps.withUnsafeBufferPointer { pps in
            let pointers = [sps.baseAddress!, pps.baseAddress!]
            let sizes = [sps.count, pps.count]
            return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                allocator: nil,
                parameterSetCount: 2,
                parameterSetPointers: pointers,
                parameterSetSizes: sizes,
                nalUnitHeaderLength: 4,
                formatDescriptionOut: &formatDescription
            )
        }
    }
    #expect(status == noErr)
    return try #require(formatDescription)
}

func makeVideoSampleBuffer(formatDescription: CMFormatDescription,
                           decodeTimeStamp: CMTime,
                           presentationTimeStamp: CMTime,
                           isSync: Bool,
                           payload: Data) throws -> CMSampleBuffer
{
    var blockBuffer: CMBlockBuffer?
    #expect(CMBlockBufferCreateWithMemoryBlock(
        allocator: nil,
        memoryBlock: nil,
        blockLength: payload.count,
        blockAllocator: nil,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: payload.count,
        flags: kCMBlockBufferAssureMemoryNowFlag,
        blockBufferOut: &blockBuffer
    ) == noErr)
    let block = try #require(blockBuffer)
    payload.withUnsafeBytes {
        _ = CMBlockBufferReplaceDataBytes(with: $0.baseAddress!,
                                          blockBuffer: block,
                                          offsetIntoDestination: 0,
                                          dataLength: payload.count)
    }
    var timing = CMSampleTimingInfo(duration: .invalid,
                                    presentationTimeStamp: presentationTimeStamp,
                                    decodeTimeStamp: decodeTimeStamp)
    var sampleSize = payload.count
    var sampleBuffer: CMSampleBuffer?
    #expect(CMSampleBufferCreateReady(allocator: nil,
                                      dataBuffer: block,
                                      formatDescription: formatDescription,
                                      sampleCount: 1,
                                      sampleTimingEntryCount: 1,
                                      sampleTimingArray: &timing,
                                      sampleSizeEntryCount: 1,
                                      sampleSizeArray: &sampleSize,
                                      sampleBufferOut: &sampleBuffer) == noErr)
    let buffer = try #require(sampleBuffer)
    if !isSync {
        let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true)!
        let attachment = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
        CFDictionarySetValue(attachment,
                             Unmanaged.passUnretained(kCMSampleAttachmentKey_NotSync).toOpaque(),
                             Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
    }
    return buffer
}

func mediaTime(_ value: Int64) -> CMTime {
    CMTime(value: value, timescale: 1024)
}
