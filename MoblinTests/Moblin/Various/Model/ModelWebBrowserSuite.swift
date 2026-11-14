import Foundation
@testable import Moblin
import Testing

struct ModelWebBrowserSuite {
    struct SearchCase: CustomTestStringConvertible {
        let testDescription: String
        let text: String
        let url: String

        init(_ text: String, _ query: String) {
            testDescription = text
            self.text = text
            url = "https://www.google.com/search?q=\(query)"
        }
    }

    @Test(arguments: [
        SearchCase("moblin", "moblin"),
        SearchCase("moblin app", "moblin%20app"),
        SearchCase("c++", "c%2B%2B"),
        SearchCase("a & b", "a%20%26%20b"),
        SearchCase("what is #1", "what%20is%20%231"),
        SearchCase("x=1", "x%3D1"),
    ])
    func search(searchCase: SearchCase) {
        #expect(makeWebBrowserUrl(text: searchCase.text)?.absoluteString == searchCase.url)
    }

    @Test
    func urlWithScheme() {
        #expect(makeWebBrowserUrl(text: "http://example.com/a?b=c")?
            .absoluteString == "http://example.com/a?b=c")
    }

    @Test
    func urlWithoutScheme() {
        #expect(makeWebBrowserUrl(text: "example.com/a")?.absoluteString == "https://example.com/a")
    }
}
