@testable import Moblin
import Testing

struct ModelControlBarSuite {
    struct FilterCase: CustomTestStringConvertible {
        let testDescription: String
        let name: String
        let filter: String

        init(_ name: String, _ filter: String) {
            testDescription = "\"\(name)\" with filter \"\(filter)\""
            self.name = name
            self.filter = filter
        }
    }

    @Test(arguments: [
        FilterCase("Mute", ""),
        FilterCase("", ""),
        FilterCase("Mute", "m"),
        FilterCase("Mute", "mute"),
        FilterCase("Mute", "MU"),
        FilterCase("MUTE", "mu"),
        FilterCase("Instant replay", "rep"),
        FilterCase("Instant replay", "inst"),
        FilterCase("Scene  widgets", "wid"),
        FilterCase("Scene\twidgets", "wid"),
        FilterCase("4:3", "4:"),
        FilterCase("Ölbrunn", "öl"),
        FilterCase("Torch", " "),
        FilterCase("Scene widgets", "scene w"),
        FilterCase("Scene widgets", "s w"),
        FilterCase("Scene widgets", "Scene Widgets"),
        FilterCase("Scene widgets", "s  w"),
        FilterCase("Scene widgets", "scene "),
        FilterCase("Scene widgets", " w"),
        FilterCase("Start instant replay", "i r"),
    ])
    func matches(filterCase: FilterCase) {
        #expect(quickButtonNameMatchesFilter(name: filterCase.name, filter: filterCase.filter))
    }

    @Test(arguments: [
        FilterCase("", "m"),
        FilterCase("Mute", "ute"),
        FilterCase("Mute", "muted"),
        FilterCase("Instant replay", "play"),
        FilterCase("Instant replay", "inst x"),
        FilterCase("Scene widgets", "w s"),
        FilterCase("Scene widgets", "s w x"),
        FilterCase("Scene widgets", "s idgets"),
        FilterCase("Start instant replay", "s r"),
    ])
    func doesNotMatch(filterCase: FilterCase) {
        #expect(!quickButtonNameMatchesFilter(name: filterCase.name, filter: filterCase.filter))
    }
}
