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
    func usbUrlValidation() {
        #expect(isValidUrl(url: "usb://localhost:7777") == nil)
        #expect(isValidUrl(url: "usb://localhost") != nil)
        #expect(isValidUrl(url: "usb://localhost:70000") != nil)
        #expect(isValidUrl(url: "usb://localhost:7777", allowedSchemes: ["srt"]) != nil)
    }
}
