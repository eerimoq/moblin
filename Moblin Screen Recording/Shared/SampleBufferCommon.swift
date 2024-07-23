import AVFoundation
import CoreFoundation
import UIKit
import VideoToolbox

// | 4b header size | <m>b header | <n>b buffer |

enum SampleBufferType: Codable {
    case videoFormat
    case videoBuffer
    case audioFormat
    case audioBuffer
}

struct SampleBufferHeader: Codable {
    var type: SampleBufferType
    var size: Int
    var presentationTimeStamp: Double
    var isSync: Bool
}

func createContainerDir(appGroup: String) throws -> URL {
    guard let containerDir = FileManager.default
        .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    else {
        throw "Failed to create container directory"
    }
    try FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
    return containerDir
}

func createSocketPath(containerDir: URL) -> URL {
    return containerDir.appendingPathComponent("sb.sock")
}

func removeFile(path: URL) {
    do {
        try FileManager.default.removeItem(at: path)
    } catch {}
}

func createAddr(path: URL) throws -> sockaddr_un {
    let path = path.path
    var addr = sockaddr_un()
    addr.sun_family = sa_family_t(AF_UNIX)
    let pathLength = path.withCString { Int(strlen($0)) }
    guard MemoryLayout.size(ofValue: addr.sun_path) > pathLength else {
        throw "sample-buffer: unix socket path \(path) too long"
    }
    _ = withUnsafeMutablePointer(to: &addr.sun_path.0) { addrPtr in
        path.withCString {
            strncpy(addrPtr, $0, pathLength)
        }
    }
    return addr
}

func createSocket() throws -> Int32 {
    let fd = Darwin.socket(AF_UNIX, SOCK_STREAM, 0)
    if fd == -1 {
        throw "Failed to create unix socket"
    }
    return fd
}

func setIgnoreSigPipe(fd: Int32) throws {
    var on: Int32 = 1
    if setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &on, socklen_t(MemoryLayout<Int32>.size)) == -1 {
        throw "Failed to set ignore sigpipe"
    }
}

protocol VideoEncoderDelegate: AnyObject {
    func videoEncoderOutputFormat(_ formatDescription: CMFormatDescription)
    func videoEncoderOutputSampleBuffer(_ sampleBuffer: CMSampleBuffer)
}

class VideoEncoder {
    weak var delegate: (any VideoEncoderDelegate)?
    private var session: VTCompressionSession?
    var formatDescription: CMFormatDescription? {
        didSet {
            guard !CMFormatDescriptionEqual(formatDescription, otherFormatDescription: oldValue) else {
                return
            }
            guard let formatDescription else {
                return
            }
            delegate?.videoEncoderOutputFormat(formatDescription)
        }
    }

    init(width: Int32, height: Int32) {
        session = makeCompressionSession(width: width, height: height)
    }

    func appendImageBuffer(_ imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration _: CMTime) {
        guard let session else {
            return
        }
        _ = VTCompressionSessionEncodeFrame(
            session,
            imageBuffer: imageBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: .invalid,
            frameProperties: nil,
            infoFlagsOut: nil,
            outputHandler: { [unowned self] status, _, sampleBuffer in
                guard let sampleBuffer, status == noErr else {
                    return
                }
                formatDescription = sampleBuffer.formatDescription
                delegate?.videoEncoderOutputSampleBuffer(sampleBuffer)
            }
        )
    }
}

private func makeCompressionSession(width: Int32, height: Int32) -> VTCompressionSession? {
    var session: VTCompressionSession?
    let attributes: [NSString: AnyObject] = [
        kCVPixelBufferPixelFormatTypeKey: NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
        kCVPixelBufferWidthKey: NSNumber(value: width),
        kCVPixelBufferHeightKey: NSNumber(value: height),
    ]
    var status = VTCompressionSessionCreate(
        allocator: kCFAllocatorDefault,
        width: width,
        height: height,
        codecType: kCMVideoCodecType_HEVC,
        encoderSpecification: nil,
        imageBufferAttributes: attributes as CFDictionary?,
        compressedDataAllocator: nil,
        outputCallback: nil,
        refcon: nil,
        compressionSessionOut: &session
    )
    guard status == noErr, let session else {
        return nil
    }
    let options: [NSString: AnyObject] = [
        kVTCompressionPropertyKey_RealTime: kCFBooleanTrue,
        kVTCompressionPropertyKey_ProfileLevel: kVTProfileLevel_HEVC_Main_AutoLevel as NSObject,
        kVTCompressionPropertyKey_AverageBitRate: 10_000_000 as CFNumber,
        kVTCompressionPropertyKey_ExpectedFrameRate: 30 as CFNumber,
        kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration: 2 as NSNumber,
        kVTCompressionPropertyKey_AllowFrameReordering: kCFBooleanFalse,
        kVTCompressionPropertyKey_PixelTransferProperties: ["ScalingMode": "Trim"] as NSObject,
    ]
    status = VTSessionSetProperties(session, propertyDictionary: options as CFDictionary)
    guard status == noErr else {
        return nil
    }
    status = VTCompressionSessionPrepareToEncodeFrames(session)
    guard status == noErr else {
        return nil
    }
    return session
}
