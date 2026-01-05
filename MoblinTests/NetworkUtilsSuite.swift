@testable import Moblin
import Testing

struct NetworkUtilsSuite {
    @Test
    func makeUrls() async throws {
        #expect(makeUrl("channels", [("foo", "bar")]) == "channels?foo=bar")
        #expect(makeUrl("/a/b/c", []) == "/a/b/c?")
        #expect(makeUrl("kalle", [("1", "2"), ("3", "4")]) == "kalle?1=2&3=4")
        #expect(makeUrl("foo/bar", [("^&*%", "#$%^")]) == "foo/bar?%5E%26*%25=%23$%25%5E")
    }
}
