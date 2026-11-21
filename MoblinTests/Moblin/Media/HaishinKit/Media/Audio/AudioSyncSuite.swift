import AVFoundation
@testable import Moblin
import Testing

private let sampleRate = 48000.0
private let chirpFrames = 6000.0
private let chirpStarts = [0.0, 19200, 44160, 76800]
private let chirpUps = [true, false, true, false]

private struct Noise {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    private mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return (Double(state >> 11) + 0.5) / Double(1 << 53)
    }

    mutating func gaussian() -> Float {
        Float(sqrt(-2 * log(next())) * cos(2 * .pi * next()))
    }
}

// The sync chirp evaluated at any position, so that fractional delays are exact.
private func createChirp(_ position: Double, up: Bool, maximumFrequency: Double) -> Float {
    let last = chirpFrames - 1
    guard position >= 0, position <= last else {
        return 0
    }
    let frame = up ? position : last - position
    let rate = 5000 * sampleRate / chirpFrames
    let time = frame / sampleRate
    guard 1000 + rate * time <= maximumFrequency else {
        return 0
    }
    let edge = min(frame, last - frame) + 0.5
    let gain = 0.5 - 0.5 * cos(.pi * min(1, edge / 480))
    return Float(0.7 * gain * cos(2 * .pi * (1000 * time + 0.5 * rate * time * time)))
}

private struct Burst {
    var offset: Double
    var level: Float = 1
    var chirps: Set<Int> = [0, 1, 2, 3]
    var stretch = 0.0
    var clockRatio = 1.0
    var maximumFrequency = 24000.0
}

private func createWindow(_ bursts: [Burst], noise: Float = 0, seed: UInt64 = 1) -> [Float] {
    var samples = [Float](repeating: 0, count: audioSyncFrames)
    for burst in bursts {
        for chirp in burst.chirps {
            let start = burst.offset + (chirpStarts[chirp] + burst.stretch * Double(chirp) / 3) * burst
                .clockRatio
            let first = max(Int(start.rounded(.down)), 0)
            let last = min(Int((start + chirpFrames * burst.clockRatio).rounded(.up)), audioSyncFrames - 1)
            guard first <= last else {
                continue
            }
            for frame in first ... last {
                let position = (Double(frame) - start) / burst.clockRatio
                samples[frame] += burst.level * createChirp(position,
                                                            up: chirpUps[chirp],
                                                            maximumFrequency: burst.maximumFrequency)
            }
        }
    }
    if noise > 0 {
        var generator = Noise(seed: seed)
        for frame in samples.indices {
            samples[frame] += noise * generator.gaussian()
        }
    }
    return samples
}

// White noise level for an in-band (1 to 6 kHz) SNR against the chirp at full level.
private func createNoiseLevel(snr: Double) -> Float {
    let chirpPower = 0.7 * 0.7 / 2
    let inBandFraction = 5000 / (sampleRate / 2)
    return Float(sqrt(chirpPower / pow(10, snr / 10) / inBandFraction))
}

private func detect(_ samples: [Float]) -> Result<AudioSyncArrival, AudioSyncError> {
    AudioSyncDetector().detect(samples)
}

private func detectFrame(_ samples: [Float]) -> AudioSyncArrival? {
    try? detect(samples).get()
}

private func isFailure(_ result: Result<AudioSyncArrival, AudioSyncError>, _ error: AudioSyncError) -> Bool {
    if case let .failure(actual) = result {
        return actual == error
    }
    return false
}

private func aacRoundTrip(_ samples: [Float], bitRate: Int) -> [Float]? {
    let pcmFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                  sampleRate: sampleRate,
                                  channels: 1,
                                  interleaved: false)!
    var description = AudioStreamBasicDescription(mSampleRate: sampleRate,
                                                  mFormatID: kAudioFormatMPEG4AAC,
                                                  mFormatFlags: 0,
                                                  mBytesPerPacket: 0,
                                                  mFramesPerPacket: 1024,
                                                  mBytesPerFrame: 0,
                                                  mChannelsPerFrame: 1,
                                                  mBitsPerChannel: 0,
                                                  mReserved: 0)
    guard let aacFormat = AVAudioFormat(streamDescription: &description),
          let encoder = AVAudioConverter(from: pcmFormat, to: aacFormat),
          let decoder = AVAudioConverter(from: aacFormat, to: pcmFormat)
    else {
        return nil
    }
    encoder.bitRate = bitRate
    let input = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 1024)!
    let packet = AVAudioCompressedBuffer(format: aacFormat,
                                         packetCapacity: 1,
                                         maximumPacketSize: max(encoder.maximumOutputPacketSize, 1))
    let decoded = AVAudioPCMBuffer(pcmFormat: pcmFormat, frameCapacity: 4096)!
    var position = 0
    var output: [Float] = []
    for _ in 0 ..< samples.count / 1024 + 8 where output.count < samples.count {
        let status = encoder.convert(to: packet, error: nil) { _, inputStatus in
            input.frameLength = 1024
            let count = max(min(1024, samples.count - position), 0)
            let data = input.floatChannelData![0]
            data.update(repeating: 0, count: 1024)
            if count > 0 {
                samples.withUnsafeBufferPointer {
                    data.update(from: $0.baseAddress! + position, count: count)
                }
            }
            position += 1024
            inputStatus.pointee = .haveData
            return input
        }
        guard status == .haveData else {
            return nil
        }
        var isPacketConsumed = false
        decoded.frameLength = 0
        let decodeStatus = decoder.convert(to: decoded, error: nil) { _, inputStatus in
            if isPacketConsumed {
                inputStatus.pointee = .noDataNow
                return nil
            }
            isPacketConsumed = true
            inputStatus.pointee = .haveData
            return packet
        }
        guard decodeStatus != .error else {
            return nil
        }
        let data = decoded.floatChannelData![0]
        output += (0 ..< Int(decoded.frameLength)).map { data[$0] }
    }
    guard output.count >= samples.count else {
        return nil
    }
    return Array(output.prefix(samples.count))
}

