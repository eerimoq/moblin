import AVFoundation
@testable import Moblin
import Testing

struct BufferedVideoSuite {
    @Test
    func appendOutOfOrderEarlyFrame() {
        let bufferedVideo = createBufferedVideo()
        let sampleBuffer1 = createVideoSampleBuffer(presentationTimeStamp: 2.0)
        let sampleBuffer2 = createVideoSampleBuffer(presentationTimeStamp: 3.0)
        let sampleBuffer3 = createVideoSampleBuffer(presentationTimeStamp: 1.0)
        bufferedVideo.appendSampleBuffer(sampleBuffer1)
        bufferedVideo.appendSampleBuffer(sampleBuffer2)
        bufferedVideo.appendSampleBuffer(sampleBuffer3)
        #expect(bufferedVideo.numberOfBuffers() == 3)
        bufferedVideo.updateSampleBuffer(1.5)
        #expect(bufferedVideo.numberOfBuffers() == 2)
    }

    @Test
    func appendFramesInReverseOrder() {
        let bufferedVideo = createBufferedVideo()
        let sampleBuffer1 = createVideoSampleBuffer(presentationTimeStamp: 3.0)
        let sampleBuffer2 = createVideoSampleBuffer(presentationTimeStamp: 2.0)
        let sampleBuffer3 = createVideoSampleBuffer(presentationTimeStamp: 1.0)
        bufferedVideo.appendSampleBuffer(sampleBuffer1)
        bufferedVideo.appendSampleBuffer(sampleBuffer2)
        bufferedVideo.appendSampleBuffer(sampleBuffer3)
        #expect(bufferedVideo.numberOfBuffers() == 3)
        bufferedVideo.updateSampleBuffer(2.5)
        #expect(bufferedVideo.numberOfBuffers() == 1)
    }
}

private func createBufferedVideo() -> BufferedVideo {
    BufferedVideo(cameraId: .init(), name: "", update: true, latency: 0.1, processor: nil)
}

private func createVideoSampleBuffer(presentationTimeStamp: Double) -> CMSampleBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(kCFAllocatorDefault, 1, 1, kCVPixelFormatType_32BGRA, nil,
                                     &pixelBuffer)
    precondition(status == kCVReturnSuccess && pixelBuffer != nil)
    var formatDescription: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
        allocator: kCFAllocatorDefault,
        imageBuffer: pixelBuffer!,
        formatDescriptionOut: &formatDescription
    )
    return CMSampleBuffer.create(
        pixelBuffer!,
        formatDescription!,
        .zero,
        CMTime(seconds: presentationTimeStamp),
        .invalid
    )!
}
