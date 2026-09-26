import CoreVideo
import Foundation

extension CVPixelBuffer {
    var width: Int {
        CVPixelBufferGetWidth(self)
    }

    var height: Int {
        CVPixelBufferGetHeight(self)
    }

    var size: CGSize {
        .init(width: width, height: height)
    }

    func isPortrait() -> Bool {
        height > width
    }

    var colorAttachments: [String: String] {
        var attachments: [String: String] = [:]
        for key in [
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferYCbCrMatrixKey,
        ] {
            if let value = CVBufferCopyAttachment(self, key, nil) as? String {
                attachments[key as String] = value
            }
        }
        return attachments
    }
}

let defaultColorAttachments: [String: String] = [
    kCVImageBufferColorPrimariesKey as String: kCVImageBufferColorPrimaries_ITU_R_709_2 as String,
    kCVImageBufferTransferFunctionKey as String: kCVImageBufferTransferFunction_ITU_R_709_2 as String,
    kCVImageBufferYCbCrMatrixKey as String: kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String,
]

let rec709ColorAttachments: [String: String] = [
    kCVImageBufferColorPrimariesKey as String: kCVImageBufferColorPrimaries_ITU_R_709_2 as String,
    kCVImageBufferTransferFunctionKey as String: kCVImageBufferTransferFunction_ITU_R_709_2 as String,
    kCVImageBufferYCbCrMatrixKey as String: kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String,
]

func sdrColorAttachments(pixelFormat: OSType) -> [String: String] {
    isVideoRangePixelFormat(pixelFormat) ? rec709ColorAttachments : defaultColorAttachments
}

func sdrYCbCrMatrix(pixelFormat: OSType) -> CFString {
    isVideoRangePixelFormat(pixelFormat) ? kCVImageBufferYCbCrMatrix_ITU_R_709_2 :
        kCVImageBufferYCbCrMatrix_ITU_R_601_4
}

let hlgColorAttachments: [String: String] = [
    kCVImageBufferColorPrimariesKey as String: kCVImageBufferColorPrimaries_ITU_R_2020 as String,
    kCVImageBufferTransferFunctionKey as String: kCVImageBufferTransferFunction_ITU_R_2100_HLG as String,
    kCVImageBufferYCbCrMatrixKey as String: kCVImageBufferYCbCrMatrix_ITU_R_2020 as String,
]