struct AudioSyncSuite {
    @Test
    func signalIsFourChirps() throws {
        let signal = makeAudioSyncSignal()
        let expected = createWindow([Burst(offset: 0)])
        #expect(signal.count == 82800)
        #expect(try #require(zip(signal, expected).map { abs($0 - $1) }.max()) < 1e-5)
        #expect(try abs(#require(signal.map(abs).max()) - 0.7) < 1e-3)
    }

    @Test(arguments: [12000.0, 100_003, 170_000])
    func findsIntegerOffsets(_ offset: Double) throws {
        let arrival = try detect(createWindow([Burst(offset: offset)])).get()
        #expect(abs(arrival.frame - offset) < 0.05)
        #expect(arrival.numberOfChirps == 4)
        #expect(arrival.spread < 0.5)
        #expect(arrival.isGood)
    }

    @Test(arguments: [0.25, 0.5, 0.75])
    func findsFractionalOffsets(_ fraction: Double) throws {
        let offset = 54321 + fraction
        let arrival = try detect(createWindow([Burst(offset: offset)])).get()
        #expect(abs(arrival.frame - offset) < 0.1)
    }

    @Test
    func measuresDifferenceBetweenTwoSources() throws {
        let first = try detect(createWindow([Burst(offset: 15000)], noise: 0.05, seed: 3)).get()
        let second = try detect(createWindow([Burst(offset: 15000 + 59256.4)], noise: 0.05, seed: 4)).get()
        #expect(abs(second.frame - first.frame - 59256.4) < 0.5)
    }

