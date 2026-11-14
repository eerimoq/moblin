import AVFoundation

extension CMVideoFormatDescription {
    static func create(imageBuffer: CVImageBuffer) -> CMVideoFormatDescription? {
        var formatDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard status == noErr else {
            logger.info("Failed to create video format description with error \(status)")
            return nil
        }
        return formatDescription
    }
}
