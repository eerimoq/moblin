@testable import Moblin
import Testing

struct RistSuite {
    @Test
    func makeBondingUrl() async throws {
        #expect(makeRistBondingUrl("rist://foobar?secret=1234") == "rist://foobar?secret=1234&weight=1")
    }

    @Test
    func makeMoblinkBondingUrl() async throws {
        #expect(makeRistMoblinkBondingUrl(
            "rist://foobar?secret=1234",
            .hostPort(host: .init("1.2.3.4"), port: .imap)
        ) == "rist://1.2.3.4:143?secret=1234&weight=1")
    }
}
