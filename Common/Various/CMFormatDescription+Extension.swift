import CoreMedia

extension CMFormatDescription {
    func atoms() -> NSDictionary? {
        return CMFormatDescriptionGetExtension(
            self,
            extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms
        ) as? NSDictionary
    }

    func extensions() -> CFDictionary? {
        return CMFormatDescriptionGetExtensions(self)
    }

    func numberOfAudioChannels() -> UInt32? {
        return audioStreamBasicDescription?.mChannelsPerFrame
    }
}
