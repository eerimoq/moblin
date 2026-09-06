import Foundation
@testable import Moblin
import Testing

struct CheermotesSuite {
    private func makeCheermotes(_ prefixes: [String: [Int]]) -> Cheermotes {
        let cheermotes = Cheermotes()
        cheermotes.addCheermotes(datas: prefixes.map { prefix, minBits in
            TwitchApiGetCheermotesData(prefix: prefix, tiers: minBits.map { minBits in
                TwitchApiGetCheermotesDataTier(
                    min_bits: minBits,
                    images: TwitchApiGetCheermotesDataTiersImages(
                        dark: TwitchApiGetCheermotesDataTiersImagesTheme(
                            static_: TwitchApiGetCheermotesDataTiersImagesThemeKind(
                                two: "https://cheer.example.com/\(prefix)/\(minBits)"
                            )
                        )
                    )
                )
            })
        })
        return cheermotes
    }

    @Test
    func matchesPrefixAndBits() throws {
        let cheermotes = makeCheermotes(["cheer": [1]])
        let (url, bits) = try #require(cheermotes.getUrlAndBits(word: "cheer100"))
        #expect(url.absoluteString == "https://cheer.example.com/cheer/1")
        #expect(bits == 100)
    }

    @Test
    func ignoresSurroundingWhitespaceAndCase() throws {
        let cheermotes = makeCheermotes(["cheer": [1]])
        let (_, bits) = try #require(cheermotes.getUrlAndBits(word: " Cheer250 "))
        #expect(bits == 250)
    }

    @Test
    func picksHighestMatchingTier() throws {
        let cheermotes = makeCheermotes(["cheer": [1, 100, 1000, 5000]])
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer1")).0.lastPathComponent == "1")
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer500")).0.lastPathComponent == "100")
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer1000")).0.lastPathComponent == "1000")
        #expect(try #require(cheermotes.getUrlAndBits(word: "cheer99999")).0.lastPathComponent == "5000")
    }

    @Test
    func belowLowestTierDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [100]])
        #expect(cheermotes.getUrlAndBits(word: "cheer1") == nil)
    }

    @Test
    func prefixEndingInDigitPrefersTheLongestPrefix() throws {
        let cheermotes = makeCheermotes(["cheer": [1], "cheer1": [1]])
        let (url, bits) = try #require(cheermotes.getUrlAndBits(word: "cheer1100"))
        #expect(url.absoluteString == "https://cheer.example.com/cheer1/1")
        #expect(bits == 100)
    }

    @Test
    func withoutBitsDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "cheer") == nil)
    }

    @Test
    func unknownPrefixDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "notacheermote100") == nil)
    }

    @Test
    func partialWordDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "xcheer100") == nil)
        #expect(cheermotes.getUrlAndBits(word: "cheer100x") == nil)
    }

    @Test
    func emptyWordDoesNotMatch() {
        let cheermotes = makeCheermotes(["cheer": [1]])
        #expect(cheermotes.getUrlAndBits(word: "") == nil)
        #expect(cheermotes.getUrlAndBits(word: "100") == nil)
    }

    @Test
    func noCheermotesFetched() {
        #expect(Cheermotes().getUrlAndBits(word: "cheer100") == nil)
    }
}
