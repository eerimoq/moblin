import AVFoundation
import VideoToolbox

/*
 - seealso: ISO/IEC 14496-15 2010
 */
struct MpegTsVideoConfigAvc: MpegTsVideoConfig {
    static func getData(_ formatDescription: CMFormatDescription) -> Data? {
        if let atoms = CMFormatDescriptionGetExtension(
            formatDescription,
            extensionKey: "SampleDescriptionExtensionAtoms" as CFString
        ) as? NSDictionary {
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
    var sequenceParameterSets: [[UInt8]] = []
    var pictureParameterSets: [[UInt8]] = []

    init() {}

    init(data: Data) {
        self.data = data
    }

    func makeFormatDescription(_ formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>)
        -> OSStatus
    {
        return pictureParameterSets[0].withUnsafeBytes { (ppsBuffer: UnsafeRawBufferPointer) -> OSStatus in
            guard let ppsBaseAddress = ppsBuffer.baseAddress else {
                return kCMFormatDescriptionBridgeError_InvalidParameter
            }
            return sequenceParameterSets[0]
                .withUnsafeBytes { (spsBuffer: UnsafeRawBufferPointer) -> OSStatus in
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

    var data: Data {
        get {
            let buffer = ByteArray()
                .writeUInt8(configurationVersion)
                .writeUInt8(avcProfileIndication)
                .writeUInt8(profileCompatibility)
                .writeUInt8(avcLevelIndication)
                .writeUInt8(lengthSizeMinusOneWithReserved)
                .writeUInt8(numOfSequenceParameterSetsWithReserved)
            for i in 0 ..< sequenceParameterSets.count {
                buffer
                    .writeUInt16(UInt16(sequenceParameterSets[i].count))
                    .writeBytes(Data(sequenceParameterSets[i]))
            }
            buffer.writeUInt8(UInt8(pictureParameterSets.count))
            for i in 0 ..< pictureParameterSets.count {
                buffer
                    .writeUInt16(UInt16(pictureParameterSets[i].count))
                    .writeBytes(Data(pictureParameterSets[i]))
            }
            return buffer.data
        }
        set {
            let buffer = ByteArray(data: newValue)
            do {
                configurationVersion = try buffer.readUInt8()
                avcProfileIndication = try buffer.readUInt8()
                profileCompatibility = try buffer.readUInt8()
                avcLevelIndication = try buffer.readUInt8()
                lengthSizeMinusOneWithReserved = try buffer.readUInt8()
                numOfSequenceParameterSetsWithReserved = try buffer.readUInt8()
                let numOfSequenceParameterSets: UInt8 = numOfSequenceParameterSetsWithReserved &
                    ~MpegTsVideoConfigAvc.reserveNumOfSequenceParameterSets
                for _ in 0 ..< numOfSequenceParameterSets {
                    let length = try Int(buffer.readUInt16())
                    try sequenceParameterSets.append(buffer.readBytes(length).bytes)
                }
                let numPictureParameterSets: UInt8 = try buffer.readUInt8()
                for _ in 0 ..< numPictureParameterSets {
                    let length = try Int(buffer.readUInt16())
                    try pictureParameterSets.append(buffer.readBytes(length).bytes)
                }
            } catch {
                logger.error("\(buffer)")
            }
        }
    }
}
