import AVFoundation
@testable import Moblin
import Testing

struct RtmpReconnectPolicySuite {
    @Test
    func appliesExponentialBackoffWithJitter() {
        let policy = RtmpReconnectPolicy()

        let delay1 = policy.delay(forAttempt: 0)
        let delay3 = policy.delay(forAttempt: 3)
        let delay5 = policy.delay(forAttempt: 5)

        #expect(delay3 > delay1)
        #expect(delay5 > delay3)
        // O delay para a tentativa 5 (baseando-se no cap de 32.0 + jitter max)
        // 1 * 2^5 = 32.0. Com jitter de 15% (32 * 0.15 = 4.8), o maximo é 36.8
        #expect(delay5 <= 36.8)
    }

    @Test
    func rejectsFatalAuthErrors() {
        let policy = RtmpReconnectPolicy()

        #expect(policy.shouldRetry(forError: "badstreamkey") == false)
        #expect(policy.shouldRetry(forError: "authmod=adobe") == false)
        #expect(policy.shouldRetry(forError: "code=403") == false)
        #expect(policy.shouldRetry(forError: "temporary network error") == true)
    }
}
