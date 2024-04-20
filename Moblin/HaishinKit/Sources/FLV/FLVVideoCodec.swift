import Foundation

/// The type of flv supports video codecs.
enum FLVVideoCodec: UInt8 {
    /// The JPEG codec.
    case jpeg = 1
    /// The Sorenson H263 codec.
    case sorensonH263 = 2
    /// The Screen video codec.
    case screen1 = 3
    /// The On2 VP6 codec.
    case on2VP6 = 4
    /// The On2 VP6 with alpha channel codec.
    case on2VP6Alpha = 5
    /// The Screen video version2 codec.
    case screen2 = 6
    /// The AVC codec.
    case avc = 7
    /// The unknown codec.
    case unknown = 0xFF
}
