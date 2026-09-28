import AVFoundation
import CoreImage
@testable import Moblin
import Testing

private let sRGBColorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

private let fullRange8Bit = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
private let videoRange8Bit = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
private let mjpeg: OSType = 0x6A70_6567
private let fullRange10Bit = kCVPixelFormatType_420YpCbCr10BiPlanarFullRange
private let videoRange10Bit = kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange

private struct TestVideoFormat: VideoFormat {
    let pixelFormat: OSType
}

private final class EncoderTester: VideoEncoderDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var formatDescriptions: [CMFormatDescription] = []
    private var sampleBuffers: [CMSampleBuffer] = []

    func videoEncoderOutputFormat(_: VideoEncoder, _ formatDescription: CMFormatDescription) {
        lock.withLock {
            formatDescriptions.append(formatDescription)
        }
    }

    func videoEncoderOutputSampleBuffer(_: VideoEncoder, _ sampleBuffer: CMSampleBuffer, _: CMTime) {
        lock.withLock {
            sampleBuffers.append(sampleBuffer)
        }
    }

    func waitForSampleBuffers(count: Int) -> [CMSampleBuffer] {
        for _ in 0 ..< 500 {
            let sampleBuffers = lock.withLock { self.sampleBuffers }
            if sampleBuffers.count >= count {
                return sampleBuffers
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return lock.withLock { sampleBuffers }
    }

    func waitForFormatDescriptions(count: Int) -> [CMFormatDescription] {
        for _ in 0 ..< 500 {
            let formatDescriptions = lock.withLock { self.formatDescriptions }
            if formatDescriptions.count >= count {
                return formatDescriptions
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return lock.withLock { formatDescriptions }
    }
}

private final class DecoderTester: VideoDecoderDelegate, @unchecked Sendable {
    private let lock = NSLock()
    private var imageBuffers: [CVImageBuffer] = []

    func videoDecoderOutputSampleBuffer(_: VideoDecoder, _ sampleBuffer: CMSampleBuffer) {
        lock.withLock {
            if let imageBuffer = sampleBuffer.imageBuffer {
                imageBuffers.append(imageBuffer)
            }
        }
    }

    func waitForImageBuffers(count: Int) -> [CVImageBuffer] {
        for _ in 0 ..< 500 {
            let imageBuffers = lock.withLock { self.imageBuffers }
            if imageBuffers.count >= count {
                return imageBuffers
            }
            Thread.sleep(forTimeInterval: 0.01)
        }
        return lock.withLock { imageBuffers }
    }
}

struct VideoColorSuite {
    @Test
    func colorAttachments() {
        let pixelBuffer = createPixelBuffer(width: 16, height: 16, colorAttachments: defaultColorAttachments)
        #expect(pixelBuffer.colorAttachments == defaultColorAttachments)
        #expect(createPixelBuffer(width: 16, height: 16, colorAttachments: [:]).colorAttachments.isEmpty)
    }

    #if targetEnvironment(macCatalyst)
    @Test
    func formatDescriptionMatcherAddsColorExtensions() {
        let pixelBuffer = createPixelBuffer(width: 16, height: 16, colorAttachments: [:])
        let sampleBuffer = createSampleBuffer(pixelBuffer)
        CVBufferSetAttachments(pixelBuffer, defaultColorAttachments as CFDictionary, .shouldPropagate)
        let matcher = FormatDescriptionMatcher()
        let matchedSampleBuffer = matcher.match(sampleBuffer)
        #expect(matchedSampleBuffer?.formatDescription.map(colorExtensions) == defaultColorAttachments)
        #expect(matchedSampleBuffer?.presentationTimeStamp == sampleBuffer.presentationTimeStamp)
        let matchingSampleBuffer = createSampleBuffer(pixelBuffer)
        #expect(matcher.match(matchingSampleBuffer) === matchingSampleBuffer)
    }
    #endif

    @Test
    func encoderUsesFrameColorAttachments() {
        let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.test.encoder")
        let tester = EncoderTester()
        let encoder = VideoEncoder(lockQueue: lockQueue, colorRange: .full)
        encoder.delegate = tester
        encoder.settings.mutate {
            $0.videoSize = .init(width: 320, height: 240)
            $0.bitrate = 1_000_000
        }
        encoder.startRunning()
        var frame: Int64 = 0
        for colorAttachments in [defaultColorAttachments, rec709ColorAttachments] {
            let pixelBuffer = createPixelBuffer(width: 320, height: 240, colorAttachments: colorAttachments)
            for _ in 0 ..< 10 {
                lockQueue.sync {
                    encoder.encodeImageBuffer(pixelBuffer,
                                              presentationTimeStamp: CMTime(value: frame, timescale: 30),
                                              duration: CMTime(value: 1, timescale: 30))
                }
                frame += 1
            }
            _ = tester.waitForFormatDescriptions(count: colorAttachments == defaultColorAttachments ? 1 : 2)
        }
        encoder.stopRunning()
        let formatDescriptions = tester.waitForFormatDescriptions(count: 2)
        #expect(formatDescriptions.count == 2)
        #expect(formatDescriptions.first.map(colorExtensions) == defaultColorAttachments)
        #expect(formatDescriptions.last.map(colorExtensions) == rec709ColorAttachments)
    }

    @Test
    func encoderUsesOutputColorAttachments() {
        let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.test.encoder")
        let tester = EncoderTester()
        let encoder = VideoEncoder(lockQueue: lockQueue, colorRange: .full)
        encoder.delegate = tester
        encoder.settings.mutate {
            $0.videoSize = .init(width: 320, height: 240)
            $0.bitrate = 1_000_000
        }
        encoder.outputColorAttachments = defaultColorAttachments
        encoder.startRunning()
        var frame: Int64 = 0
        for colorAttachments in [defaultColorAttachments, rec709ColorAttachments, [:]] {
            let pixelBuffer = createPixelBuffer(width: 320, height: 240, colorAttachments: colorAttachments)
            for _ in 0 ..< 10 {
                lockQueue.sync {
                    encoder.encodeImageBuffer(pixelBuffer,
                                              presentationTimeStamp: CMTime(value: frame, timescale: 30),
                                              duration: CMTime(value: 1, timescale: 30))
                }
                frame += 1
            }
        }
        let sampleBuffers = tester.waitForSampleBuffers(count: 30)
        encoder.stopRunning()
        #expect(sampleBuffers.count == 30)
        #expect(sampleBuffers.filter { $0.getIsSync() }.count == 1)
        let formatDescriptions = tester.waitForFormatDescriptions(count: 1)
        #expect(formatDescriptions.map(colorExtensions) == [defaultColorAttachments])
    }

    @Test(arguments: [defaultColorAttachments, rec709ColorAttachments], [
        SettingsStreamColorRange.full,
        .limited,
    ])
    func coreImageRenderKeepsSrgbValues(sourceColorAttachments: [String: String],
                                        colorRange: SettingsStreamColorRange) throws
    {
        let pixelFormat = colorRange.pixelFormatType()
        let processor = VideoEffectsProcessor(colorRange: colorRange)
        processor.canvasSize = CGSize(width: 64, height: 64)
        for color in [(0, 255, 0), (255, 0, 255), (255, 0, 0), (128, 128, 128), (98, 122, 157)] {
            let source = createPixelBuffer(width: 64,
                                           height: 64,
                                           colorAttachments: sourceColorAttachments,
                                           pixelFormat: pixelFormat)
            let colorImage = CIImage(color: CIColor(red: CGFloat(color.0) / 255,
                                                    green: CGFloat(color.1) / 255,
                                                    blue: CGFloat(color.2) / 255,
                                                    colorSpace: sRGBColorSpace)!)
                .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
            processor.context.render(
                colorImage,
                to: source,
                bounds: colorImage.extent,
                colorSpace: sRGBColorSpace
            )
            let output = try #require(processor.createPixelBuffer(sampleBuffer: createSampleBuffer(source)))
            let image = processor.makeCiImage(source)
            processor.renderCoreImage(image, output, image.extent)
            #expect(output.colorAttachments == sdrColorAttachments(colorRange: colorRange))
            let actual = readCenterPixel(output)
            #expect(abs(actual.0 - color.0) <= 3, "\(color) -> \(actual)")
            #expect(abs(actual.1 - color.1) <= 3, "\(color) -> \(actual)")
            #expect(abs(actual.2 - color.2) <= 3, "\(color) -> \(actual)")
        }
    }

    @Test
    func colorRangePixelFormats() {
        #expect(SettingsStreamColorRange.full.pixelFormatType() == fullRange8Bit)
        #expect(SettingsStreamColorRange.limited.pixelFormatType() == videoRange8Bit)
        #expect(!isVideoRangePixelFormat(fullRange8Bit))
        #expect(isVideoRangePixelFormat(videoRange8Bit))
        #expect(!isVideoRangePixelFormat(fullRange10Bit))
        #expect(isVideoRangePixelFormat(videoRange10Bit))
        #expect(!isVideoRangePixelFormat(kCVPixelFormatType_32BGRA))
        #expect(isFullRangePixelFormat(fullRange8Bit))
        #expect(!isFullRangePixelFormat(videoRange8Bit))
        #expect(isFullRangePixelFormat(fullRange10Bit))
        #expect(!isFullRangePixelFormat(videoRange10Bit))
        #expect(!isFullRangePixelFormat(mjpeg))
        #expect(!isVideoRangePixelFormat(mjpeg))
    }

    @Test
    func cameraFormatsFollowColorRange() {
        let formats = [videoRange8Bit, fullRange8Bit, videoRange10Bit].map(TestVideoFormat.init)
        #expect(filterFormatsByColorRange(formats, .full).map(\.pixelFormat) == [fullRange8Bit])
        #expect(filterFormatsByColorRange(formats, .limited).map(\.pixelFormat)
            == [videoRange8Bit, videoRange10Bit])
        let fullRangeFormats = [TestVideoFormat(pixelFormat: fullRange8Bit)]
        #expect(filterFormatsByColorRange(fullRangeFormats, .limited).map(\.pixelFormat)
            == [fullRange8Bit])
        let videoRangeFormats = [videoRange8Bit, videoRange10Bit].map(TestVideoFormat.init)
        #expect(filterFormatsByColorRange(videoRangeFormats, .full).map(\.pixelFormat) == [videoRange10Bit])
        let videoRange8BitFormats = [TestVideoFormat(pixelFormat: videoRange8Bit)]
        #expect(filterFormatsByColorRange(videoRange8BitFormats, .full)
            .map(\.pixelFormat) == [videoRange8Bit])
        let usbCameraFormats = [videoRange8Bit, mjpeg].map(TestVideoFormat.init)
        #expect(filterFormatsByColorRange(usbCameraFormats, .full).map(\.pixelFormat) == [mjpeg])
        #expect(filterFormatsByColorRange(usbCameraFormats, .limited).map(\.pixelFormat) == [videoRange8Bit])
    }

    @Test
    func processorOutputPixelFormatFollowsColorRange() {
        for (colorRange, pixelFormat, hlgPixelFormat, colorAttachments) in [
            (SettingsStreamColorRange.full, fullRange8Bit, fullRange10Bit, defaultColorAttachments),
            (.limited, videoRange8Bit, videoRange10Bit, rec709ColorAttachments),
        ] {
            let processor = VideoEffectsProcessor(colorRange: colorRange)
            processor.colorSpace = .sRGB
            #expect(processor.outputPixelFormatType() == pixelFormat)
            #expect(processor.outputColorAttachments == colorAttachments)
            processor.colorSpace = .HLG_BT2020
            #expect(processor.outputPixelFormatType() == hlgPixelFormat)
        }
    }

    @Test(arguments: [
        (kVTProfileLevel_H264_Main_AutoLevel as String, fullRange8Bit),
        (kVTProfileLevel_H264_Main_AutoLevel as String, videoRange8Bit),
        (kVTProfileLevel_HEVC_Main_AutoLevel as String, fullRange8Bit),
        (kVTProfileLevel_HEVC_Main_AutoLevel as String, videoRange8Bit),
        (kVTProfileLevel_HEVC_Main10_AutoLevel as String, fullRange10Bit),
        (kVTProfileLevel_HEVC_Main10_AutoLevel as String, videoRange10Bit),
    ])
    func encoderKeepsColorRange(profileLevel: String, pixelFormat: OSType) {
        let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.test.encoder")
        let tester = EncoderTester()
        let encoder = VideoEncoder(lockQueue: lockQueue, colorRange: colorRange(pixelFormat))
        encoder.delegate = tester
        encoder.settings.mutate {
            $0.videoSize = .init(width: 320, height: 240)
            $0.bitrate = 1_000_000
            $0.profileLevel = profileLevel
        }
        encoder.startRunning()
        let pixelBuffer = createPixelBuffer(width: 320,
                                            height: 240,
                                            colorAttachments: defaultColorAttachments,
                                            pixelFormat: pixelFormat)
        for frame in 0 ..< 10 {
            lockQueue.sync {
                encoder.encodeImageBuffer(pixelBuffer,
                                          presentationTimeStamp: CMTime(value: Int64(frame), timescale: 30),
                                          duration: CMTime(value: 1, timescale: 30))
            }
        }
        let formatDescriptions = tester.waitForFormatDescriptions(count: 1)
        encoder.stopRunning()
        #expect(formatDescriptions.count == 1)
        #expect(formatDescriptions.first.map(isFullRange) == !isVideoRangePixelFormat(pixelFormat))
    }

    @Test(arguments: [SettingsStreamColorRange.full, .limited], [SettingsStreamColorRange.full, .limited])
    func decoderOutputsColorRange(streamColorRange: SettingsStreamColorRange,
                                  outputColorRange: SettingsStreamColorRange) throws
    {
        let processor = VideoEffectsProcessor(colorRange: .full)
        let color = (204, 51, 102)
        let sampleBuffers = try encodeColorStream(streamColorRange, color, processor.context)
        let decoded = try #require(decode(sampleBuffers, outputColorRange).first)
        #expect(CVPixelBufferGetPixelFormatType(decoded) == outputColorRange.pixelFormatType())
        let actual = readCenterPixel(processor.makeCiImage(decoded), processor.context)
        #expect(abs(actual.0 - color.0) <= 3, "\(color) -> \(actual)")
        #expect(abs(actual.1 - color.1) <= 3, "\(color) -> \(actual)")
        #expect(abs(actual.2 - color.2) <= 3, "\(color) -> \(actual)")
        #expect(decoded.colorAttachments[kCVImageBufferYCbCrMatrixKey as String]
            == sdrYCbCrMatrix(colorRange: outputColorRange) as String)
    }

    @Test(arguments: [videoRange10Bit, fullRange10Bit])
    func hlgRenderKeepsCameraSignal(pixelFormat: OSType) {
        let processor = VideoEffectsProcessor(colorRange: .full)
        processor.colorSpace = .HLG_BT2020
        for signal in [
            (0.0, 0.0, 0.0),
            (0.75, 0.75, 0.75),
            (0.2, 0.5, 0.8),
            (0.9, 0.3, 0.1),
            (1.0, 1.0, 1.0),
        ] {
            let source = createHlgPixelBuffer(pixelFormat)
            let signalImage = CIImage(color: CIColor(red: signal.0, green: signal.1, blue: signal.2))
                .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
            processor.context.render(signalImage, to: source, bounds: signalImage.extent, colorSpace: nil)
            let expected = readHlgSignal(source, processor.context)
            let output = createHlgPixelBuffer(pixelFormat)
            let image = processor.makeCiImage(source)
            processor.renderCoreImage(image, output, image.extent)
            let actual = readHlgSignal(output, processor.context)
            for (actual, expected) in zip(actual, expected) {
                #expect(abs(actual - expected) < 0.004, "\(signal) -> \(actual) != \(expected)")
            }
        }
    }

    @Test(arguments: [videoRange10Bit, fullRange10Bit])
    func hlgRenderMapsSdrFramesToBt2100(pixelFormat: OSType) throws {
        let processor = VideoEffectsProcessor(colorRange: .full)
        processor.colorSpace = .HLG_BT2020
        for (color, expected) in [
            ((1.0, 1.0, 1.0), [0.7499, 0.7499, 0.7499]),
            ((1.0, 0.0, 0.0), [0.7086, 0.2664, 0.1297]),
            ((0.0, 0.0, 1.0), [0.2310, 0.1183, 0.8133]),
        ] {
            let source = createPixelBuffer(width: 64, height: 64, colorAttachments: defaultColorAttachments)
            let colorImage = try CIImage(color: #require(CIColor(red: color.0,
                                                                 green: color.1,
                                                                 blue: color.2,
                                                                 colorSpace: sRGBColorSpace)))
                .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
            processor.context.render(
                colorImage,
                to: source,
                bounds: colorImage.extent,
                colorSpace: sRGBColorSpace
            )
            let output = createHlgPixelBuffer(pixelFormat)
            let image = processor.makeCiImage(source)
            processor.renderCoreImage(image, output, image.extent)
            let actual = readHlgSignal(output, processor.context)
            for (actual, expected) in zip(actual, expected) {
                #expect(abs(actual - expected) < 0.008, "\(color) -> \(actual) != \(expected)")
            }
        }
    }

    @Test(arguments: [videoRange10Bit, fullRange10Bit])
    func hlgRenderMapsSrgbToBt2100(pixelFormat: OSType) throws {
        let processor = VideoEffectsProcessor(colorRange: .full)
        processor.colorSpace = .HLG_BT2020
        for (color, expected) in [
            ((1.0, 1.0, 1.0), [0.7499, 0.7499, 0.7499]),
            ((0.5, 0.5, 0.5), [0.4689, 0.4689, 0.4689]),
            ((1.0, 0.0, 0.0), [0.7086, 0.2664, 0.1297]),
            ((0.0, 1.0, 0.0), [0.5248, 0.7444, 0.2719]),
            ((0.0, 0.0, 1.0), [0.2310, 0.1183, 0.8133]),
            ((0.878, 0.639, 0.180), [0.6724, 0.5833, 0.2511]),
            ((0.220, 0.239, 0.588), [0.2592, 0.2483, 0.5788]),
        ] {
            let image = try CIImage(color: #require(CIColor(
                red: color.0,
                green: color.1,
                blue: color.2,
                colorSpace: sRGBColorSpace
            )))
            .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))
            let output = createHlgPixelBuffer(pixelFormat)
            processor.renderCoreImage(image, output, image.extent)
            let actual = readHlgSignal(output, processor.context)
            for (actual, expected) in zip(actual, expected) {
                #expect(abs(actual - expected) < 0.006, "\(color) -> \(actual) != \(expected)")
            }
        }
    }
}

