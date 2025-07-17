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
    var sequenceParameterSet = Data()
    var pictureParameterSet = Data()

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
        return pictureParameterSet.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sequenceParameterSet.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return kCMFormatDescriptionBridgeError_InvalidParameter
                }
                let pointers: [UnsafePointer<UInt8>] = [
                    spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                ]
                let sizes: [Int] = [spsBuffer.count, ppsBuffer.count]
                let nalUnitHeaderLength: Int32 = 4
                return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                    allocator: kCFAllocatorDefault,
                    parameterSetCount: pointers.count,
                    parameterSetPointers: pointers,
                    parameterSetSizes: sizes,
                    nalUnitHeaderLength: nalUnitHeaderLength,
                    formatDescriptionOut: formatDescriptionOut
                )
            }
        }
    }

    var avcC: Data {
        get {
            let buffer = ByteWriter()
                .writeUInt8(configurationVersion)
                .writeUInt8(avcProfileIndication)
                .writeUInt8(profileCompatibility)
                .writeUInt8(avcLevelIndication)
                .writeUInt8(lengthSizeMinusOneWithReserved)
                .writeUInt8(numOfSequenceParameterSetsWithReserved)
            buffer
                .writeUInt16(UInt16(sequenceParameterSet.count))
                .writeBytes(sequenceParameterSet)
            buffer.writeUInt8(UInt8(pictureParameterSet.count))
            buffer
                .writeUInt16(UInt16(pictureParameterSet.count))
                .writeBytes(pictureParameterSet)
            return buffer.data
        }
        set {
            let buffer = ByteReader(data: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                avcProfileIndication = try buffer.readUInt8()
                profileCompatibility = try buffer.readUInt8()
                avcLevelIndication = try buffer.readUInt8()
                lengthSizeMinusOneWithReserved = try buffer.readUInt8()
                numOfSequenceParameterSetsWithReserved = try buffer.readUInt8()
                let numOfSequenceParameterSets = numOfSequenceParameterSetsWithReserved &
                    ~MpegTsVideoConfigAvc.reserveNumOfSequenceParameterSets
                for _ in 0 ..< numOfSequenceParameterSets {
                    let length = try Int(buffer.readUInt16())
                    try sequenceParameterSet.append(buffer.readBytes(length))
                }
                let numPictureParameterSets = try buffer.readUInt8()
                for _ in 0 ..< numPictureParameterSets {
                    let length = try Int(buffer.readUInt16())
                    try pictureParameterSet.append(buffer.readBytes(length))
                }
            } catch {
                logger.error("Failed to set avcC")
            }
        }
    }
}
