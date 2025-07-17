import AVFoundation

/// ISO/IEC 14496-15 8.3.3.1.2
struct MpegTsVideoConfigHevc {
    static func getHvcC(_ formatDescription: CMFormatDescription) -> Data? {
        if let atoms = formatDescription.atoms() {
            return atoms["hvcC"] as? Data
        }
        return nil
    }

    var videoParameterSet: Data?
    var sequenceParameterSet: Data?
    var pictureParameterSet: Data?

    init(hvcC: Data) {
        let reader = ByteReader(data: hvcC)
        do {
            _ = try reader.readBytes(22)
            let numberOfArrays = try reader.readUInt8()
            for _ in 0 ..< numberOfArrays {
                let header = try reader.readUInt8()
                let nalUnitType = HevcNalUnitType(rawValue: header & 0b0011_1111) ?? .unspec
                let numNalus = try reader.readUInt16()
                for _ in 0 ..< numNalus {
                    let length = try reader.readUInt16()
                    let data = try reader.readBytes(Int(length))
                    switch nalUnitType {
                    case .vps:
                        videoParameterSet = data
                    case .sps:
                        sequenceParameterSet = data
                    case .pps:
                        pictureParameterSet = data
                    default:
                        break
                    }
                }
            }
        } catch {
            logger.error("Failed to parse hvcC")
        }
    }

    init?(formatDescription: CMFormatDescription) {
        guard let data = Self.getHvcC(formatDescription) else {
            return nil
        }
        self.init(hvcC: data)
    }

    func makeFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
        guard let videoParameterSet, let sequenceParameterSet, let pictureParameterSet else {
            return kCMFormatDescriptionBridgeError_InvalidParameter
        }
        return videoParameterSet.withUnsafeBytes { (vpsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let vpsBaseAddress = vpsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sequenceParameterSet.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return kCMFormatDescriptionBridgeError_InvalidParameter
                }
                return pictureParameterSet.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                    guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                        return kCMFormatDescriptionBridgeError_InvalidParameter
                    }
                    let pointers = [
                        vpsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ]
                    let sizes = [vpsBuffer.count, spsBuffer.count, ppsBuffer.count]
                    return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointers.count,
                        parameterSetPointers: pointers,
                        parameterSetSizes: sizes,
                        nalUnitHeaderLength: 4,
                        extensions: nil,
                        formatDescriptionOut: formatDescriptionOut
                    )
                }
            }
        }
    }
}
