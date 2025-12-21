@testable import Moblin
import SwiftUI
import Testing

struct LutEffectSuite {
    @Test
    func appleLogToRec709() async throws {
        let image = try UIImage(data: readMainFile(name: "LUTs.bundle/Apple Log To Rec 709", suffix: "png"))!
        let (dimension, data) = try lutEffectConvertLut(image: image)
        #expect(dimension == 64)
        #expect(data.count == 4_194_304)
    }

    @Test
    func dither64() async throws {
        let image = try UIImage(data: readTestFile(name: "dither64", suffix: "png"))!
        #expect(throws: String(localized: "LUT image is not 3 or 4 components per pixel")) {
            _ = try lutEffectConvertLut(image: image)
        }
    }
}
