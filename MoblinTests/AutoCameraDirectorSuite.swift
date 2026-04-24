import Foundation
@testable import Moblin
import Testing

struct AutoCameraDirectorSuite {
    // MARK: - AudioLevelMonitor Tests

    @Test
    func audioLevelMonitorSmoothing() {
        let monitor = AudioLevelMonitor(smoothingFactor: 0.5)
        monitor.updateLevel(micId: "mic1", rawLevelDb: -40.0)
        #expect(monitor.getSmoothedLevel(micId: "mic1") == -40.0)
        monitor.updateLevel(micId: "mic1", rawLevelDb: -20.0)
        let smoothed = monitor.getSmoothedLevel(micId: "mic1")
        #expect(smoothed == -30.0)
    }

    @Test
    func audioLevelMonitorDefaultLevel() {
        let monitor = AudioLevelMonitor()
        #expect(monitor.getSmoothedLevel(micId: "nonexistent") == -160.0)
    }

    @Test
    func audioLevelMonitorMultipleMics() {
        let monitor = AudioLevelMonitor(smoothingFactor: 1.0)
        monitor.updateLevel(micId: "mic1", rawLevelDb: -30.0)
        monitor.updateLevel(micId: "mic2", rawLevelDb: -40.0)
        let levels = monitor.getAllLevels()
        #expect(levels["mic1"] == -30.0)
        #expect(levels["mic2"] == -40.0)
    }

    @Test
    func audioLevelMonitorReset() {
        let monitor = AudioLevelMonitor()
        monitor.updateLevel(micId: "mic1", rawLevelDb: -30.0)
        monitor.reset()
        #expect(monitor.getSmoothedLevel(micId: "mic1") == -160.0)
    }

    // MARK: - SpeechPredictionBuffer Tests

    @Test
    func predictionBufferNotEnoughSamples() {
        let buffer = SpeechPredictionBuffer(bufferLengthMs: 300)
        let now = ContinuousClock.now
        buffer.addSample(micId: "mic1", levelDb: -40.0, now: now)
        #expect(!buffer.detectRisingEnergy(micId: "mic1"))
    }

    @Test
    func predictionBufferRisingEnergy() {
        let buffer = SpeechPredictionBuffer(bufferLengthMs: 1000)
        let now = ContinuousClock.now
        for i in 0 ..< 5 {
            buffer.addSample(
                micId: "mic1",
                levelDb: -60.0,
                now: now + .milliseconds(i * 10)
            )
        }
        for i in 5 ..< 10 {
            buffer.addSample(
                micId: "mic1",
                levelDb: -30.0,
                now: now + .milliseconds(i * 10)
            )
        }
        #expect(buffer.detectRisingEnergy(micId: "mic1"))
    }

    @Test
    func predictionBufferStableEnergy() {
        let buffer = SpeechPredictionBuffer(bufferLengthMs: 1000)
        let now = ContinuousClock.now
        for i in 0 ..< 10 {
            buffer.addSample(
                micId: "mic1",
                levelDb: -30.0,
                now: now + .milliseconds(i * 10)
            )
        }
        #expect(!buffer.detectRisingEnergy(micId: "mic1"))
    }

    @Test
    func predictionBufferReset() {
        let buffer = SpeechPredictionBuffer(bufferLengthMs: 300)
        let now = ContinuousClock.now
        buffer.addSample(micId: "mic1", levelDb: -30.0, now: now)
        buffer.reset()
        #expect(!buffer.detectRisingEnergy(micId: "mic1"))
    }

    // MARK: - SpeakerDetectionEngine Tests

    @Test
    func speakerDetectionNoSpeaking() {
        let engine = SpeakerDetectionEngine(
            noiseFloorDb: -50.0,
            hysteresisDb: 3.0,
            sensitivity: 0.5
        )
        let speaker = SettingsAutoCameraSpeaker()
        speaker.microphoneIds = ["mic1"]
        let result = engine.detectSpeaker(
            speakers: [speaker],
            audioLevels: ["mic1": -70.0]
        )
        #expect(result == nil)
    }

    @Test
    func speakerDetectionOneSpeaking() {
        let engine = SpeakerDetectionEngine(
            noiseFloorDb: -50.0,
            hysteresisDb: 3.0,
            sensitivity: 0.5
        )
        let speaker = SettingsAutoCameraSpeaker()
        speaker.microphoneIds = ["mic1"]
        let result = engine.detectSpeaker(
            speakers: [speaker],
            audioLevels: ["mic1": -20.0]
        )
        #expect(result != nil)
        #expect(result?.speakerId == speaker.id)
        #expect(result?.isSpeaking == true)
    }

