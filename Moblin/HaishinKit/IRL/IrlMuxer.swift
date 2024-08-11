import AVFoundation

final class IrlMuxer {}

extension IrlMuxer: AudioCodecDelegate {
    func audioCodecOutputFormat(_: AVAudioFormat) {
        logger.info("irl-muxer: audio: Got format")
    }

    func audioCodecOutputBuffer(_: AVAudioBuffer, _: CMTime) {
        logger.info("irl-muxer: audio: Got buffer")
    }
}

extension IrlMuxer: VideoCodecDelegate {
    func videoCodecOutputFormat(_: VideoCodec, _: CMFormatDescription) {
        logger.info("irl-muxer: video: Got format")
    }

    func videoCodecOutputSampleBuffer(_: VideoCodec, _: CMSampleBuffer) {
        logger.info("irl-muxer: video: Got buffer")
    }
}
