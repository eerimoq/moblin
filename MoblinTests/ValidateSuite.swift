import Foundation
@testable import Moblin
import Testing

struct ValidateSuite {
    @Test
    func whipUrlValidation() {
        #expect(isValidUrl(url: "whips://whip.example.com/live/123") == nil)
        #expect(isValidUrl(url: "whip://whip.example.com/live/123") == nil)
    }

    @Test
    func mobcamUrlValidation() {
        #expect(isValidUrl(url: "mobcam://localhost:7777") == nil)
        #expect(isValidUrl(url: "mobcam://localhost") != nil)
        #expect(isValidUrl(url: "mobcam://localhost:70000") != nil)
        #expect(isValidUrl(url: "mobcam://localhost:7777", allowedSchemes: ["srt"]) != nil)
    }
}
