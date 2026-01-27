import AVFoundation
@testable import Moblin
import Testing

struct VideoDimensionsSuite {
    @Test
    func landscape16x9() {
        let resolution = CMVideoDimensions(width: 1920, height: 1080)
        #expect(resolution.convertTo(dimension: 720) == CMVideoDimensions(width: 1280, height: 720))
        #expect(resolution.convertTo(dimension: 480) == CMVideoDimensions(width: 854, height: 480))
        #expect(resolution.convertTo(dimension: 360) == CMVideoDimensions(width: 640, height: 360))
        #expect(resolution.convertTo(dimension: 160) == CMVideoDimensions(width: 284, height: 160))
    }

    @Test
    func portrait9x16() {
        let resolution = CMVideoDimensions(width: 1080, height: 1920)
        #expect(resolution.convertTo(dimension: 720) == CMVideoDimensions(width: 720, height: 1280))
        #expect(resolution.convertTo(dimension: 480) == CMVideoDimensions(width: 480, height: 854))
        #expect(resolution.convertTo(dimension: 360) == CMVideoDimensions(width: 360, height: 640))
        #expect(resolution.convertTo(dimension: 160) == CMVideoDimensions(width: 160, height: 284))
    }

    @Test
    func landscape4x3() {
        let resolution = CMVideoDimensions(width: 1920, height: 1440)
        #expect(resolution.convertTo(dimension: 1080) == CMVideoDimensions(width: 1440, height: 1080))
        #expect(resolution.convertTo(dimension: 720) == CMVideoDimensions(width: 960, height: 720))
        #expect(resolution.convertTo(dimension: 480) == CMVideoDimensions(width: 640, height: 480))
        #expect(resolution.convertTo(dimension: 360) == CMVideoDimensions(width: 480, height: 360))
        #expect(resolution.convertTo(dimension: 160) == CMVideoDimensions(width: 214, height: 160))
    }

    @Test
    func portrait4x3() {
        let resolution = CMVideoDimensions(width: 1440, height: 1920)
        #expect(resolution.convertTo(dimension: 1080) == CMVideoDimensions(width: 1080, height: 1440))
        #expect(resolution.convertTo(dimension: 720) == CMVideoDimensions(width: 720, height: 960))
        #expect(resolution.convertTo(dimension: 480) == CMVideoDimensions(width: 480, height: 640))
        #expect(resolution.convertTo(dimension: 360) == CMVideoDimensions(width: 360, height: 480))
        #expect(resolution.convertTo(dimension: 160) == CMVideoDimensions(width: 160, height: 214))
    }
}