private func isFullRange(_ formatDescription: CMFormatDescription) -> Bool {
    CMFormatDescriptionGetExtension(formatDescription,
                                    extensionKey: kCMFormatDescriptionExtension_FullRangeVideo) as? Bool ??
        false
}

private func colorRange(_ pixelFormat: OSType) -> SettingsStreamColorRange {
    isVideoRangePixelFormat(pixelFormat) ? .limited : .full
}

private func encodeColorStream(_ colorRange: SettingsStreamColorRange,
                               _ color: (Int, Int, Int),
                               _ context: CIContext) throws -> [CMSampleBuffer]
{
    let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.test.encoder")
    let tester = EncoderTester()
    let encoder = VideoEncoder(lockQueue: lockQueue, colorRange: colorRange)
    encoder.delegate = tester
    encoder.settings.mutate {
        $0.videoSize = .init(width: 320, height: 240)
        $0.bitrate = 2_000_000
    }
    encoder.startRunning()
    let source = createPixelBuffer(width: 320,
                                   height: 240,
                                   colorAttachments: sdrColorAttachments(colorRange: colorRange),
                                   pixelFormat: colorRange.pixelFormatType())
    let colorImage = try CIImage(color: #require(CIColor(red: CGFloat(color.0) / 255,
                                                         green: CGFloat(color.1) / 255,
                                                         blue: CGFloat(color.2) / 255,
                                                         colorSpace: sRGBColorSpace)))
        .cropped(to: CGRect(x: 0, y: 0, width: 320, height: 240))
    context.render(colorImage, to: source, bounds: colorImage.extent, colorSpace: sRGBColorSpace)
    for frame in 0 ..< 10 {
        lockQueue.sync {
            encoder.encodeImageBuffer(source,
                                      presentationTimeStamp: CMTime(value: Int64(frame), timescale: 30),
                                      duration: CMTime(value: 1, timescale: 30))
        }
    }
    let sampleBuffers = tester.waitForSampleBuffers(count: 10)
    encoder.stopRunning()
    return sampleBuffers
}

