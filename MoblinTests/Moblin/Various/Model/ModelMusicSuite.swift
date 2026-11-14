import Foundation
@testable import Moblin
import Testing

struct ModelMusicSuite {
    @Test
    func songUrl() throws {
        let url = try #require(URL(string: "https://music.apple.com/us/song/bicycle-race/6781079509"))
        #expect(appleMusicSongId(url: url) == "6781079509")
    }

    @Test
    func albumUrlWithSong() throws {
        let url = try #require(URL(string: "https://music.apple.com/us/album/jazz/6781079000?i=6781079509"))
        #expect(appleMusicSongId(url: url) == "6781079509")
    }

    @Test
    func albumUrlWithoutSong() throws {
        let url = try #require(URL(string: "https://music.apple.com/us/album/jazz/6781079000"))
        #expect(appleMusicSongId(url: url) == nil)
    }
}
