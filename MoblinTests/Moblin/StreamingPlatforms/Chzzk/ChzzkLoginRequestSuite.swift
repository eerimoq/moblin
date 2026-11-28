import Foundation
@testable import Moblin
import Testing

struct ChzzkLoginRequestSuite {
    @Test(arguments: [
        "http://localhost:8080/chzzk/callback?state=other&code=abc",
        "https://example.com/chzzk/callback?state=session&code=abc",
        "http://localhost:8080/other?state=session&code=abc",
        "http://localhost:8080/chzzk/callback?state=session&state=other&code=abc",
        "http://localhost:8080/chzzk/callback?state=session&code=abc&code=def",
        "http://localhost:8080/chzzk/callback?state=session&code=",
    ])
    func rejectUnexpectedCallback(url: String) throws {
        let request = try ChzzkLoginRequest(
            streamId: UUID(),
            state: "session",
            url: #require(URL(string: chzzkRedirectUri))
        )
        #expect(try request.code(from: #require(URL(string: url))) == nil)
    }

    @Test
    func readEncodedCode() throws {
        let request = try ChzzkLoginRequest(
            streamId: UUID(),
            state: "session",
            url: #require(URL(string: chzzkRedirectUri))
        )
        let callback = try #require(URL(string: "\(chzzkRedirectUri)?code=a%2Bb%3Dc&state=session"))
        #expect(request.code(from: callback) == "a+b=c")
    }
}
