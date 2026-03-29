import Foundation

// MARK: - Audio Level Monitor

struct MicLevelSample {
    let micId: String
    let levelDb: Float
    let timestamp: ContinuousClock.Instant
}

class AudioLevelMonitor {
    private var smoothedLevels: [String: Float] = [:]
    private let smoothingFactor: Float

    init(smoothingFactor: Float = 0.3) {
        self.smoothingFactor = smoothingFactor
    }

    func updateLevel(micId: String, rawLevelDb: Float) {
        let previous = smoothedLevels[micId] ?? rawLevelDb
        let smoothed = smoothingFactor * rawLevelDb + (1.0 - smoothingFactor) * previous
        smoothedLevels[micId] = smoothed
    }

    func getSmoothedLevel(micId: String) -> Float {
        return smoothedLevels[micId] ?? -160.0
    }

    func getAllLevels() -> [String: Float] {
        return smoothedLevels
    }

    func reset() {
        smoothedLevels.removeAll()
    }
}

// MARK: - Speech Prediction Buffer

struct AudioEnergySample {
    let levelDb: Float
    let timestamp: ContinuousClock.Instant
}

class SpeechPredictionBuffer {
    private var buffers: [String: [AudioEnergySample]] = [:]
    private let bufferDuration: Duration
    private let risingEnergyThresholdDb: Float = 6.0

    init(bufferLengthMs: Int) {
        bufferDuration = .milliseconds(bufferLengthMs)
    }

    func addSample(micId: String, levelDb: Float, now: ContinuousClock.Instant) {
        var buffer = buffers[micId] ?? []
        buffer.append(AudioEnergySample(levelDb: levelDb, timestamp: now))
        let cutoff = now - bufferDuration
        buffer.removeAll { $0.timestamp < cutoff }
        buffers[micId] = buffer
    }

    func detectRisingEnergy(micId: String) -> Bool {
        guard let buffer = buffers[micId], buffer.count >= 3 else {
            return false
        }
        let recentCount = min(buffer.count, 5)
        let recentSamples = Array(buffer.suffix(recentCount))
        let oldCount = min(buffer.count - recentCount, 5)
        guard oldCount > 0 else {
            return false
        }
        let oldSamples = Array(buffer.prefix(oldCount))
        let recentAvg = recentSamples.map(\.levelDb).reduce(0, +) / Float(recentSamples.count)
        let oldAvg = oldSamples.map(\.levelDb).reduce(0, +) / Float(oldSamples.count)
        return (recentAvg - oldAvg) > risingEnergyThresholdDb
    }

    func reset() {
        buffers.removeAll()
    }
}

// MARK: - Speaker Detection Engine

struct SpeakerScore {
    let speakerId: UUID
    let confidence: Float
    let isSpeaking: Bool
}

class SpeakerDetectionEngine {
    private let noiseFloorDb: Float
    private let hysteresisDb: Float
    private let sensitivity: Float
    private var currentSpeakerId: UUID?

    init(noiseFloorDb: Float, hysteresisDb: Float, sensitivity: Float) {
        self.noiseFloorDb = noiseFloorDb
        self.hysteresisDb = hysteresisDb
        self.sensitivity = sensitivity
    }

    func detectSpeaker(
        speakers: [SettingsAutoCameraSpeaker],
        audioLevels: [String: Float]
    ) -> SpeakerScore? {
        var speakerScores: [SpeakerScore] = []
        for speaker in speakers {
            let score = calculateSpeakerScore(speaker: speaker, audioLevels: audioLevels)
            speakerScores.append(score)
        }
        let activeSpeakers = speakerScores.filter(\.isSpeaking)
        guard !activeSpeakers.isEmpty else {
            currentSpeakerId = nil
            return nil
        }
        let sorted = activeSpeakers.sorted { $0.confidence > $1.confidence }
        guard let best = sorted.first else {
            return nil
        }
        if let currentId = currentSpeakerId, currentId != best.speakerId {
            if let currentScore = speakerScores.first(where: { $0.speakerId == currentId }),
               currentScore.isSpeaking
            {
                let margin = best.confidence - currentScore.confidence
                if margin < hysteresisDb {
                    return currentScore
                }
            }
        }
        currentSpeakerId = best.speakerId
        return best
    }

    private func calculateSpeakerScore(
        speaker: SettingsAutoCameraSpeaker,
        audioLevels: [String: Float]
    ) -> SpeakerScore {
        var maxLevel: Float = -160.0
        for micId in speaker.microphoneIds {
            if let level = audioLevels[micId] {
                let weightedLevel = level + 20.0 * log10(max(speaker.micWeight, 0.01))
                maxLevel = max(maxLevel, weightedLevel)
            }
        }
        let adjustedNoiseFloor = noiseFloorDb + (1.0 - sensitivity) * 10.0
        let isSpeaking = maxLevel > adjustedNoiseFloor
        let confidence = max(0, maxLevel - adjustedNoiseFloor)
        return SpeakerScore(
            speakerId: speaker.id,
            confidence: confidence,
            isSpeaking: isSpeaking
        )
    }

    func reset() {
        currentSpeakerId = nil
    }
}

// MARK: - Camera Switching Controller

class CameraSwitchingController {
    private var lastSwitchTime: ContinuousClock.Instant?
    private var currentSceneStartTime: ContinuousClock.Instant?
    private var currentSceneId: UUID?
    private var lastWideShotTime: ContinuousClock.Instant?
    private let minShotDuration: Duration
    private let switchCooldown: Duration

