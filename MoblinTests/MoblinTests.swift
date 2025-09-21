import AVFoundation
@testable import Moblin
import Testing

struct MoblinTests {
    @Test func wrappingTimestamp() async throws {
        let timestamp = WrappingTimestamp(name: "Test", maximumTimestamp: CMTime(seconds: 1024))
        #expect(timestamp.update(CMTime(seconds: 30)).seconds == 30)
        #expect(timestamp.update(CMTime(seconds: 1023)).seconds == -1)
        #expect(timestamp.update(CMTime(seconds: 500)).seconds == 500)
        #expect(timestamp.update(CMTime(seconds: 700)).seconds == 700)
        #expect(timestamp.update(CMTime(seconds: 1000)).seconds == 1000)
        #expect(timestamp.update(CMTime(seconds: 30)).seconds == 1054)
        #expect(timestamp.update(CMTime(seconds: 1000)).seconds == 1000)
        #expect(timestamp.update(CMTime(seconds: 500)).seconds == 1524)
        #expect(timestamp.update(CMTime(seconds: 1000)).seconds == 2024)
        #expect(timestamp.update(CMTime(seconds: 0)).seconds == 2048)
        #expect(timestamp.update(CMTime(seconds: 1022)).seconds == 2046)
        #expect(timestamp.update(CMTime(seconds: 1022)).seconds == 2046)
    }

    @Test func subtitlesLines() async throws {
        let subtitles = Subtitles()
        var position = 0
        var frozen = ""
        var partial = "Hello"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "Hello",
        ])
        frozen = "Hello What is up "
        partial = "Not much"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "Hello What is up Not much",
        ])
        frozen = "Hello What is up Not much at all "
        partial = """
        He said will it continue to be a long string when will it go to be the frozen one maybe it will \
        be the frozen one now no it just continues so the partial one can be really really long
        """
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "no it just continues so the partial one can be",
            "really really long",
        ])
        position = 66
        frozen = """
        long string when will it go to be the frozen one maybe it will be the frozen one now no it just \
        continues so the partial one can be really really long
        """ + " "
        partial = "Have to wait"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "no it just continues so the partial one can be",
            "really really long Have to wait",

        ])
        position = 109
        frozen = """
        n one maybe it will be the frozen one now no it just continues so the partial one can be really \
        really long Have to wait a while and maybe it switches
        """ + " "
        partial = "Yes"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "really really long Have to wait a while and maybe it",
            "switches Yes",
        ])
        partial = "Yes no maybe something is coming up"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "really really long Have to wait a while and maybe it",
            "switches Yes no maybe something is coming up",
        ])
        partial = "Yes no maybe something is coming up or is it"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "switches Yes no maybe something is coming up or",
            "is it"
        ])
    }
}