private func decode(_ sampleBuffers: [CMSampleBuffer],
                    _ colorRange: SettingsStreamColorRange) -> [CVImageBuffer]
{
    let lockQueue = DispatchQueue(label: "com.eerimoq.moblin.test.decoder")
    let tester = DecoderTester()
    let decoder = VideoDecoder(
        name: "test",
        lockQueue: lockQueue,
        softwareDecoding: false,
        colorRange: colorRange
    )
    decoder.delegate = tester
    lockQueue.sync {
        decoder.startRunning(formatDescription: sampleBuffers.first?.formatDescription)
        for sampleBuffer in sampleBuffers {
            decoder.decodeSampleBuffer(sampleBuffer)
        }
    }
    let imageBuffers = tester.waitForImageBuffers(count: sampleBuffers.count)
    lockQueue.sync {
        decoder.stopRunning()
    }
    return imageBuffers
}

private func createHlgPixelBuffer(_ pixelFormat: OSType) -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(nil,
                        64,
                        64,
                        pixelFormat,
                        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
                        &pixelBuffer)
    CVBufferSetAttachments(pixelBuffer!, hlgColorAttachments as CFDictionary, .shouldPropagate)
    return pixelBuffer!
}

private func readHlgSignal(_ pixelBuffer: CVPixelBuffer, _ context: CIContext) -> [Double] {
    let image = CIImage(cvPixelBuffer: pixelBuffer, options: [.colorSpace: NSNull()])
    var pixel = [Float](repeating: 0, count: 4)
    context.render(image,
                   toBitmap: &pixel,
                   rowBytes: 16,
                   bounds: CGRect(x: 32, y: 32, width: 1, height: 1),
                   format: .RGBAf,
                   colorSpace: nil)
    return pixel[0 ..< 3].map { Double($0) }
}

