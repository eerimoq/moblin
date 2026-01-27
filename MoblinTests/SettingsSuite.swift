@testable import Moblin
import Testing

struct SettingsSuite {
    @Test
    func chatFilter() {
        let filter = SettingsChatFilter()
        filter.user = ""
        filter.messageStartWords = ["!"]
        #expect(filter.isMatching(user: "erik", segments: [.init(id: 0, text: "!moblin")]))
        #expect(filter.isMatching(user: "erik", segments: [.init(id: 0, text: "!")]))
        #expect(!filter.isMatching(user: "erik", segments: [.init(id: 0, text: "@foo")]))
        #expect(!filter.isMatching(user: "erik", segments: [.init(id: 0, text: "@")]))
        filter.messageStartWords = ["hell", "h"]
        #expect(filter.isMatching(user: "erik",
                                  segments: [
                                      .init(id: 0, text: "hell"),
                                      .init(id: 0, text: "hi"),
                                      .init(id: 0, text: "ho"),
                                  ]))
        #expect(!filter.isMatching(user: "erik",
                                   segments: [
                                       .init(id: 0, text: "hello"),
                                       .init(id: 0, text: "hi"),
                                       .init(id: 0, text: "ho"),
                                   ]))
    }
}
