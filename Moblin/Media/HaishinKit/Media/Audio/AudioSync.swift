import Accelerate
import Foundation

let audioSyncFrames = 1 << 18
let audioSyncPreRollFrames: Int64 = 12000
private let log2Frames = vDSP_Length(18)
private let chirpFrames = 6000
private let chirpRampFrames = 480
private let chirpLowFrequency = 1000.0
private let chirpHighFrequency = 6000.0
private let chirpStarts = [0, 19200, 44160, 76800]
private let chirpUps = [true, false, true, false]
private let signalLevel: Float = 0.7
private let binsPerHertz = Double(audioSyncFrames) / audioMixerSampleRate
private let lowBin = Int(chirpLowFrequency * binsPerHertz) + 1
private let numberOfBins = Int(chirpHighFrequency * binsPerHertz) - lowBin + 1
private let blockFrames = 96
private let toleranceFrames = 144
private let echoFrames = 1440
private let ambiguityBlocks = 25
private let numberOfBlocks = (audioSyncFrames - chirpStarts.last! - chirpFrames) / blockFrames - 1
private let medianStride = 16
private let minimumPeak: Float = 4
private let firstArrivalRatio: Float = 0.5
private let maximumAmbiguity: Float = 0.7
private let maximumSpread = 96.0

struct AudioSyncArrival {
    let frame: Double
    let numberOfChirps: Int
    let spread: Double
    let quality: Float

    var isGood: Bool {
        numberOfChirps == chirpStarts.count && quality >= 18 && spread <= 12
    }
}

enum AudioSyncError: Error {
    case notHeard
    case ambiguous
    case moved
}

func makeAudioSyncChirp(up: Bool) -> [Float] {
    let rate = (chirpHighFrequency - chirpLowFrequency) * audioMixerSampleRate / Double(chirpFrames)
    let chirp = (0 ..< chirpFrames).map { frame in
        let time = Double(frame) / audioMixerSampleRate
        let edge = Double(min(frame, chirpFrames - 1 - frame)) + 0.5
        let gain = 0.5 - 0.5 * cos(.pi * min(1, edge / Double(chirpRampFrames)))
        return Float(gain * cos(2 * .pi * (chirpLowFrequency * time + 0.5 * rate * time * time)))
    }
    return up ? chirp : chirp.reversed()
}

func makeAudioSyncSignal() -> [Float] {
    var signal = [Float](repeating: 0, count: chirpStarts.last! + chirpFrames)
    for (start, up) in zip(chirpStarts, chirpUps) {
        for (frame, sample) in makeAudioSyncChirp(up: up).enumerated() {
            signal[start + frame] = signalLevel * sample
        }
    }
    return signal
}

func makeAudioSyncDelays(arrivals: [String: Double], delays: [String: Double],
                         anchor: String) -> [String: Double]
{
    guard let anchorArrival = arrivals[anchor], let anchorDelay = delays[anchor] else {
        return [:]
    }
    return arrivals.mapValues { anchorDelay + (anchorArrival - $0) / audioMixerSampleRate }
}

private func makeSplitComplex(_ count: Int) -> DSPSplitComplex {
    DSPSplitComplex(realp: makeAudioMixerSamples(count: count), imagp: makeAudioMixerSamples(count: count))
}

private func deallocate(_ splitComplex: DSPSplitComplex) {
    splitComplex.realp.deallocate()
    splitComplex.imagp.deallocate()
}

// Finds the sync signal in a window of audioSyncFrames frames by matched filtering. The returned
// frame is where the signal starts in the window.
final class AudioSyncDetector {
    private let setup = vDSP_create_fftsetup(log2Frames, FFTRadix(kFFTRadix2))!
    private var spectrum = makeSplitComplex(audioSyncFrames)
    private var product = makeSplitComplex(audioSyncFrames)
    private var references = [makeSplitComplex(numberOfBins), makeSplitComplex(numberOfBins)]
    private let envelopes = [
        makeAudioMixerSamples(count: audioSyncFrames),
        makeAudioMixerSamples(count: audioSyncFrames),
    ]
    private let maximums = [
        makeAudioMixerSamples(count: audioSyncFrames),
        makeAudioMixerSamples(count: audioSyncFrames),
    ]
    private let score = makeAudioMixerSamples(count: numberOfBlocks)
    private let sorted = makeAudioMixerSamples(count: audioSyncFrames / medianStride)

    init() {
        let weights = (0 ..< numberOfBins).map {
            Float(0.54 - 0.46 * cos(2 * .pi * Double($0) / Double(numberOfBins - 1)))
        }
        for (index, up) in [true, false].enumerated() {
            transform(makeAudioSyncChirp(up: up), chirpFrames)
            vDSP_vmul(
                spectrum.realp + lowBin,
                1,
                weights,
                1,
                references[index].realp,
                1,
                vDSP_Length(numberOfBins)
            )
            vDSP_vmul(
                spectrum.imagp + lowBin,
                1,
                weights,
                1,
                references[index].imagp,
                1,
                vDSP_Length(numberOfBins)
            )
        }
    }

    deinit {
        vDSP_destroy_fftsetup(setup)
        for splitComplex in [spectrum, product] + references {
            deallocate(splitComplex)
        }
        for samples in envelopes + maximums + [score, sorted] {
            samples.deallocate()
        }
    }