    init(minShotDurationMs: Int, switchCooldownMs: Int) {
        minShotDuration = .milliseconds(minShotDurationMs)
        switchCooldown = .milliseconds(switchCooldownMs)
    }

    func shouldSwitch(
        toSceneId: UUID,
        now: ContinuousClock.Instant
    ) -> Bool {
        if toSceneId == currentSceneId {
            return false
        }
        if let lastSwitch = lastSwitchTime {
            guard now - lastSwitch >= switchCooldown else {
                return false
            }
        }
        if let sceneStart = currentSceneStartTime {
            guard now - sceneStart >= minShotDuration else {
                return false
            }
        }
        return true
    }

    func didSwitch(toSceneId: UUID, now: ContinuousClock.Instant) {
        lastSwitchTime = now
        currentSceneStartTime = now
        currentSceneId = toSceneId
    }

    func shouldSwitchToWideShot(
        wideShotInterval: Int,
        maxSpeakerShotDuration: Int,
        now: ContinuousClock.Instant
    ) -> Bool {
        if let sceneStart = currentSceneStartTime {
            if now - sceneStart >= .seconds(maxSpeakerShotDuration) {
                return true
            }
        }
        if let lastWide = lastWideShotTime {
            if now - lastWide >= .seconds(wideShotInterval) {
                return true
            }
        } else if let sceneStart = currentSceneStartTime {
            if now - sceneStart >= .seconds(wideShotInterval) {
                return true
            }
        }
        return false
    }

    func didSwitchToWideShot(now: ContinuousClock.Instant) {
        lastWideShotTime = now
    }

    func getCurrentSceneId() -> UUID? {
        return currentSceneId
    }

    func reset() {
        lastSwitchTime = nil
        currentSceneStartTime = nil
        currentSceneId = nil
        lastWideShotTime = nil
    }
}

// MARK: - Auto Camera Director

class AutoCameraDirector {
    private(set) var audioMonitor: AudioLevelMonitor
    private(set) var predictionBuffer: SpeechPredictionBuffer
    private(set) var speakerDetection: SpeakerDetectionEngine
    private(set) var cameraController: CameraSwitchingController
    private var settings: SettingsAutoCameraSwitcher?

    init() {
        audioMonitor = AudioLevelMonitor()
        predictionBuffer = SpeechPredictionBuffer(bufferLengthMs: 200)
        speakerDetection = SpeakerDetectionEngine(
            noiseFloorDb: -50.0,
            hysteresisDb: 3.0,
            sensitivity: 0.5
        )
        cameraController = CameraSwitchingController(
            minShotDurationMs: 2000,
            switchCooldownMs: 1500
        )
    }

    func configure(settings: SettingsAutoCameraSwitcher) {
        self.settings = settings
        audioMonitor = AudioLevelMonitor(smoothingFactor: settings.smoothingFactor)
        predictionBuffer = SpeechPredictionBuffer(bufferLengthMs: settings.predictionBufferMs)
        speakerDetection = SpeakerDetectionEngine(
            noiseFloorDb: settings.noiseFloorDb,
            hysteresisDb: settings.hysteresisDb,
            sensitivity: settings.sensitivity
        )
        cameraController = CameraSwitchingController(
            minShotDurationMs: settings.minShotDurationMs,
            switchCooldownMs: settings.switchCooldownMs
        )
    }

    func update(
        micLevels: [String: Float],
        now: ContinuousClock.Instant
    ) -> UUID? {
        guard let settings else {
            return nil
        }
        for (micId, level) in micLevels {
            audioMonitor.updateLevel(micId: micId, rawLevelDb: level)
            predictionBuffer.addSample(micId: micId, levelDb: level, now: now)
        }
        let smoothedLevels = audioMonitor.getAllLevels()
        let speakerResult = speakerDetection.detectSpeaker(
            speakers: settings.speakers,
            audioLevels: smoothedLevels
        )
        if let wideShotSceneId = settings.wideShotSceneId {
            if speakerResult == nil {
                if cameraController.shouldSwitch(toSceneId: wideShotSceneId, now: now) {
                    cameraController.didSwitch(toSceneId: wideShotSceneId, now: now)
                    cameraController.didSwitchToWideShot(now: now)
                    return wideShotSceneId
                }
            }
            if cameraController.shouldSwitchToWideShot(
                wideShotInterval: settings.wideShotIntervalSeconds,
                maxSpeakerShotDuration: settings.maxSpeakerShotDurationSeconds,
                now: now
            ) {
                if cameraController.shouldSwitch(toSceneId: wideShotSceneId, now: now) {
                    cameraController.didSwitch(toSceneId: wideShotSceneId, now: now)
                    cameraController.didSwitchToWideShot(now: now)
                    return wideShotSceneId
                }
            }
        }
        if let speaker = speakerResult,
           let speakerConfig = settings.speakers.first(where: { $0.id == speaker.speakerId }),
           let sceneId = speakerConfig.sceneId
        {
            var shouldPredict = false
            for micId in speakerConfig.microphoneIds {
                if predictionBuffer.detectRisingEnergy(micId: micId) {
                    shouldPredict = true
                    break
                }
            }
            if shouldPredict || speaker.confidence > settings.hysteresisDb {
                if cameraController.shouldSwitch(toSceneId: sceneId, now: now) {
                    cameraController.didSwitch(toSceneId: sceneId, now: now)
                    return sceneId
                }
            }
        }
        return nil
    }

    func reset() {
        audioMonitor.reset()
        predictionBuffer.reset()
        speakerDetection.reset()
        cameraController.reset()
        settings = nil
    }
}
