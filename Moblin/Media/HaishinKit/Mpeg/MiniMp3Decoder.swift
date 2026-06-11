import AVFoundation

// Wraps the minimp3 C decoder for use in MpegTsReader.
// One instance corresponds to one MPEG audio PID / stream.
class MiniMp3Decoder {
    // Decoded format, populated after the first successful frame decode.
    private(set) var outputFormat: AVAudioFormat?

    // Reusable PCM sample storage: interleaved int16, up to 2 ch × 1152 samples.
    private let pcmStorage = UnsafeMutablePointer<Int16>
        .allocate(capacity: Int(MINIMP3_MAX_SAMPLES_PER_FRAME))

    deinit {
        pcmStorage.deallocate()
    }

    // Decode all MPEG audio frames found in `data`.
    // Returns one AVAudioPCMBuffer per frame. A PES packet may contain more than one frame.
    func decodeAll(_ data: Data) -> [AVAudioPCMBuffer] {
        var results: [AVAudioPCMBuffer] = []
        var offset = 0
        while offset < data.count {
            var info = MiniMp3FrameInfo()
            let remaining = data.count - offset
            let samplesPerChannel: Int = data.withUnsafeBytes { (rawBuf: UnsafeRawBufferPointer) in
                guard let base = rawBuf.baseAddress else { return 0 }
                let ptr = base.advanced(by: offset).assumingMemoryBound(to: UInt8.self)
                return Int(minimp3_decode_frame(ptr, Int32(remaining), pcmStorage, &info))
            }
            // frame_bytes == 0 means no valid frame found in the remaining data.
            guard info.frame_bytes > 0 else { break }
            offset += Int(info.frame_bytes)
            guard samplesPerChannel > 0, info.channels > 0, info.hz > 0 else { continue }

            let channels = AVAudioChannelCount(info.channels)
            let sampleRate = Double(info.hz)

            if outputFormat == nil
                || outputFormat!.sampleRate != sampleRate
                || outputFormat!.channelCount != channels
            {
                outputFormat = AVAudioFormat(
                    commonFormat: .pcmFormatInt16,
                    sampleRate: sampleRate,
                    channels: channels,
                    interleaved: true
                )
            }
            guard let fmt = outputFormat,
                  let pcmBuf = AVAudioPCMBuffer(pcmFormat: fmt,
                                                frameCapacity: AVAudioFrameCount(samplesPerChannel))
            else { continue }

            pcmBuf.frameLength = AVAudioFrameCount(samplesPerChannel)
            let totalSamples = samplesPerChannel * Int(channels)
            let abl = pcmBuf.mutableAudioBufferList
            abl.pointee.mBuffers.mDataByteSize = UInt32(totalSamples * MemoryLayout<Int16>.size)
            if let dest = abl.pointee.mBuffers.mData {
                dest.copyMemory(from: pcmStorage, byteCount: totalSamples * MemoryLayout<Int16>.size)
            }
            results.append(pcmBuf)
        }
        return results
    }
}
