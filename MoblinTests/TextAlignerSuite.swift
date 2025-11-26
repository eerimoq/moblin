import AVFoundation
@testable import Moblin
import Testing

struct TextAlignerSuite {
    @Test
    func basic() async throws {
        let textAligner = TextAligner(text: "Cats have more fun than dogs")
        #expect(textAligner.position == 0)
        textAligner.update(text: "Cats have more fun than dogs")
        #expect(textAligner.position == 0)
        textAligner.update(text: "have more fun than dogs when")
        #expect(textAligner.position == 5)
        textAligner.update(text: "Cats have more fun than dogs")
        #expect(textAligner.position == 0)
        textAligner.update(text: "Cats are more fun than dogs")
        #expect(textAligner.position == 1)
        textAligner.update(text: "ore fun than dogs and have")
        #expect(textAligner.position == 11)
        textAligner.update(text: "ore fun than dogs but dogs are better listeners")
        #expect(textAligner.position == 11)
        textAligner.update(text: "ore fun but dogs are better listeners")
        #expect(textAligner.position == 21)
    }
}