    @Test
    func speakerDetectionLoudestWins() {
        let engine = SpeakerDetectionEngine(
            noiseFloorDb: -50.0,
            hysteresisDb: 3.0,
            sensitivity: 0.5
        )
        let speakerA = SettingsAutoCameraSpeaker()
        speakerA.microphoneIds = ["mic1"]
        let speakerB = SettingsAutoCameraSpeaker()
        speakerB.microphoneIds = ["mic2"]
        let result = engine.detectSpeaker(
            speakers: [speakerA, speakerB],
            audioLevels: ["mic1": -30.0, "mic2": -20.0]
        )
        #expect(result != nil)
        #expect(result?.speakerId == speakerB.id)
    }

    @Test
    func speakerDetectionHysteresis() {
        let engine = SpeakerDetectionEngine(
            noiseFloorDb: -50.0,
            hysteresisDb: 3.0,
            sensitivity: 0.5
        )
        let speakerA = SettingsAutoCameraSpeaker()
        speakerA.microphoneIds = ["mic1"]
        let speakerB = SettingsAutoCameraSpeaker()
        speakerB.microphoneIds = ["mic2"]
        let speakers = [speakerA, speakerB]
        let result1 = engine.detectSpeaker(
            speakers: speakers,
            audioLevels: ["mic1": -20.0, "mic2": -40.0]
        )
        #expect(result1?.speakerId == speakerA.id)
        let result2 = engine.detectSpeaker(
            speakers: speakers,
            audioLevels: ["mic1": -20.0, "mic2": -21.0]
        )
        #expect(result2?.speakerId == speakerA.id)
    }

    // MARK: - CameraSwitchingController Tests

    @Test
    func cameraSwitchingBasic() {
        let controller = CameraSwitchingController(
            minShotDurationMs: 1000,
            switchCooldownMs: 500
        )
        let now = ContinuousClock.now
        let sceneId = UUID()
        #expect(controller.shouldSwitch(toSceneId: sceneId, now: now))
    }

    @Test
    func cameraSwitchingSameScene() {
        let controller = CameraSwitchingController(
            minShotDurationMs: 1000,
            switchCooldownMs: 500
        )
        let now = ContinuousClock.now
        let sceneId = UUID()
        controller.didSwitch(toSceneId: sceneId, now: now)
        #expect(!controller.shouldSwitch(toSceneId: sceneId, now: now + .seconds(10)))
    }

    @Test
    func cameraSwitchingCooldown() {
        let controller = CameraSwitchingController(
            minShotDurationMs: 100,
            switchCooldownMs: 2000
        )
        let now = ContinuousClock.now
        let scene1 = UUID()
        let scene2 = UUID()
        controller.didSwitch(toSceneId: scene1, now: now)
        #expect(!controller.shouldSwitch(toSceneId: scene2, now: now + .milliseconds(500)))
        #expect(controller.shouldSwitch(toSceneId: scene2, now: now + .milliseconds(2100)))
    }

    @Test
    func cameraSwitchingMinShotDuration() {
        let controller = CameraSwitchingController(
            minShotDurationMs: 3000,
            switchCooldownMs: 100
        )
        let now = ContinuousClock.now
        let scene1 = UUID()
        let scene2 = UUID()
        controller.didSwitch(toSceneId: scene1, now: now)
        #expect(!controller.shouldSwitch(toSceneId: scene2, now: now + .milliseconds(1000)))
        #expect(controller.shouldSwitch(toSceneId: scene2, now: now + .milliseconds(3100)))
    }

