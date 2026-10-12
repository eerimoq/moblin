import AVFoundation
@testable import Moblin
import Testing

struct TextAlignerSuite {
    @Test(arguments: [
        ("xé👩‍💻ab", "e\u{301}👩‍💻abz", 1),
        ("é👩‍💻abz", "xe\u{301}👩‍💻ab", -1),
        ("ab", "ba", -1),
        ("abc", "xyz", 0),
        ("a", "b", 0),
        (String(repeating: "x", count: 25) + "a", "a", 25),
        ("a", String(repeating: "x", count: 25) + "a", -25),
        (String(repeating: "x", count: 26) + "a", "a", 0),
        ("a", String(repeating: "x", count: 26) + "a", 0),
    ])
    func characterShifts(oldText: String, newText: String, expectedPosition: Int) {
        let textAligner = TextAligner(text: oldText)
        textAligner.update(text: newText)
        #expect(textAligner.position == expectedPosition)
    }

    @Test
    func basic() {
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
