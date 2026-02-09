import Foundation
@testable import Moblin
import Testing

struct ValidateSuite {
    @Test
    func whipUrlValidation() {
        #expect(isValidUrl(url: "whips://whip.example.com/live/123") == nil)
        #expect(isValidUrl(url: "whip://whip.example.com/live/123") == nil)
    }
}
