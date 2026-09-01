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
        #expect(isValidUrl(url: "mobcam://localhost:7790") == nil)
        #expect(isValidUrl(url: "mobcam://127.0.0.1:7790") == nil)
        #expect(isValidUrl(url: "mobcam://LocalHost:7790") == nil)
        #expect(isValidUrl(url: "mobcam://localhost") != nil)
        #expect(isValidUrl(url: "mobcam://localhost:70000") != nil)
        #expect(isValidUrl(url: "mobcam://192.168.1.5:7790") != nil)
        #expect(isValidUrl(url: "mobcam://example.com:7790") != nil)
        #expect(isValidUrl(url: "mobcam://[::1]:7790") != nil)
        #expect(isValidUrl(url: "mobcam://localhost:7790", allowedSchemes: ["srt"]) != nil)
    }
}
