import AVFoundation
@testable import Moblin
import Testing

struct SubtitlesSuite {
    @Test func speechToTextOutput() async throws {
        let subtitles = Subtitles(languageIdentifier: nil)
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
            "no it just continues so the partial one can be re",
            "ally really long",
        ])
        position = 66
        frozen = """
        long string when will it go to be the frozen one maybe it will be the frozen one now no it just \
        continues so the partial one can be really really long
        """ + " "
        partial = "Have to wait"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "no it just continues so the partial one can be re",
            "ally really long Have to wait",

        ])
        position = 109
        frozen = """
        n one maybe it will be the frozen one now no it just continues so the partial one can be really \
        really long Have to wait a while and maybe it switches
        """ + " "
        partial = "Yes"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "ally really long Have to wait a while and maybe it",
            "switches Yes",
        ])
        partial = "Yes no maybe something is coming up"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "ally really long Have to wait a while and maybe it",
            "switches Yes no maybe something is coming up",
        ])
        partial = "Yes no maybe something is coming up or is it"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "switches Yes no maybe something is coming up or i",
            "s it",
        ])
        partial = "Yes no maybe something did come up or is it"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "switches Yes no maybe something did come up or is",
            "it",
        ])
        partial = "Yes no maybe something did come up or is"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "switches Yes no maybe something did come up or is",
        ])
        partial = "Yes no maybe something"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "switches Yes no maybe something",
        ])
        partial = "Yes no maybe something did come up or is this just another"
        subtitles.updateSubtitles(position: position, text: frozen + partial)
        #expect(subtitles.lines == [
            "switches Yes no maybe something did come up or is",
            "this just another",
        ])
    }
}
