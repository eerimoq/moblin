import Foundation

struct RtmpReconnectPolicy {
    let baseDelay: Double
    let maxDelay: Double
    let jitterFactor: Double

    init(baseDelay: Double = 1.0, maxDelay: Double = 32.0, jitterFactor: Double = 0.15) {
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.jitterFactor = jitterFactor
    }

    func delay(forAttempt attempt: Int) -> Double {
        let exponentialDelay = baseDelay * pow(2.0, Double(attempt))
        let cappedDelay = min(exponentialDelay, maxDelay)

        let jitterAmount = cappedDelay * jitterFactor
        let randomJitter = Double.random(in: -jitterAmount ... jitterAmount)

        return cappedDelay + randomJitter
    }

    func shouldRetry(forError error: String?) -> Bool {
        // Return false for fatal errors like auth failed, no such user, bad stream key
        guard let error else { return true }

        let fatalKeywords = [
            "authmod=adobe",
            "?reason=authfailed",
            "nosuchuser",
            "badstreamkey",
            "code=403",
            "forbidden",
        ]

        let lowerError = error.lowercased()
        for keyword in fatalKeywords where lowerError.contains(keyword) {
            return false
        }
        return true
    }
}
