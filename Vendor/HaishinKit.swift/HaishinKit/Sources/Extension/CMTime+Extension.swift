import AVFoundation
import Foundation

extension CMTime {
    func makeAudioTime() -> AVAudioTime {
        return .init(sampleTime: value, atRate: Double(timescale))
    }

    func convertTime(from: CMClock?, to: CMClock? = CMClockGetHostTimeClock()) -> CMTime {
        guard let from, let to else {
            return self
        }
        return from.convertTime(self, to: to)
    }
}
