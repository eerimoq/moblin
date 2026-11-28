import AVFoundation
import Foundation

private let captureDelay = 5.7
private let retryDelay = 1.0

struct AudioSyncResult: Identifiable {
    let id: String
    let name: String
    let arrival: AudioSyncArrival?
    let failure: String?
}

@MainActor
class AudioSync: ObservableObject {
    @Published var isListening = false
    @Published var message: String?
    @Published var results: [AudioSyncResult] = []
    @Published var anchorId: String?
    @Published var undoDelays: [String: Double]?
    var player: AudioPlayer?
}

func makeAudioSyncWav(samples: [Float]) -> Data {
    var data = Data()
    func append(_ value: some FixedWidthInteger) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }
    let dataSize = UInt32(2 * samples.count)
    data.append(contentsOf: Array("RIFF".utf8))
    append(36 + dataSize)
    data.append(contentsOf: Array("WAVEfmt ".utf8))
    append(UInt32(16))
    append(UInt16(1))
    append(UInt16(1))
    append(UInt32(audioMixerSampleRate))
    append(UInt32(2 * audioMixerSampleRate))
    append(UInt16(2))
    append(UInt16(16))
    data.append(contentsOf: Array("data".utf8))
    append(dataSize)
    for sample in samples {
        append(Int16((sample.clamped(to: -1 ... 1) * 32767).rounded()))
    }
    return data
}

private func makeAudioSyncFailure(_ error: AudioMixerCaptureError) -> String {
    switch error {
    case .missing, .notReady:
        String(localized: "No audio.")
    case .discontinuity:
        String(localized: "The connection stuttered while measuring. Try again.")
    }
}

private func makeAudioSyncFailure(_ error: AudioSyncError) -> String {
    switch error {
    case .notHeard:
        String(localized: "Did not hear the sound.")
    case .ambiguous:
        String(localized: "Could not tell the sound apart from other audio. Try again.")
    case .moved:
        String(localized: "The distance changed while measuring. Hold still and try again.")
    }
}

