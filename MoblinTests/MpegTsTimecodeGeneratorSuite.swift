import AVFoundation
@testable import Moblin
import Testing

private let noon = Date(timeIntervalSince1970: 1_755_864_000).timeIntervalSince1970

private func presentationTimeStamp(_ frameNumber: Int, _ fps: Int) -> CMTime {
    CMTime(value: Int64(frameNumber), timescale: Int32(fps))
}

private func makeTimecodes(_ generator: MpegTsTimecodeGenerator,
                           _ fps: Int,
                           _ count: Int,
                           firstFrameNumber: Int = 0) -> [MpegTsTimecode]
{
    (firstFrameNumber ..< firstFrameNumber + count).compactMap {
        let timeStamp = presentationTimeStamp($0, fps)
        return generator.makeTimecode(timeStamp, timeStamp)
    }
}

private func makeGenerator(_ base: Double = noon) -> MpegTsTimecodeGenerator {
    let generator = MpegTsTimecodeGenerator()
    generator.setReference(now: base, presentationTimeStamp: 0)
    return generator
}

private func timeOfDay(_ timecode: MpegTsTimecode, _ fps: Int) -> Double {
    let components = calendar.dateComponents([.hour, .minute, .second], from: timecode.clock)
    let seconds = 3600 * components.hour! + 60 * components.minute! + components.second!
    return Double(seconds) + Double(timecode.frame) / Double(fps)
}

struct MpegTsTimecodeGeneratorSuite {
    @Test
    func noTimecodesBeforeReferenceIsSet() {
        let generator = MpegTsTimecodeGenerator()
        #expect(generator.hasReference() == false)
        #expect(generator.makeTimecode(presentationTimeStamp(0, 30), presentationTimeStamp(0, 30)) == nil)
        generator.setReference(now: noon, presentationTimeStamp: 0)
        #expect(generator.hasReference() == true)
        #expect(generator.makeTimecode(presentationTimeStamp(0, 30), presentationTimeStamp(0, 30)) != nil)
    }

    @Test
    func resetForgetsTheReference() {
        let generator = makeGenerator()
        _ = makeTimecodes(generator, 30, 30)
        generator.reset()
        #expect(generator.hasReference() == false)
        #expect(generator.makeTimecode(presentationTimeStamp(0, 30), presentationTimeStamp(0, 30)) == nil)
    }

    @Test
    func clockIsReferenceTimePlusPresentationTimeStamp() {
        let generator = makeGenerator()
        let timecodes = makeTimecodes(generator, 30, 300)
        #expect(timecodes[0].clock.timeIntervalSince1970 == noon)
        for (frameNumber, timecode) in timecodes.enumerated().dropFirst() {
            let offset = timecode.clock.timeIntervalSince1970 - noon - Double(frameNumber) / 30
            #expect(offset >= 0, "frame \(frameNumber)")
            #expect(offset < 1.0 / 30, "frame \(frameNumber)")
        }
    }

    @Test
    func referenceIsPresentationTimeStampBaseNotTheFirstFrame() {
        let generator = MpegTsTimecodeGenerator()
        generator.setReference(now: noon, presentationTimeStamp: 100)
        let timecodes = makeTimecodes(generator, 30, 1, firstFrameNumber: 30 * 110)
        #expect(timecodes[0].clock.timeIntervalSince1970 == noon + 10)
    }

    @Test
    func clockIsSplitIntoHoursMinutesAndSecondsInUtc() {
        let generator = makeGenerator()
        let timecodes = makeTimecodes(generator, 30, 30 * 62)
        #expect(timeOfDay(timecodes[0], 30) == 12 * 3600)
        #expect(timeOfDay(timecodes[30 * 61], 30) == 12 * 3600 + 61)
    }

    @Test(arguments: [24, 25, 30, 50, 60])
    func frameNumberCountsUpAndWrapsOncePerSecond(fps: Int) {
        let generator = makeGenerator()
        _ = makeTimecodes(generator, fps, fps)
        let frames = makeTimecodes(generator, fps, 5 * fps, firstFrameNumber: fps).map(\.frame)
        #expect(frames.allSatisfy { $0 < fps })
        #expect(frames.count == 5 * fps)
        for (previous, current) in zip(frames, frames.dropFirst()) {
            #expect(current == (previous + 1) % UInt32(fps))
        }
        #expect(frames.filter { $0 == 0 }.count == 5)
    }

    @Test(arguments: [24, 25, 30, 50, 60])
    func timeOfDayTracksThePresentationTimeStamp(fps: Int) {
        let generator = makeGenerator()
        _ = makeTimecodes(generator, fps, fps)
        let timecodes = makeTimecodes(generator, fps, 5 * fps, firstFrameNumber: fps)
        let offsets = timecodes.enumerated().map { index, timecode in
            timeOfDay(timecode, fps) - Double(fps + index) / Double(fps)
        }
        let median = offsets.sorted()[offsets.count / 2]
        #expect(offsets.allSatisfy { abs($0 - median) < 1.0 / Double(fps) })
        #expect(abs(median - 12 * 3600) < 1.0 / Double(fps))
    }

    @Test
    func timeOfDayTracksThePresentationTimeStampOverAMinute() {
        let generator = makeGenerator()
        let timecodes = makeTimecodes(generator, 30, 30 * 60)
        let offsets = timecodes.enumerated().map { index, timecode in
            timeOfDay(timecode, 30) - Double(index) / 30
        }
        let first = offsets.prefix(30).sorted()[15]
        let last = offsets.suffix(30).sorted()[15]
        #expect(abs(last - first) < 2.0 / 30)
    }

    @Test
    func invalidDecodeTimeStampFallsBackToPresentationTimeStamp() {
        let withDecodeTimeStamps = makeGenerator()
        let withoutDecodeTimeStamps = makeGenerator()
        for frameNumber in 0 ..< 90 {
            let timeStamp = presentationTimeStamp(frameNumber, 30)
            let withDecodeTimeStamp = withDecodeTimeStamps.makeTimecode(timeStamp, timeStamp)
            let withoutDecodeTimeStamp = withoutDecodeTimeStamps.makeTimecode(timeStamp, .invalid)
            #expect(withDecodeTimeStamp?.clock == withoutDecodeTimeStamp?.clock)
            #expect(withDecodeTimeStamp?.frame == withoutDecodeTimeStamp?.frame)
        }
    }

    @Test
    func reorderedPresentationTimeStampsDoNotBreakFrameNumbers() {
        let generator = makeGenerator()
        var timecodes: [MpegTsTimecode] = []
        for groupOfPictures in 0 ..< 20 {
            for (presentationOffset, decodeOffset) in [(2, 0), (0, 1), (1, 2)] {
                let presentation = presentationTimeStamp(3 * groupOfPictures + presentationOffset, 30)
                let decode = presentationTimeStamp(3 * groupOfPictures + decodeOffset, 30)
                guard let timecode = generator.makeTimecode(presentation, decode) else {
                    continue
                }
                timecodes.append(timecode)
            }
        }
        #expect(timecodes.count == 60)
        #expect(timecodes.allSatisfy { $0.frame < 30 })
        for (index, timecode) in timecodes.enumerated().dropFirst(30) {
            #expect(abs(timeOfDay(timecode, 30) - timecode.clock.timeIntervalSince1970
                        .truncatingRemainder(dividingBy: 86400)) < 1.0 / 30,
            "frame \(index)")
        }
    }
}