private func colorExtensions(_ formatDescription: CMFormatDescription) -> [String: String] {
    var extensions: [String: String] = [:]
    for key in [
        kCMFormatDescriptionExtension_ColorPrimaries,
        kCMFormatDescriptionExtension_TransferFunction,
        kCMFormatDescriptionExtension_YCbCrMatrix,
    ] {
        if let value = CMFormatDescriptionGetExtension(formatDescription, extensionKey: key) as? String {
            extensions[key as String] = value
        }
    }
    return extensions
}

private func createPixelBuffer(width: Int,
                               height: Int,
                               colorAttachments: [String: String],
                               pixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
    -> CVPixelBuffer
{
    var pixelBuffer: CVPixelBuffer?
    CVPixelBufferCreate(nil,
                        width,
                        height,
                        pixelFormat,
                        [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary,
                        &pixelBuffer)
    CVBufferSetAttachments(pixelBuffer!, colorAttachments as CFDictionary, .shouldPropagate)
    return pixelBuffer!
}

private func createSampleBuffer(_ pixelBuffer: CVPixelBuffer) -> CMSampleBuffer {
    var formatDescription: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
                                                 imageBuffer: pixelBuffer,
                                                 formatDescriptionOut: &formatDescription)
    var timingInfo = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: 30),
                                        presentationTimeStamp: CMTime(value: 7, timescale: 30),
                                        decodeTimeStamp: .invalid)
    var sampleBuffer: CMSampleBuffer?
    CMSampleBufferCreateForImageBuffer(allocator: nil,
                                       imageBuffer: pixelBuffer,
                                       dataReady: true,
                                       makeDataReadyCallback: nil,
                                       refcon: nil,
                                       formatDescription: formatDescription!,
                                       sampleTiming: &timingInfo,
                                       sampleBufferOut: &sampleBuffer)
    return sampleBuffer!
}