    func detect(_ samples: [Float]) -> Result<AudioSyncArrival, AudioSyncError> {
        precondition(samples.count == audioSyncFrames)
        transform(samples, audioSyncFrames)
        for index in 0 ..< 2 {
            guard correlate(&references[index], envelopes[index], maximums[index]) else {
                return .failure(.notHeard)
            }
        }
        vDSP_vclr(score, 1, vDSP_Length(numberOfBlocks))
        for (start, up) in zip(chirpStarts, chirpUps) {
            vDSP_vadd(
                maximums[up ? 0 : 1] + start,
                blockFrames,
                score,
                1,
                score,
                1,
                vDSP_Length(numberOfBlocks)
            )
        }
        var peak: Float = 0
        var block: vDSP_Length = 0
        vDSP_maxvi(score, 1, &peak, &block, vDSP_Length(numberOfBlocks))
        var arrivals: [Double] = []
        var weakestPeak = Float.infinity
        for (start, up) in zip(chirpStarts, chirpUps) {
            let envelope = envelopes[up ? 0 : 1]
            let first = max(Int(block) * blockFrames + start - toleranceFrames, 1)
            var chirpPeak: Float = 0
            var offset: vDSP_Length = 0
            vDSP_maxvi(
                envelope + first,
                1,
                &chirpPeak,
                &offset,
                vDSP_Length(blockFrames + 2 * toleranceFrames)
            )
            guard chirpPeak >= minimumPeak else {
                continue
            }
            let threshold = max(firstArrivalRatio * chirpPeak, minimumPeak)
            let frame = findFirstArrival(envelope, first + Int(offset), threshold)
            arrivals.append(interpolate(envelope, frame) - Double(start))
            weakestPeak = min(weakestPeak, chirpPeak)
        }
        guard arrivals.count >= 3 else {
            return .failure(.notHeard)
        }
        let low = max(Int(block) - ambiguityBlocks, 0)
        let high = min(Int(block) + ambiguityBlocks + 1, numberOfBlocks)
        vDSP_vclr(score + low, 1, vDSP_Length(high - low))
        var otherPeak: Float = 0
        vDSP_maxv(score, 1, &otherPeak, vDSP_Length(numberOfBlocks))
        guard otherPeak <= maximumAmbiguity * peak else {
            return .failure(.ambiguous)
        }
        arrivals.sort()
        let spread = arrivals.last! - arrivals.first!
        guard spread <= maximumSpread else {
            return .failure(.moved)
        }
        let middle = arrivals.count / 2
        let frame = arrivals.count % 2 == 1 ? arrivals[middle] : (arrivals[middle - 1] + arrivals[middle]) / 2
        return .success(AudioSyncArrival(frame: frame,
                                         numberOfChirps: arrivals.count,
                                         spread: spread,
                                         quality: 20 * log10(weakestPeak)))
    }

    private func transform(_ samples: UnsafePointer<Float>, _ count: Int) {
        vDSP_vclr(spectrum.realp, 1, vDSP_Length(audioSyncFrames))
        vDSP_vclr(spectrum.imagp, 1, vDSP_Length(audioSyncFrames))
        spectrum.realp.update(from: samples, count: count)
        vDSP_fft_zip(setup, &spectrum, 1, log2Frames, FFTDirection(kFFTDirection_Forward))
    }

    // Only positive frequencies are kept, so the inverse transform is the analytic correlation and
    // its magnitude the envelope. The envelope is normalized by its median, so every threshold is a
    // multiple of the noise.
    private func correlate(_ reference: inout DSPSplitComplex,
                           _ envelope: UnsafeMutablePointer<Float>,
                           _ maximum: UnsafeMutablePointer<Float>) -> Bool
    {
        let frames = vDSP_Length(audioSyncFrames)
        vDSP_vclr(product.realp, 1, frames)
        vDSP_vclr(product.imagp, 1, frames)
        var input = DSPSplitComplex(realp: spectrum.realp + lowBin, imagp: spectrum.imagp + lowBin)
        var output = DSPSplitComplex(realp: product.realp + lowBin, imagp: product.imagp + lowBin)
        vDSP_zvmul(&reference, 1, &input, 1, &output, 1, vDSP_Length(numberOfBins), -1)
        vDSP_fft_zip(setup, &product, 1, log2Frames, FFTDirection(kFFTDirection_Inverse))
        vDSP_zvabs(&product, 1, envelope, 1, frames)
        let count = vDSP_Length(audioSyncFrames / medianStride)
        var one: Float = 1
        vDSP_vsmul(envelope, medianStride, &one, sorted, 1, count)
        vDSP_vsort(sorted, count, 1)
        var median = max(sorted[Int(count) / 2], sorted[Int(count) - 1] / 1000)
        guard median > 0 else {
            return false
        }
        vDSP_vsdiv(envelope, 1, &median, envelope, 1, frames)
        vDSP_vswmax(
            envelope,
            1,
            maximum,
            1,
            vDSP_Length(audioSyncFrames - blockFrames + 1),
            vDSP_Length(blockFrames)
        )
        return true
    }

    // The earliest local maximum of at least the threshold, at most 30 ms before the peak. A
    // reflection can be stronger than the direct path.
    private func findFirstArrival(_ envelope: UnsafePointer<Float>, _ peak: Int, _ threshold: Float) -> Int {
        for frame in max(peak - echoFrames, 1) ..< peak
            where envelope[frame] >= threshold && envelope[frame] >= envelope[frame - 1]
            && envelope[frame] > envelope[frame + 1]
        {
            return frame
        }
        return peak
    }

    private func interpolate(_ envelope: UnsafePointer<Float>, _ frame: Int) -> Double {
        let before = Double(envelope[frame - 1])
        let after = Double(envelope[frame + 1])
        let curvature = before - 2 * Double(envelope[frame]) + after
        return Double(frame) + (curvature < 0 ? 0.5 * (before - after) / curvature : 0)
    }
}