extension Model {
    func startAudioSync() {
        guard !audioSync.isListening else {
            return
        }
        audioSync.message = nil
        audioSync.results = []
        audioSync.anchorId = nil
        let mics = ([mic.current] + mic.mixed).map { getMicById(id: $0.id) ?? $0 }
        let measurableMics = mics.filter { !$0.isScreenCapture() && !isMediaPlayerMic(mic: $0) }
        guard measurableMics.count >= 2 else {
            audioSync.message = String(localized: "Mix at least two mics to sync them.")
            return
        }
        let session = AVAudioSession.sharedInstance()
        if let output = session.currentRoute.outputs.first, output.portType != .builtInSpeaker {
            let name = output.portName
            audioSync.message = String(localized: "Sound plays on \(name), so other mics cannot hear it.")
            return
        }
        guard let player = try? AudioPlayer(data: makeAudioSyncWav(samples: makeAudioSyncSignal())) else {
            audioSync.message = String(localized: "Failed to play the sync sound.")
            return
        }
        if session.outputVolume < 0.5 {
            audioSync.message = String(localized: "Turn the volume up if the mics do not hear the sound.")
        }
        let names = Dictionary(mics.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        let ids = measurableMics.map(\.id)
        let start = makeAudioMixerIndex(currentPresentationTimeStamp()) - audioSyncPreRollFrames
        audioSync.player = player
        audioSync.isListening = true
        player.play()
        logger.info("""
        audio-sync: Playing on \(session.currentRoute.outputs.first?.portName ?? "-") at volume \
        \(session.outputVolume), window start \(start)
        """)
        audioSync.results = mics.filter { !ids.contains($0.id) }.map {
            AudioSyncResult(id: $0.id,
                            name: $0.name,
                            arrival: nil,
                            failure: String(localized: "Not measured: no microphone."))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + captureDelay) {
            self.captureAudioSync(ids: ids, names: names, start: start, isRetry: false)
        }
    }

    func audioSyncDelays() -> [String: Double] {
        guard let anchorId = audioSync.anchorId else {
            return [:]
        }
        let range = makeMicDelayRange(audioMixer: true)
        var arrivals: [String: Double] = [:]
        var delays: [String: Double] = [:]
        for result in audioSync.results {
            guard let arrival = result.arrival else {
                continue
            }
            arrivals[result.id] = arrival.frame
            delays[result.id] = (getMicById(id: result.id)?.delay ?? 0).clamped(to: range)
        }
        return makeAudioSyncDelays(arrivals: arrivals, delays: delays, anchor: anchorId)
    }

    func applyAudioSync() {
        let range = makeMicDelayRange(audioMixer: true)
        var undoDelays = audioSync.undoDelays ?? [:]
        for (id, delay) in audioSyncDelays() where id != audioSync.anchorId && range.contains(delay) {
            guard let mic = getMicById(id: id), mic.delay != delay else {
                continue
            }
            if undoDelays[id] == nil {
                undoDelays[id] = mic.delay
            }
            mic.delay = delay
            logger.info("audio-sync: \(mic.name) delay \(delay) s")
        }
        audioSync.undoDelays = undoDelays.isEmpty ? nil : undoDelays
        updateMicDelay()
    }

    func undoAudioSync() {
        for (id, delay) in audioSync.undoDelays ?? [:] {
            getMicById(id: id)?.delay = delay
        }
        audioSync.undoDelays = nil
        updateMicDelay()
    }

    private func captureAudioSync(ids: [String],
                                  names: [String: String],
                                  start: Int64,
                                  isRetry: Bool)
    {
        media.captureMixedAudio(ids: ids, start: start, count: audioSyncFrames) { captures in
            let isReady = !captures.values.contains {
                if case .failure(.notReady) = $0 {
                    return true
                }
                return false
            }
            guard isReady || isRetry else {
                DispatchQueue.main.asyncAfter(deadline: .now() + retryDelay) {
                    self.captureAudioSync(ids: ids, names: names, start: start, isRetry: true)
                }
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                let detector = AudioSyncDetector()
                var detections: [String: Result<AudioSyncArrival, AudioSyncError>] = [:]
                for (id, capture) in captures {
                    if case let .success(samples) = capture {
                        detections[id] = detector.detect(samples)
                    }
                }
                DispatchQueue.main.async {
                    self.finishAudioSync(ids: ids, names: names, captures: captures, detections: detections)
                }
            }
        }
    }

    private func finishAudioSync(ids: [String],
                                 names: [String: String],
                                 captures: AudioMixerCaptures,
                                 detections: [String: Result<AudioSyncArrival, AudioSyncError>])
    {
        audioSync.isListening = false
        audioSync.player = nil
        var results: [AudioSyncResult] = []
        for id in ids {
            let name = names[id] ?? ""
            var arrival: AudioSyncArrival?
            var failure: String?
            switch (captures[id] ?? .failure(.missing), detections[id]) {
            case let (.failure(error), _):
                failure = makeAudioSyncFailure(error)
            case let (_, .success(detection)?):
                arrival = detection
            case let (_, .failure(error)?):
                failure = makeAudioSyncFailure(error)
            case (_, nil):
                failure = makeAudioSyncFailure(.notHeard)
            }
            if let arrival {
                logger.info("""
                audio-sync: \(name) arrival \(arrival.frame) frames, \(arrival.numberOfChirps) chirps, \
                spread \(arrival.spread) frames, quality \(arrival.quality) dB
                """)
            } else {
                logger.info("audio-sync: \(name) \(failure ?? "")")
            }
            results.append(AudioSyncResult(id: id, name: name, arrival: arrival, failure: failure))
        }
        audioSync.results = results + audioSync.results
        let detected = results.filter { $0.arrival != nil }
        audioSync.anchorId = detected.max { ($0.arrival?.frame ?? 0) < ($1.arrival?.frame ?? 0) }?.id
        if detected.isEmpty {
            audioSync.message = String(localized: "No mic heard the sound. Turn the volume up and try again.")
        } else if detected.count == 1 {
            audioSync.message = String(localized: "Only \(detected[0].name) heard the sound.")
        }
    }
}
