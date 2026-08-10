import Foundation
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

    @Test
    func isLoopback() throws {
        #expect(try #require(URL(string: "ws://localhost:2345")?.isLoopback()))
        #expect(try #require(URL(string: "ws://127.0.0.1:2345/foo")?.isLoopback()))
        #expect(try #require(URL(string: "wss://[::1]/foo")?.isLoopback()))
        #expect(try !#require(URL(string: "ws://127.0.0.2:2345")?.isLoopback()))
        #expect(try !#require(URL(string: "ws://192.168.1.5:2345")?.isLoopback()))
        #expect(try !#require(URL(string: "wss://example.com/foo")?.isLoopback()))
        #expect(try !#require(URL(string: "wss://[fe80::1]/foo")?.isLoopback()))
        #expect(try !#require(URL(string: "ws:///foo")?.isLoopback()))
    }
}
