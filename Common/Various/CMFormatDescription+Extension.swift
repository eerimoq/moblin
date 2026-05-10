import CoreMedia

extension CMFormatDescription {
    func atoms() -> NSDictionary? {
        CMFormatDescriptionGetExtension(
            self,
            extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms
        ) as? NSDictionary
    }

    func extensions() -> CFDictionary? {
        CMFormatDescriptionGetExtensions(self)
    }

    func numberOfAudioChannels() -> UInt32? {
        audioStreamBasicDescription?.mChannelsPerFrame
    }
}
