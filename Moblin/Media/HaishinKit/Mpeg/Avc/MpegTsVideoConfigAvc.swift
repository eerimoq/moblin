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
    var sequenceParameterSet: Data?
    var pictureParameterSet: Data?

    init(avcC: Data) {
        let reader = ByteReader(data: avcC)
        do {
            _ = try reader.readBytes(5)
            let numOfSequenceParameterSetsWithReserved = try reader.readUInt8()
            let numOfSequenceParameterSets = numOfSequenceParameterSetsWithReserved &
                ~MpegTsVideoConfigAvc.reserveNumOfSequenceParameterSets
            for _ in 0 ..< numOfSequenceParameterSets {
                let length = try Int(reader.readUInt16())
                sequenceParameterSet = try reader.readBytes(length)
            }
            let numPictureParameterSets = try reader.readUInt8()
            for _ in 0 ..< numPictureParameterSets {
                let length = try Int(reader.readUInt16())
                pictureParameterSet = try reader.readBytes(length)
            }
        } catch {
            logger.error("Failed to parse avcC")
        }
    }

    init?(formatDescription: CMFormatDescription) {
        guard let data = Self.getAvcC(formatDescription) else {
            return nil
        }
        self.init(avcC: data)
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
}
