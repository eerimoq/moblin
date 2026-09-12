import AVFoundation
@testable import Moblin
import Testing

struct AudioUnitSuite {
    @Test
    func calcAudioLevelPeakFloat32() {
        var samples: [Float32] = [0.1, -0.75, 0.5, -0.2]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakFloat32(samples: $0.baseAddress!, count: $0.count)
        }
        #expect(peak == 0.75)
    }

    @Test
    func calcAudioLevelPeakFloat32Empty() {
        var samples: [Float32] = [1.0]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakFloat32(samples: $0.baseAddress!, count: 0)
        }
        #expect(peak == 0.0)
    }

    @Test
    func calcAudioLevelPeakInt16() {
        var samples: [Int16] = [100, -3000, 2000, -50]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakInt16(samples: $0.baseAddress!, count: $0.count)
        }
        #expect(peak == 0.091552734)
    }

    @Test
    func calcAudioLevelPeakInt16Min() {
        var samples: [Int16] = [Int16.min, Int16.max]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakInt16(samples: $0.baseAddress!, count: $0.count)
        }
        #expect(peak == 1.0)
    }

    @Test
    func calcAudioLevelPeakInt16Empty() {
        var samples: [Int16] = [1000]
        let peak = samples.withUnsafeMutableBufferPointer {
            Moblin.calcAudioLevelPeakInt16(samples: $0.baseAddress!, count: 0)
        }
        #expect(peak == 0.0)
    }
}
