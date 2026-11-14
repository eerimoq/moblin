import CoreHaptics

@MainActor
protocol HapticsDelegate: AnyObject {
    func hapticsActiveChanged()
}

@MainActor
class Haptics {
    weak var delegate: HapticsDelegate?
    private(set) var isActive = false
    private var engine: CHHapticEngine?
    private var player: (any CHHapticAdvancedPatternPlayer)?
    private var generation = 0
    private let stopTimer = MainTimer()

    func start(duration: Double?, intensity: Float, sharpness: Float) {
        stop()
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            return
        }
        generation += 1
        let generation = generation
        isActive = true
        delegate?.hapticsActiveChanged()
        do {
            let engine = try CHHapticEngine()
            engine.playsHapticsOnly = true
            engine.stoppedHandler = { _ in
                DispatchQueue.main.async {
                    self.stop(generation: generation)
                }
            }
            engine.resetHandler = {
                DispatchQueue.main.async {
                    self.stop(generation: generation)
                }
            }
            try engine.start()
            let event = CHHapticEvent(
                eventType: .hapticContinuous,
                parameters: [
                    CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity),
                    CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpness),
                ],
                relativeTime: 0,
                duration: 30
            )
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true
            try player.start(atTime: CHHapticTimeImmediate)
            self.engine = engine
            self.player = player
        } catch {
            logger.info("haptics: Failed to start with error: \(error)")
            stop()
            return
        }
        if let duration {
            stopTimer.startSingleShot(timeout: duration) {
                self.stop()
            }
        }
    }

    func stop() {
        stopTimer.stop()
        try? player?.stop(atTime: CHHapticTimeImmediate)
        player = nil
        engine?.stop()
        engine = nil
        if isActive {
            isActive = false
            delegate?.hapticsActiveChanged()
        }
    }

    private func stop(generation: Int) {
        guard generation == self.generation else {
            return
        }
        stop()
    }
}
