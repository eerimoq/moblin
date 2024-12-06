import VideoToolbox

class MultiTrackVideoEncoder {
    private let encoders: [VideoCodec]

    init(settings: [VideoCodecSettings], lockQueue: DispatchQueue) {
        encoders = settings.map { setting in
            let encoder = VideoCodec(lockQueue: lockQueue)
            encoder.settings.mutate { $0 = setting }
            return encoder
        }
        for encoder in encoders {
            encoder.delegate = self
            encoder.startRunning()
        }
    }

    func encodeImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime) {
        for encoder in encoders {
            encoder.encodeImageBuffer(imageBuffer,
                                      presentationTimeStamp: presentationTimeStamp,
                                      duration: duration)
        }
    }
}

extension MultiTrackVideoEncoder: VideoCodecDelegate {
    func videoCodecOutputFormat(_ codec: VideoCodec, _ formatDescription: CMFormatDescription) {
        logger.info("multi-track-video-encoder: Format for \(codec) \(formatDescription)")
    }

    func videoCodecOutputSampleBuffer(_ codec: VideoCodec, _ sampleBuffer: CMSampleBuffer) {
        logger.info("multi-track-video-encoder: Frame for \(codec) \(sampleBuffer.presentationTimeStamp)")
    }
}
