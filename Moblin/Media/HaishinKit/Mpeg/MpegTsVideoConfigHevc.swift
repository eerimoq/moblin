import AVFoundation

/// ISO/IEC 14496-15 8.3.3.1.2
struct MpegTsVideoConfigHevc: MpegTsVideoConfig {
    static func getData(_ formatDescription: CMFormatDescription) -> Data? {
        if let atoms = formatDescription.atoms() {
            return atoms["hvcC"] as? Data
        }
        return nil
    }

    var configurationVersion: UInt8 = 1
    // periphery:ignore
    var generalProfileSpace: UInt8 = 0
    var generalTierFlag = false
    // periphery:ignore
    var generalProfileIdc: UInt8 = 0
    // periphery:ignore
    var generalProfileCompatibilityFlags: UInt32 = 0
    // periphery:ignore
    var generalConstraintIndicatorFlags: UInt64 = 0
    // periphery:ignore
    var generalLevelIdc: UInt8 = 0
    // periphery:ignore
    var minSpatialSegmentationIdc: UInt16 = 0
    // periphery:ignore
    var parallelismType: UInt8 = 0
    // periphery:ignore
    var chromaFormat: UInt8 = 0
    // periphery:ignore
    var bitDepthLumaMinus8: UInt8 = 0
    // periphery:ignore
    var bitDepthChromaMinus8: UInt8 = 0
    // periphery:ignore
    var avgFrameRate: UInt16 = 0
    // periphery:ignore
    var constantFrameRate: UInt8 = 0
    // periphery:ignore
    var numTemporalLayers: UInt8 = 0
    // periphery:ignore
    var temporalIdNested: UInt8 = 0
    // periphery:ignore
    var lengthSizeMinusOne: UInt8 = 0
    var numberOfArrays: UInt8 = 0
    var array: [HevcNalUnitType: [Data]] = [:]

    init() {}

    init(data: Data) {
        self.data = data
    }

    func makeFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>)
        -> OSStatus
    {
        guard let vps = array[.vps], let sps = array[.sps], let pps = array[.pps] else {
            return kCMFormatDescriptionBridgeError_InvalidParameter
        }
        return vps[0].withUnsafeBytes { (vpsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let vpsBaseAddress = vpsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sps[0].withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                guard let spsBaseAddress = spsBuffer.baseAddress else {
                    return kCMFormatDescriptionBridgeError_InvalidParameter
                }
                return pps[0].withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
                    guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                        return kCMFormatDescriptionBridgeError_InvalidParameter
                    }
                    let pointers: [UnsafePointer<UInt8>] = [
                        vpsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        spsBaseAddress.assumingMemoryBound(to: UInt8.self),
                        ppsBaseAddress.assumingMemoryBound(to: UInt8.self),
                    ]
                    let sizes: [Int] = [vpsBuffer.count, spsBuffer.count, ppsBuffer.count]
                    let nalUnitHeaderLength: Int32 = 4
                    return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                        allocator: kCFAllocatorDefault,
                        parameterSetCount: pointers.count,
                        parameterSetPointers: pointers,
                        parameterSetSizes: sizes,
                        nalUnitHeaderLength: nalUnitHeaderLength,
                        extensions: nil,
                        formatDescriptionOut: formatDescriptionOut
                    )
                }
            }
        }
    }

    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(configurationVersion)
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                let a = try buffer.readUInt8()
                generalProfileSpace = a >> 6
                generalTierFlag = a & 0x20 > 0
                generalProfileIdc = a & 0x1F
                generalProfileCompatibilityFlags = try buffer.readUInt32()
                generalConstraintIndicatorFlags = try UInt64(buffer.readUInt32()) << 16 |
                    UInt64(buffer.readUInt16())
                generalLevelIdc = try buffer.readUInt8()
                minSpatialSegmentationIdc = try buffer.readUInt16() & 0xFFF
                parallelismType = try buffer.readUInt8() & 0x3
                chromaFormat = try buffer.readUInt8() & 0x3
                bitDepthLumaMinus8 = try buffer.readUInt8() & 0x7
                bitDepthChromaMinus8 = try buffer.readUInt8() & 0x7
                avgFrameRate = try buffer.readUInt16()
                let b = try buffer.readUInt8()
                constantFrameRate = b >> 6
                numTemporalLayers = b & 0x38 >> 3
                temporalIdNested = b & 0x6 >> 1
                lengthSizeMinusOne = b & 0x3
                numberOfArrays = try buffer.readUInt8()
                for _ in 0 ..< numberOfArrays {
                    let a = try buffer.readUInt8()
                    let nalUnitType = HevcNalUnitType(rawValue: a & 0b0011_1111) ?? .unspec
                    array[nalUnitType] = []
                    let numNalus = try buffer.readUInt16()
                    for _ in 0 ..< numNalus {
                        let length = try buffer.readUInt16()
                        try array[nalUnitType]?.append(buffer.readBytes(Int(length)))
                    }
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
