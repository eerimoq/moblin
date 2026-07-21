struct TimecodeNtpOffsetTracker {
    private(set) var offset: Double?
    private(set) var lastCorrectionDelta: Double?
    private(set) var correctionCount: Int = 0
    private let continuousCorrection: Bool
    private let minUpdateIntervalSeconds: Double
    private let emaAlpha: Double
    private let maxStepSeconds: Double
    private var lastUpdateHostTime: Double?

    init(continuousCorrection: Bool,
         minUpdateIntervalSeconds: Double = 5.0,
         emaAlpha: Double = 0.15,
         maxStepSeconds: Double = 0.05)
    {
        self.continuousCorrection = continuousCorrection
        self.minUpdateIntervalSeconds = max(0.0, minUpdateIntervalSeconds)
        self.emaAlpha = min(max(emaAlpha, 0.0), 1.0)
        self.maxStepSeconds = max(0.0, maxStepSeconds)
    }

    func needsSample(hostSeconds: Double) -> Bool {
        guard continuousCorrection else {
            return offset == nil
        }
        guard let lastUpdateHostTime else {
            return true
        }
        return hostSeconds - lastUpdateHostTime >= minUpdateIntervalSeconds
    }

    mutating func update(ntpSeconds: Double, hostSeconds: Double) -> (offset: Double, didWrite: Bool) {
        let measured = ntpSeconds - hostSeconds
        guard let current = offset else {
            offset = measured
            lastUpdateHostTime = hostSeconds
            lastCorrectionDelta = 0
            correctionCount += 1
            return (measured, true)
        }
        guard continuousCorrection else {
            return (current, false)
        }
        if let lastUpdateHostTime, hostSeconds - lastUpdateHostTime < minUpdateIntervalSeconds {
            return (current, false)
        }
        var next = current * (1.0 - emaAlpha) + measured * emaAlpha
        let delta = next - current
        if abs(delta) > maxStepSeconds {
            next = current + (delta > 0 ? maxStepSeconds : -maxStepSeconds)
        }
        lastCorrectionDelta = next - current
        offset = next
        lastUpdateHostTime = hostSeconds
        correctionCount += 1
        return (next, true)
    }

    mutating func reset() {
        offset = nil
        lastCorrectionDelta = nil
        correctionCount = 0
        lastUpdateHostTime = nil
    }
}