private func readCenterPixel(_ pixelBuffer: CVPixelBuffer) -> (Int, Int, Int) {
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)
    }
    let x = CVPixelBufferGetWidth(pixelBuffer) / 2
    let y = CVPixelBufferGetHeight(pixelBuffer) / 2
    let lumaPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0)!.assumingMemoryBound(to: UInt8.self)
    let chromaPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1)!.assumingMemoryBound(to: UInt8.self)
    let luma = Double(lumaPlane[y * CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) + x])
    let chromaOffset = (y / 2) * CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1) + (x / 2) * 2
    let blueDifference = Double(chromaPlane[chromaOffset]) - 128
    let redDifference = Double(chromaPlane[chromaOffset + 1]) - 128
    let (kr, kb) = pixelBuffer.colorAttachments[kCVImageBufferYCbCrMatrixKey as String]
        == kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String ? (0.2126, 0.0722) : (0.299, 0.114)
    let (yScale, cScale, yOffset) = isVideoRangePixelFormat(CVPixelBufferGetPixelFormatType(pixelBuffer))
        ? (219.0, 224.0, 16.0) : (255.0, 255.0, 0.0)
    let yNormalized = (luma - yOffset) / yScale
    let red = yNormalized + 2 * (1 - kr) * redDifference / cScale
    let blue = yNormalized + 2 * (1 - kb) * blueDifference / cScale
    let green = (yNormalized - kr * red - kb * blue) / (1 - kr - kb)
    return (Int((255 * red).rounded()), Int((255 * green).rounded()), Int((255 * blue).rounded()))
}

private func readCenterPixel(_ image: CIImage, _ context: CIContext) -> (Int, Int, Int) {
    var pixel = [UInt8](repeating: 0, count: 4)
    context.render(image,
                   toBitmap: &pixel,
                   rowBytes: 4,
                   bounds: CGRect(x: image.extent.midX, y: image.extent.midY, width: 1, height: 1),
                   format: .RGBA8,
                   colorSpace: sRGBColorSpace)
    return (Int(pixel[0]), Int(pixel[1]), Int(pixel[2]))
}
