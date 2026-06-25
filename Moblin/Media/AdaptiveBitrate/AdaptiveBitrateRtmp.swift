import Foundation

class AdaptiveBitrateRtmp: AdaptiveBitrate {
    private var currentBitrate: Int64
    private let minBitrate: Int64
    private var maxBitrate: Int64

    private var lastDropTime: ContinuousClock.Instant = .now
    private var lastIncreaseTime: ContinuousClock.Instant = .now
    private var lastKeyframeTime: ContinuousClock.Instant = .now

    // Configuração conservadora-média (ajustável)
    private let aggressiveDropThreshold = 0.82 // sendBufferUtilization
    private let rttWarningThresholdMs = 350.0
    private let recoveryCooldown: Duration = .seconds(2.5) // segundos após drop
    private let keyframeProtectionWindow: Duration = .milliseconds(800) // janela de proteção

    init(targetBitrate: UInt32, delegate: any AdaptiveBitrateDelegate) {
        maxBitrate = Int64(targetBitrate)
        currentBitrate = Int64(targetBitrate)
        minBitrate = 800_000 // default min
        super.init(delegate: delegate)
    }

    override func setTargetBitrate(bitrate: UInt32) {
        maxBitrate = Int64(bitrate)
    }

    override func getCurrentBitrate() -> UInt32 {
        UInt32(currentBitrate)
    }

    override func getCurrentMaximumBitrateInKbps() -> Int64 {
        maxBitrate / 1000
    }

    func notifyKeyframeSent() {
        lastKeyframeTime = .now
    }

    override func update(stats: StreamStats) {
        super.update(stats: stats)

        let now: ContinuousClock.Instant = .now
        let utilization = stats.sendBufferUtilization ?? 0.0
        let rtt = stats.rttMs
        let timeSinceLastKeyframe = lastKeyframeTime.duration(to: now)
        let isInKeyframeWindow = timeSinceLastKeyframe < keyframeProtectionWindow

        // === DROP AGRESSIVO (Congestionamento) ===
        if utilization > aggressiveDropThreshold || rtt > rttWarningThresholdMs, !isInKeyframeWindow {
            let reductionFactor = utilization > 0.92 ? 0.55 : 0.68
            let newBitrate = Int64(Double(currentBitrate) * reductionFactor)

            if newBitrate < currentBitrate && lastDropTime.duration(to: now) > .seconds(1.0) {
                currentBitrate = max(minBitrate, newBitrate)
                lastDropTime = now
                delegate?.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(currentBitrate))
                let action = "Decrease (utilization: \(String(format: "%.2f", utilization))) [protected keyframe]"
                logAdaptiveAcion(actionTaken: action)
                return
            }
        }

        // === RECUPERAÇÃO LENTA ===
        let isLowPressure = utilization < 0.45 && rtt < 180.0
        let isCooldownOver = lastDropTime.duration(to: now) > recoveryCooldown
        let isIncreaseCooldownOver = lastIncreaseTime.duration(to: now) > .seconds(2.0)

        if isLowPressure, isCooldownOver, isIncreaseCooldownOver {
            let increase = Int64(Double(currentBitrate) * 0.09) // +9% por passo
            let newBitrate = min(maxBitrate, currentBitrate + increase)

            if newBitrate > currentBitrate {
                currentBitrate = newBitrate
                lastIncreaseTime = now
                delegate?.adaptiveBitrateSetVideoStreamBitrate(bitrate: UInt32(currentBitrate))
                let action = "Increase (utilization: \(String(format: "%.2f", utilization)))"
                logAdaptiveAcion(actionTaken: action)
            }
        }
    }

    func reset() {
        lastDropTime = .now
        lastIncreaseTime = .now
    }
}
