@testable import Moblin
import Testing

struct NetworkUtilsSuite {
    @Test
    func makeUrls() {
        #expect(makeUrl("channels", [("foo", "bar")]) == "channels?foo=bar")
        #expect(makeUrl("/a/b/c", []) == "/a/b/c?")
        #expect(makeUrl("kalle", [("1", "2"), ("3", "4")]) == "kalle?1=2&3=4")
        #expect(makeUrl("foo/bar", [("^&*%", "#$%^")]) == "foo/bar?%5E%26*%25=%23$%25%5E")
    }

    @Test
    func makeMdnsHostnames() {
        #expect(makeMdnsHostname(deviceName: "iPhone") == "iphone.local")
        #expect(makeMdnsHostname(deviceName: "Erik 17 Pro") == "erik-17-pro.local")
        #expect(makeMdnsHostname(deviceName: "a's$b 6") == "asb-6.local")
        #expect(makeMdnsHostname(deviceName: "a    b----c--") == "a-b-c.local")
    }
}
