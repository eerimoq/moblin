import CoreMedia

extension CMFormatDescription {
    func atoms() -> NSDictionary? {
        return CMFormatDescriptionGetExtension(
            self,
            extensionKey: kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms
        ) as? NSDictionary
    }
}
