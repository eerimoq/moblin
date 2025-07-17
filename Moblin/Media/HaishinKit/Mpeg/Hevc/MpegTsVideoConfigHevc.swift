import AVFoundation

/// ISO/IEC 14496-15 8.3.3.1.2
struct MpegTsVideoConfigHevc {
    static func getHvcC(_ formatDescription: CMFormatDescription) -> Data? {
        if let atoms = formatDescription.atoms() {
            return atoms["hvcC"] as? Data
        }
        return nil
    }

    var configurationVersion: UInt8 = 1
    private(set) var nalUnits: [HevcNalUnitType: Data] = [:]

    init(hvcC: Data) {
        self.hvcC = hvcC
    }

    init?(formatDescription: CMFormatDescription) {
        guard let data = Self.getHvcC(formatDescription) else {
            return nil
        }
        hvcC = data
    }

    func makeFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
        guard let vps = nalUnits[.vps], let sps = nalUnits[.sps], let pps = nalUnits[.pps] else {
            return kCMFormatDescriptionBridgeError_InvalidParameter
        }
        return vps.withUnsafeBytes { (vpsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let vpsBaseAddress = vpsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sps.withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return kCMFormatDescriptionBridgeError_InvalidParameter
                }
                return pps.withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
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

    private var hvcC: Data {
        get {
            let writer = ByteWriter()
            writer.writeUInt8(configurationVersion)
            return writer.data
        }
        set {
            let reader = ByteReader(data: newValue)
            do {
                configurationVersion = try reader.readUInt8()
                _ = try reader.readBytes(21)
                let numberOfArrays = try reader.readUInt8()
                for _ in 0 ..< numberOfArrays {
                    let header = try reader.readUInt8()
                    let nalUnitType = HevcNalUnitType(rawValue: header & 0b0011_1111) ?? .unspec
                    let numNalus = try reader.readUInt16()
                    for _ in 0 ..< numNalus {
                        let length = try reader.readUInt16()
                        try nalUnits[nalUnitType] = reader.readBytes(Int(length))
                    }
                }
            } catch {
                logger.error("Failed to set hvcC")
            }
        }
    }
}
