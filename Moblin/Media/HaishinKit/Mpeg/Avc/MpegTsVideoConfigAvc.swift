import AVFoundation

/*
 - seealso: ISO/IEC 14496-15 2010
 */
struct MpegTsVideoConfigAvc {
    static func getAvcC(_ formatDescription: CMFormatDescription) -> Data? {
        if let atoms = formatDescription.atoms() {
            return atoms["avcC"] as? Data
        }
        return nil
    }

    static let reserveNumOfSequenceParameterSets: UInt8 = 0xE0
    var configurationVersion: UInt8 = 1
    var avcProfileIndication: UInt8 = 0
    var profileCompatibility: UInt8 = 0
    var avcLevelIndication: UInt8 = 0
    var lengthSizeMinusOneWithReserved: UInt8 = 0
    var numOfSequenceParameterSetsWithReserved: UInt8 = 0
    var sequenceParameterSet: Data?
    var pictureParameterSet: Data?

    init(avcC: Data) {
        self.avcC = avcC
    }

    init?(formatDescription: CMFormatDescription) {
        guard let data = Self.getAvcC(formatDescription) else {
            return nil
        }
        avcC = data
    }

    func makeFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
        guard let pictureParameterSet, let sequenceParameterSet else {
            return kCMFormatDescriptionBridgeError_InvalidParameter
        }
        return pictureParameterSet.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sequenceParameterSet.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return kCMFormatDescriptionBridgeError_InvalidParameter
                }
                let pointers = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                ]
                let sizes = [spsBuffer.count, ppsBuffer.count]
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: 4,
                    formatDescriptionOut: formatDescriptionOut
                )
            }
        }
    }

    private var avcC: Data {
        get {
            let writer = ByteWriter()
                .writeUInt8(configurationVersion)
                .writeUInt8(avcProfileIndication)
                .writeUInt8(profileCompatibility)
                .writeUInt8(avcLevelIndication)
                .writeUInt8(lengthSizeMinusOneWithReserved)
                .writeUInt8(numOfSequenceParameterSetsWithReserved)
            if let sequenceParameterSet {
                writer.writeUInt16(UInt16(sequenceParameterSet.count))
                writer.writeBytes(sequenceParameterSet)
            }
            if let pictureParameterSet {
                writer.writeUInt8(UInt8(pictureParameterSet.count))
                writer.writeUInt16(UInt16(pictureParameterSet.count))
                writer.writeBytes(pictureParameterSet)
            }
            return writer.data
        }
        set {
            let reader = ByteReader(data: newValue)
            do {
                configurationVersion = try reader.readUInt8()
                avcProfileIndication = try reader.readUInt8()
                profileCompatibility = try reader.readUInt8()
                avcLevelIndication = try reader.readUInt8()
                lengthSizeMinusOneWithReserved = try reader.readUInt8()
                numOfSequenceParameterSetsWithReserved = try reader.readUInt8()
                let numOfSequenceParameterSets = numOfSequenceParameterSetsWithReserved &
                    ~MpegTsVideoConfigAvc.reserveNumOfSequenceParameterSets
                for _ in 0 ..< numOfSequenceParameterSets {
                    let length = try Int(reader.readUInt16())
                    try sequenceParameterSet = reader.readBytes(length)
                }
                let numPictureParameterSets = try reader.readUInt8()
                for _ in 0 ..< numPictureParameterSets {
                    let length = try Int(reader.readUInt16())
                    try pictureParameterSet = reader.readBytes(length)
                }
            } catch {
                logger.error("Failed to set avcC")
            }
        }
    }
}