    @Test
    func cameraSwitchingWideShotTimeout() {
        let controller = CameraSwitchingController(
            minShotDurationMs: 100,
            switchCooldownMs: 100
        )
        let now = ContinuousClock.now
        let scene1 = UUID()
        controller.didSwitch(toSceneId: scene1, now: now)
        #expect(
            controller.shouldSwitchToWideShot(
                wideShotInterval: 30,
                maxSpeakerShotDuration: 10,
                now: now + .seconds(11)
            )
        )
    }

    @Test
    func cameraSwitchingReset() {
        let controller = CameraSwitchingController(
            minShotDurationMs: 3000,
            switchCooldownMs: 3000
        )
        let now = ContinuousClock.now
        let scene1 = UUID()
        controller.didSwitch(toSceneId: scene1, now: now)
        controller.reset()
        #expect(controller.getCurrentSceneId() == nil)
        let scene2 = UUID()
        #expect(controller.shouldSwitch(toSceneId: scene2, now: now))
    }

    // MARK: - AutoCameraDirector Integration Tests

    @Test
    func directorNoSettingsReturnsNil() {
        let director = AutoCameraDirector()
        let result = director.update(
            micLevels: ["mic1": -20.0],
            now: .now
        )
        #expect(result == nil)
    }

    @Test
    func directorSwitchesToLoudestSpeaker() {
        let director = AutoCameraDirector()
        let settings = SettingsAutoCameraSwitcher()
        settings.switchCooldownMs = 0
        settings.minShotDurationMs = 0
        settings.noiseFloorDb = -50.0
        settings.hysteresisDb = 3.0
        settings.sensitivity = 0.5
        settings.smoothingFactor = 1.0
        let sceneA = UUID()
        let sceneB = UUID()
        let speakerA = SettingsAutoCameraSpeaker()
        speakerA.name = "Speaker A"
        speakerA.sceneId = sceneA
        speakerA.microphoneIds = ["mic1"]
        let speakerB = SettingsAutoCameraSpeaker()
        speakerB.name = "Speaker B"
        speakerB.sceneId = sceneB
        speakerB.microphoneIds = ["mic2"]
        settings.speakers = [speakerA, speakerB]
        director.configure(settings: settings)
        let result = director.update(
            micLevels: ["mic1": -60.0, "mic2": -15.0],
            now: .now
        )
        #expect(result == sceneB)
    }

    @Test
    func directorRespectsNoiseFloor() {
        let director = AutoCameraDirector()
        let settings = SettingsAutoCameraSwitcher()
        settings.noiseFloorDb = -30.0
        settings.sensitivity = 0.5
        settings.smoothingFactor = 1.0
        let speaker = SettingsAutoCameraSpeaker()
        speaker.sceneId = UUID()
        speaker.microphoneIds = ["mic1"]
        settings.speakers = [speaker]
        director.configure(settings: settings)
        let result = director.update(
            micLevels: ["mic1": -40.0],
            now: .now
        )
        #expect(result == nil)
    }

    // MARK: - Settings Codable Tests

    @Test
    func settingsAutoCameraSpeakerCodable() throws {
        let speaker = SettingsAutoCameraSpeaker()
        speaker.name = "Test Speaker"
        speaker.sceneId = UUID()
        speaker.microphoneIds = ["mic1", "mic2"]
        speaker.micWeight = 1.5
        let data = try JSONEncoder().encode(speaker)
        let decoded = try JSONDecoder().decode(SettingsAutoCameraSpeaker.self, from: data)
        #expect(decoded.name == speaker.name)
        #expect(decoded.sceneId == speaker.sceneId)
        #expect(decoded.microphoneIds == speaker.microphoneIds)
        #expect(decoded.micWeight == speaker.micWeight)
    }

    @Test
    func settingsAutoCameraSwitcherCodable() throws {
        let switcher = SettingsAutoCameraSwitcher()
        switcher.name = "Test Switcher"
        switcher.enabled = true
        switcher.sensitivity = 0.7
        switcher.switchCooldownMs = 2000
        switcher.noiseFloorDb = -45.0
        switcher.activityLevel = .high
        let data = try JSONEncoder().encode(switcher)
        let decoded = try JSONDecoder().decode(SettingsAutoCameraSwitcher.self, from: data)
        #expect(decoded.name == switcher.name)
        #expect(decoded.enabled == switcher.enabled)
        #expect(decoded.sensitivity == switcher.sensitivity)
        #expect(decoded.switchCooldownMs == switcher.switchCooldownMs)
        #expect(decoded.noiseFloorDb == switcher.noiseFloorDb)
        #expect(decoded.activityLevel == .high)
    }

    @Test
    func settingsAutoCameraSwitchersCodable() throws {
        let switchers = SettingsAutoCameraSwitchers()
        let switcher = SettingsAutoCameraSwitcher()
        switcher.name = "Podcast Setup"
        switchers.switchers.append(switcher)
        switchers.switcherId = switcher.id
        let data = try JSONEncoder().encode(switchers)
        let decoded = try JSONDecoder().decode(SettingsAutoCameraSwitchers.self, from: data)
        #expect(decoded.switcherId == switcher.id)
        #expect(decoded.switchers.count == 1)
        #expect(decoded.switchers.first?.name == "Podcast Setup")
    }

    @Test
    func settingsAutoCameraSpeakerDefaults() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SettingsAutoCameraSpeaker.self, from: data)
        #expect(decoded.name == SettingsAutoCameraSpeaker.baseName)
        #expect(decoded.sceneId == nil)
        #expect(decoded.microphoneIds.isEmpty)
        #expect(decoded.micWeight == 1.0)
    }

    @Test
    func settingsAutoCameraSwitcherDefaults() throws {
        let json = "{}"
        let data = json.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(SettingsAutoCameraSwitcher.self, from: data)
        #expect(decoded.enabled == false)
        #expect(decoded.sensitivity == 0.5)
        #expect(decoded.switchCooldownMs == 1500)
        #expect(decoded.noiseFloorDb == -50.0)
        #expect(decoded.predictionBufferMs == 200)
        #expect(decoded.minShotDurationMs == 2000)
        #expect(decoded.activityLevel == .medium)
    }
}
