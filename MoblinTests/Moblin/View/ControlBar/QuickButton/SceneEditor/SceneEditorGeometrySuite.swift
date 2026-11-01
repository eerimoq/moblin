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
    @Test(arguments: [SettingsAlignment.topLeft, .topRight, .bottomLeft, .bottomRight])
    func layoutPositionMatchesRect(alignment: SettingsAlignment) {
        let rects = [
            CGRect(x: 500, y: 300, width: 400, height: 300),
            CGRect(x: 0, y: 780, width: 400, height: 300),
            CGRect(x: 1520, y: 0, width: 400, height: 300),
        ]
        for rect in rects {
            let layout = sceneEditorLayout(makeLayout(alignment), rect, canvasSize)
            #expect(layout.alignment == alignment)
            #expect(isEqual(layoutPosition(layout, rect.size, canvasSize), rect.origin))
            #expect((0 ... 100).contains(layout.x))
            #expect((0 ... 100).contains(layout.y))
        }
    }

    @Test
    func moveKeepsAlignment() {
        let rect = CGRect(x: 1500, y: 780, width: 400, height: 300)
        let layout = sceneEditorLayout(makeLayout(.topLeft), rect, canvasSize)
        #expect(layout.alignment == .topLeft)
        #expect(isEqual(layoutPosition(layout, rect.size, canvasSize), rect.origin))
    }

    @Test
    func moveKeepsCenteredAxis() {
        var layout = makeLayout(.topCenter)
        layout.x = 7
        layout = sceneEditorLayout(layout, CGRect(x: 100, y: 200, width: 400, height: 300), canvasSize)
        #expect(layout.alignment == .topCenter)
        #expect(layout.x == 7)
        #expect(isEqual(layoutPosition(layout, CGSize(width: 400, height: 300), canvasSize),
                        CGPoint(x: 760, y: 200)))
    }

    @Test(arguments: SettingsAlignment.allCases)
    func alignCenteredWidgetKeepsPosition(alignment: SettingsAlignment) {
        let rect = CGRect(x: 760, y: 390, width: 400, height: 300)
        let layout = sceneEditorLayout(makeLayout(.topLeft), rect, canvasSize)
        let aligned = sceneEditorAlignedLayout(layout, alignment, rect.size, canvasSize)
        #expect(aligned.alignment == alignment)
        #expect(aligned.size == layout.size)
        #expect(isEqual(layoutPosition(aligned, rect.size, canvasSize), rect.origin))
    }

    @Test(arguments: [SettingsAlignment.topLeft, .topRight, .bottomLeft, .bottomRight])
    func alignCornerWidgetKeepsPosition(alignment: SettingsAlignment) {
        for size in [CGSize(width: 400, height: 300), .zero] {
            let rect = CGRect(origin: CGPoint(x: 100, y: 150), size: size)
            let layout = sceneEditorLayout(makeLayout(.bottomRight), rect, canvasSize)
            let aligned = sceneEditorAlignedLayout(layout, alignment, size, canvasSize)
            #expect(isEqual(layoutPosition(aligned, size, canvasSize), rect.origin))
        }
    }

    @Test
    func alignCenteredClearsPositioningLock() {
        var layout = makeLayout(.topLeft)
        layout.positioningLock = true
        #expect(!sceneEditorAlignedLayout(layout, .leftCenter, .zero, canvasSize).positioningLock)
        #expect(sceneEditorAlignedLayout(layout, .bottomRight, .zero, canvasSize).positioningLock)
    }

    @Test
    func moveWithPositioningLockKeepsCorner() {
        var layout = makeLayout(.topLeft)
        layout.positioningLock = true
        let rect = CGRect(x: 1500, y: 780, width: 400, height: 300)
        layout = sceneEditorLayout(layout, rect, canvasSize)
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
    func snapAxisKeepsOffsetWithinBounds() {
        #expect(sceneEditorSnapAxis(-300, 400, 1920, 10, true, true, []).position == 0)
        #expect(sceneEditorSnapAxis(1800, 400, 1920, 10, true, true, []).position == 1800)
        #expect(sceneEditorSnapAxis(2500, 400, 1920, 10, true, true, []).position == 1920)
        #expect(sceneEditorSnapAxis(-300, 400, 1920, 10, true, false, []).position == -300)
        #expect(sceneEditorSnapAxis(-500, 400, 1920, 10, true, false, []).position == -400)
        #expect(sceneEditorSnapAxis(1800, 400, 1920, 10, true, false, []).position == 1520)
        #expect(sceneEditorSnapAxis(300, 2000, 1920, 10, true, true, []).position == 300)
    }

    @Test(arguments: [SettingsAlignment.topLeft, .topRight, .bottomLeft, .bottomRight])
    func snapAxisBoundsMatchLayoutBounds(alignment: SettingsAlignment) {
        let size = CGSize(width: 400, height: 300)
        for position in [CGPoint(x: -1000, y: -1000), CGPoint(x: 3000, y: 3000)] {
            let x = sceneEditorSnapAxis(position.x, size.width, 1920, 10, true, alignment.isLeft(), [])
            let y = sceneEditorSnapAxis(position.y, size.height, 1080, 10, true, alignment.isTop(), [])
            let rect = CGRect(origin: CGPoint(x: x.position, y: y.position), size: size)
            let layout = sceneEditorLayout(makeLayout(alignment), rect, canvasSize)
            #expect((0 ... 100).contains(layout.x))
            #expect((0 ... 100).contains(layout.y))
            #expect([0, 100].contains(layout.x))
            #expect([0, 100].contains(layout.y))
        }
    }

    @Test
    func snapAxisSnapsToEdgesAndCenter() {
        #expect(sceneEditorSnapAxis(-5, 400, 1920, 10, true, true, []).position == 0)
        #expect(sceneEditorSnapAxis(1525, 400, 1920, 10, true, true, []).position == 1520)
        let center = sceneEditorSnapAxis(765, 400, 1920, 10, true, true, [])
        #expect(center.position == 760)
        #expect(center.guide == 960)
        #expect(sceneEditorSnapAxis(765, 400, 1920, 10, false, true, []).position == 765)
    }

    @Test
    func snapAxisSnapsToOtherWidgets() {
        let snap = sceneEditorSnapAxis(1003, 400, 1920, 10, true, true, [1000])
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
