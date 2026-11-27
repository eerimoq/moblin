import Foundation
@testable import Moblin
import Testing

struct SettingsSceneWidgetSuite {
    private func decode(_ json: String) throws -> SettingsSceneWidget {
        try JSONDecoder().decode(SettingsSceneWidget.self, from: Data(json.utf8))
    }

    @Test
    func oldCenteredWidgetGetsZeroCenterOffset() throws {
        let sceneWidget = try decode(#"{"x": 10, "y": 20, "alignment": "Center"}"#)
        #expect(sceneWidget.layout.x == 0)
        #expect(sceneWidget.layout.y == 0)
    }

    @Test
    func oldHorizontallyCenteredWidgetKeepsVerticalOffset() throws {
        let sceneWidget = try decode(#"{"x": 10, "y": 20, "alignment": "TopCenter"}"#)
        #expect(sceneWidget.layout.x == 0)
        #expect(sceneWidget.layout.y == 20)
    }

    @Test
    func oldCornerWidgetKeepsOffsets() throws {
        let sceneWidget = try decode(#"{"x": 10, "y": 20, "alignment": "BottomRight"}"#)
        #expect(sceneWidget.layout.x == 10)
        #expect(sceneWidget.layout.y == 20)
    }

    @Test
    func centerOffsetSurvivesRoundTrip() throws {
        let sceneWidget = SettingsSceneWidget(widgetId: .init())
        sceneWidget.layout.x = 10
        sceneWidget.layout.y = 20
        sceneWidget.layout.alignment = .center
        let decoded = try JSONDecoder().decode(SettingsSceneWidget.self,
                                               from: JSONEncoder().encode(sceneWidget))
        #expect(decoded.layout.x == 10)
        #expect(decoded.layout.y == 20)
    }

    @Test
    func oldCenteredReplayGetsZeroCenterOffset() throws {
        let json = #"{"x": 10, "y": 20, "alignment": "Center"}"#
        let replay = try JSONDecoder().decode(SettingsStreamReplay.self, from: Data(json.utf8))
        #expect(replay.layout.x == 0)
        #expect(replay.layout.y == 0)
    }
}
