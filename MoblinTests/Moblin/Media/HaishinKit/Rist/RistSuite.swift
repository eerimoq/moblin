@testable import Moblin
import Testing

struct RistSuite {
    @Test
    func makeBondingUrl() {
        #expect(makeRistBondingUrl("rist://foobar?secret=1234") == "rist://foobar?secret=1234&weight=1")
    }

    @Test
    func makeBondingUrlWithPort() {
        #expect(makeRistBondingUrl("rist://a.com:54") == "rist://a.com:54?weight=1")
    }

    @Test
    func makeMoblinkBondingUrl() {
        #expect(makeRistMoblinkBondingUrl(
            "rist://foobar?secret=1234",
            .hostPort(host: .init("1.2.3.4"), port: .imap)
        ) == "rist://1.2.3.4:143?secret=1234&weight=1")
    }
}