    @Test(arguments: [-6.0, -10.0])
    func findsSignalInNoise(_ snr: Double) throws {
        let offset = 33333.0
        let samples = createWindow([Burst(offset: offset)], noise: createNoiseLevel(snr: snr), seed: 7)
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - offset) < 2)
    }

    @Test
    func rejectsSignalBelowNoise() {
        let samples = createWindow([Burst(offset: 33333)], noise: createNoiseLevel(snr: -25), seed: 11)
        #expect(detectFrame(samples) == nil)
    }

    @Test(arguments: [1, 2, 3])
    func rejectsNoiseOnly(_ seed: UInt64) {
        #expect(isFailure(detect(createWindow([], noise: 0.3, seed: seed)), .notHeard))
    }

    @Test
    func rejectsSilence() {
        #expect(isFailure(detect(createWindow([])), .notHeard))
    }

    @Test(arguments: [1000.0, 3000.0])
    func rejectsTones(_ frequency: Double) {
        let samples = (0 ..< audioSyncFrames).map {
            Float(0.5 * sin(2 * .pi * frequency * Double($0) / sampleRate))
        }
        #expect(detectFrame(samples) == nil)
    }

    @Test
    func rejectsSingleChirp() {
        #expect(detectFrame(createWindow([Burst(offset: 20000, chirps: [0])])) == nil)
    }

    @Test
    func rejectsTrainOfUpChirps() {
        let bursts = stride(from: 0.0, to: Double(audioSyncFrames) - chirpFrames, by: 24000).map {
            Burst(offset: $0, chirps: [0])
        }
        #expect(detectFrame(createWindow(bursts, noise: 0.01)) == nil)
    }

    @Test
    func rejectsTwoBursts() {
        let samples = createWindow([Burst(offset: 10000), Burst(offset: 120_000)], noise: 0.01)
        #expect(isFailure(detect(samples), .ambiguous))
    }

    @Test(arguments: [0, 1, 2, 3])
    func findsThreeChirps(_ missing: Int) throws {
        var chirps: Set = [0, 1, 2, 3]
        chirps.remove(missing)
        let arrival = try detect(createWindow([Burst(offset: 40000, chirps: chirps)], noise: 0.01)).get()
        #expect(abs(arrival.frame - 40000) < 0.5)
        #expect(arrival.numberOfChirps == 3)
        #expect(!arrival.isGood)
    }

    @Test
    func rejectsTwoChirps() {
        let samples = createWindow([Burst(offset: 40000, chirps: [0, 3])], noise: 0.01)
        #expect(isFailure(detect(samples), .notHeard))
    }

    @Test
    func findsInvertedSignal() throws {
        let samples = createWindow([Burst(offset: 23456.5)]).map { -$0 }
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 23456.5) < 0.5)
    }

    @Test(arguments: [0.05, 0.3])
    func findsClippedSignal(_ limit: Float) throws {
        let samples = createWindow([Burst(offset: 23456.5)], noise: 0.002).map { min(max($0, -limit), limit) }
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 23456.5) < 0.5)
    }

    @Test
    func findsQuietQuantizedSignal() throws {
        let samples = createWindow([Burst(offset: 23456.5)]).map { ($0 * 0.001 * 32768).rounded() / 32768 }
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 23456.5) < 0.5)
    }

    @Test
    func picksDirectPathBeforeStrongerReflection() throws {
        let samples = createWindow([Burst(offset: 30000, level: 0.7), Burst(offset: 30149)], noise: 0.002)
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 30000) < 0.5)
    }

    @Test
    func picksReflectionWhenDirectPathIsWeak() throws {
        let samples = createWindow([Burst(offset: 30000, level: 0.3), Burst(offset: 30149)], noise: 0.002)
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 30149) < 0.5)
    }

    @Test
    func picksDirectPathInReverberantNoise() throws {
        var samples = createWindow([Burst(offset: 30000, level: 0.7), Burst(offset: 30149)],
                                   noise: createNoiseLevel(snr: -6),
                                   seed: 5)
        let tail = createWindow([Burst(offset: 30600, level: 0.4), Burst(offset: 31500, level: 0.2)])
        for frame in samples.indices {
            samples[frame] += tail[frame]
        }
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 30000) < 2)
    }

    @Test
    func findsAmplitudeModulatedSignal() throws {
        let samples = createWindow([Burst(offset: 50000)]).enumerated().map { frame, sample in
            sample * Float(1 - 0.8 * (0.5 + 0.5 * sin(2 * .pi * 20 * Double(frame) / sampleRate)))
        }
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 50000) < 0.5)
    }

    @Test
    func findsNarrowbandSignal() throws {
        let samples = createWindow([Burst(offset: 50000, maximumFrequency: 3400)], noise: 0.002)
        let arrival = try detect(samples).get()
        #expect(abs(arrival.frame - 50000) < 2)
    }

    @Test(arguments: [(20.0, true), (60.0, true), (300.0, false)])
    func toleratesMovement(_ stretch: Double, _ detected: Bool) {
        let samples = createWindow([Burst(offset: 50000, stretch: stretch)], noise: 0.002)
        let result = detect(samples)
        if detected {
            let arrival = try? result.get()
            #expect(arrival != nil)
            #expect(abs((arrival?.spread ?? 0) - stretch) < 1)
        } else {
            #expect(isFailure(result, .moved))
        }
    }

    @Test
    func toleratesClockDrift() throws {
        let samples = createWindow([Burst(offset: 50000, clockRatio: 1.0001)], noise: 0.002)
        let arrival = try detect(samples).get()
        #expect(arrival.spread < 12)
        #expect(abs(arrival.frame - 50000) < 5)
    }

    @Test
    func rejectsSignalAtEndOfWindow() {
        let samples = createWindow([Burst(offset: Double(audioSyncFrames) - 70000)], noise: 0.002)
        #expect(detectFrame(samples) == nil)
    }

    @Test
    func findsSignalThroughAac() throws {
        let offsets = [20000.0, 60000.5, 110_000]
        let delays = try offsets.map { offset in
            let samples = createWindow([Burst(offset: offset)], noise: 0.002, seed: 9)
            let pcm = try detect(samples).get()
            guard let coded = aacRoundTrip(samples, bitRate: 64000) else {
                Issue.record("AAC round trip failed")
                return 0.0
            }
            let aac = try detect(coded).get()
            #expect(aac.numberOfChirps == 4)
            return aac.frame - pcm.frame
        }
        print("AAC delay \(delays) frames")
        #expect(try #require(delays.max()) - #require(delays.min()) < 2)
    }

    @Test
    func makesDelays() throws {
        let arrivals = ["a": 1000.0, "b": 1000 + 48000 * 0.5, "c": 1000 + 48000 * 1.25]
        let delays = ["a": 0.1, "b": 0.2, "c": 0.3]
        let toC = makeAudioSyncDelays(arrivals: arrivals, delays: delays, anchor: "c")
        #expect(toC["c"] == 0.3)
        #expect(try abs(#require(toC["a"]) - 1.55) < 1e-9)
        #expect(try abs(#require(toC["b"]) - 1.05) < 1e-9)
        let toA = makeAudioSyncDelays(arrivals: arrivals, delays: delays, anchor: "a")
        #expect(toA["a"] == 0.1)
        #expect(try abs(#require(toA["b"]) + 0.4) < 1e-9)
        #expect(try abs(#require(toA["c"]) + 1.15) < 1e-9)
        #expect(makeAudioSyncDelays(arrivals: ["a": 1, "b": 2], delays: delays, anchor: "c").isEmpty)
    }
}
