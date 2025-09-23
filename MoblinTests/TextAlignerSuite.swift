import AVFoundation
@testable import Moblin
import Testing

struct TextAlignerSuite {
    @Test func basic() async throws {
        let textAligner = TextAligner(text: "Cats have more fun than dogs")
        #expect(textAligner.position == 0)
        textAligner.update(text: "Cats have more fun than dogs")
        #expect(textAligner.position == 0)
        // textAligner.update(text: "have more fun than dogs when")
        // #expect(textAligner.position == 5)
    }
}
