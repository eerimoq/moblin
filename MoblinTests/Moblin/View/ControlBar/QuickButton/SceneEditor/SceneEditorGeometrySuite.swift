import CoreGraphics
import Foundation
@testable import Moblin
import Testing

private let canvasSize = CGSize(width: 1920, height: 1080)

private func makeLayout(_ alignment: SettingsAlignment) -> SettingsWidgetLayout {
    var layout = SettingsWidgetLayout()
    layout.alignment = alignment
    return layout
}

private func isEqual(_ actual: CGPoint, _ expected: CGPoint) -> Bool {
    areEqual([actual.x, actual.y], [expected.x, expected.y], epsilon: 0.001)
}

struct SceneEditorGeometrySuite {
    @Test(arguments: SettingsAlignment.allCases)
    func layoutPositionMatchesRect(alignment: SettingsAlignment) {
        let rects = [
            CGRect(x: 500, y: 300, width: 400, height: 300),
            CGRect(x: 0, y: 780, width: 400, height: 300),
            CGRect(x: 1520, y: 0, width: 400, height: 300),
        ]
        for rect in rects {
            let layout = sceneEditorLayout(makeLayout(alignment), rect, canvasSize, (false, false))
            #expect(isEqual(layoutPosition(layout, rect.size, canvasSize), rect.origin))
            #expect((0 ... 100).contains(layout.x))
            #expect((0 ... 100).contains(layout.y))
        }
    }

    @Test
    func moveFollowsSide() {
        let rect = CGRect(x: 1500, y: 780, width: 400, height: 300)
        let layout = sceneEditorLayout(makeLayout(.topLeft), rect, canvasSize, (false, false))
        #expect(layout.alignment == .bottomRight)
        #expect(isEqual(layoutPosition(layout, rect.size, canvasSize), rect.origin))
    }

    @Test
    func moveCentered() {
        let rect = CGRect(x: 760, y: 390, width: 400, height: 300)
        #expect(sceneEditorLayout(makeLayout(.topLeft), rect, canvasSize, (true, true)).alignment == .center)
        #expect(sceneEditorLayout(makeLayout(.center), rect, canvasSize, (true, false))
            .alignment == .bottomCenter)
    }

    @Test
    func moveWithPositioningLockKeepsCorner() {
        var layout = makeLayout(.topLeft)
        layout.positioningLock = true
        let rect = CGRect(x: 1500, y: 780, width: 400, height: 300)
        layout = sceneEditorLayout(layout, rect, canvasSize, (false, false))
        #expect(layout.alignment == .topLeft)
        #expect(layout.positioningLock)
        #expect(isEqual(layoutPosition(layout, rect.size, canvasSize), rect.origin))
    }

    @Test(arguments: SettingsAlignment.allCases)
    func resizeKeepsAlignedPoint(alignment: SettingsAlignment) {
        let rect = CGRect(x: 500, y: 300, width: 400, height: 300)
        let fixed = sceneEditorFixedPoint(rect, alignment)
        let resized = sceneEditorResizedRect(rect, fixed, 1.5)
        #expect(isEqual(sceneEditorFixedPoint(resized, alignment), fixed))
        #expect(resized.size == CGSize(width: 600, height: 450))
    }

    @Test
    func handleIsOppositeAlignedCorner() {
        let rect = CGRect(x: 500, y: 300, width: 400, height: 300)
        #expect(sceneEditorHandlePoint(rect, .topLeft) == CGPoint(x: 900, y: 600))
        #expect(sceneEditorHandlePoint(rect, .topRight) == CGPoint(x: 500, y: 600))
        #expect(sceneEditorHandlePoint(rect, .bottomLeft) == CGPoint(x: 900, y: 300))
        #expect(sceneEditorHandlePoint(rect, .bottomRight) == CGPoint(x: 500, y: 300))
        #expect(sceneEditorHandlePoint(rect, .center) == CGPoint(x: 900, y: 600))
    }

    @Test
    func snapAxisKeepsInside() {
        #expect(sceneEditorSnapAxis(-300, 400, 1920, 10, []).position == 0)
        #expect(sceneEditorSnapAxis(1800, 400, 1920, 10, []).position == 1520)
        #expect(sceneEditorSnapAxis(300, 2000, 1920, 10, []).position == 0)
    }

    @Test
    func resizeStopsAtCanvasEdges() {
        let rect = CGRect(x: 1400, y: 100, width: 400, height: 100)
        let fixed = sceneEditorFixedPoint(rect, .topRight)
        let factor = sceneEditorMaximumInsideFactor(rect, fixed, canvasSize)
        #expect(isEqual(factor, 1800 / 400, epsilon: 0.001))
        let resized = sceneEditorResizedRect(rect, fixed, factor)
        #expect(isEqual(resized.minX, 0, epsilon: 0.001))
        #expect(isEqual(resized.maxX, rect.maxX, epsilon: 0.001))
    }

    @Test
    func resizeCenteredStopsAtNearestEdge() {
        let rect = CGRect(x: 760, y: 100, width: 400, height: 300)
        let fixed = sceneEditorFixedPoint(rect, .topCenter)
        #expect(isEqual(sceneEditorMaximumInsideFactor(rect, fixed, canvasSize), 980 / 300, epsilon: 0.001))
    }

    @Test
    func snapAxisSnapsToEdgesAndCenter() {
        #expect(sceneEditorSnapAxis(-5, 400, 1920, 10, []).position == 0)
        #expect(sceneEditorSnapAxis(1525, 400, 1920, 10, []).position == 1520)
        let center = sceneEditorSnapAxis(765, 400, 1920, 10, [])
        #expect(center.position == 760)
        #expect(center.centered)
        let unsizedCenter = sceneEditorSnapAxis(955, 0, 1920, 10, [])
        #expect(unsizedCenter.position == 960)
        #expect(unsizedCenter.centered)
    }

    @Test
    func snapAxisSnapsToOtherWidgets() {
        let snap = sceneEditorSnapAxis(1003, 400, 1920, 10, [1000])
        #expect(snap.position == 1000)
        #expect(snap.guide == 1000)
    }

    @Test
    func tapSelectsTopWidget() {
        let small = UUID()
        let big = UUID()
        #expect(sceneEditorTapSelection([small, big], nil, false) == small)
        #expect(sceneEditorTapSelection([small, big], big, false) == small)
        #expect(sceneEditorTapSelection([], big, false) == nil)
    }

    @Test
    func tapOnSelectedInFrontDeselects() {
        let small = UUID()
        let big = UUID()
        #expect(sceneEditorTapSelection([small, big], small, false) == nil)
        #expect(sceneEditorTapSelection([big], big, false) == nil)
    }

    @Test
    func tapAtSameLocationCycles() {
        let small = UUID()
        let medium = UUID()
        let big = UUID()
        let hits = [small, medium, big]
        #expect(sceneEditorTapSelection(hits, small, true) == medium)
        #expect(sceneEditorTapSelection(hits, medium, true) == big)
        #expect(sceneEditorTapSelection(hits, big, true) == nil)
        #expect(sceneEditorTapSelection(hits, nil, true) == small)
    }
}
