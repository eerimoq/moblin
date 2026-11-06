import Foundation
@testable import Moblin
import Testing

struct WebBrowserWindowLayoutSuite {
    @Test
    func startsAboveCameraControls() {
        let frame = WebBrowserWindowLayout.defaultFrame(in: CGSize(width: 800, height: 400), bottomInset: 100)
        #expect(frame == CGRect(x: 547, y: 50, width: 250, height: 250))
    }

    @Test
    func movingStaysOnScreen() {
        let frame = CGRect(x: 200, y: 100, width: 200, height: 150)
        let size = CGSize(width: 800, height: 400)
        #expect(WebBrowserWindowLayout.moved(frame, by: CGSize(width: -1000, height: -1000), in: size)
            == CGRect(x: 0, y: 0, width: 200, height: 150))
        #expect(WebBrowserWindowLayout.moved(frame, by: CGSize(width: 1000, height: 1000), in: size)
            == CGRect(x: 600, y: 250, width: 200, height: 150))
    }

    @Test
    func resizingChangesWidthAndHeightIndependently() {
        let frame = CGRect(x: 20, y: 30, width: 250, height: 250)
        let size = CGSize(width: 800, height: 400)
        #expect(WebBrowserWindowLayout.resized(frame, by: CGSize(width: 50, height: -100), in: size)
            == CGRect(x: 20, y: 30, width: 300, height: 150))
        #expect(WebBrowserWindowLayout.resized(frame, by: CGSize(width: -1000, height: -1000), in: size)
            == CGRect(x: 20, y: 30, width: 120, height: 90))
        #expect(WebBrowserWindowLayout.resized(frame, by: CGSize(width: 1000, height: 1000), in: size)
            == CGRect(x: 20, y: 30, width: 780, height: 370))
    }

    @Test(arguments: WebBrowserResizeCorner.allCases)
    func cornerResizeKeepsOppositeCornerFixed(corner: WebBrowserResizeCorner) {
        let frame = CGRect(x: 100, y: 100, width: 240, height: 180)
        let result = WebBrowserWindowLayout.resized(frame, by: CGSize(width: 20, height: 30),
                                                    in: CGSize(width: 800, height: 600), corner: corner)
        #expect(result.width == (corner.isLeading ? 220 : 260))
        #expect(result.height == (corner.isTop ? 150 : 210))
        #expect(corner.isLeading ? result.maxX == frame.maxX : result.minX == frame.minX)
        #expect(corner.isTop ? result.maxY == frame.maxY : result.minY == frame.minY)
    }

    @Test
    func topLeftResizeStopsAtScreenAndMinimumSize() {
        let frame = CGRect(x: 100, y: 100, width: 240, height: 180)
        let size = CGSize(width: 800, height: 600)
        #expect(WebBrowserWindowLayout.resized(frame, by: CGSize(width: -1000, height: -1000),
                                               in: size, corner: .topLeading)
                == CGRect(x: 0, y: 0, width: 340, height: 280))
        #expect(WebBrowserWindowLayout.resized(frame, by: CGSize(width: 1000, height: 1000),
                                               in: size, corner: .topLeading)
                == CGRect(x: 220, y: 190, width: 120, height: 90))
    }

    @Test
    func rotationPreservesPlacementAndPreferredSize() {
        let landscape = CGSize(width: 800, height: 400)
        let layout = WebBrowserWindowLayout(
            frame: CGRect(x: 0, y: 250, width: 500, height: 150),
            in: landscape
        )
        #expect(layout.frame(in: CGSize(width: 300, height: 700))
            == CGRect(x: 0, y: 550, width: 300, height: 150))
        #expect(layout.frame(in: landscape) == CGRect(x: 0, y: 250, width: 500, height: 150))
    }

    @Test(arguments: [CGSize.zero, CGSize(width: 80, height: 60)])
    func fitsEvenWhenViewportIsSmallerThanMinimum(size: CGSize) {
        let layout = WebBrowserWindowLayout(frame: CGRect(x: 500, y: 300, width: 250, height: 250),
                                            in: CGSize(width: 800, height: 600))
        #expect(layout.frame(in: size) == CGRect(origin: .zero, size: size))
        let frame = WebBrowserWindowLayout.defaultFrame(in: size, bottomInset: 100)
        #expect(frame.minX >= 0 && frame.minY >= 0)
        #expect(frame.maxX <= size.width && frame.maxY <= size.height)
    }

    @Test
    func settingsRoundTripAndOldSettings() throws {
        let old = try JSONDecoder().decode(WebBrowserSettings.self, from: Data("{}".utf8))
        #expect(old.smallWindow == nil)
        old.smallWindow = WebBrowserWindowLayout(frame: CGRect(x: 12, y: 34, width: 200, height: 150),
                                                 in: CGSize(width: 800, height: 400))
        let restored = try JSONDecoder().decode(WebBrowserSettings.self, from: JSONEncoder().encode(old))
        #expect(restored.smallWindow?.frame(in: CGSize(width: 800, height: 400))
            == CGRect(x: 12, y: 34, width: 200, height: 150))
    }

    @Test
    func invalidSavedGeometryIsClamped() throws {
        let data = Data("{\"x\":-100,\"y\":100,\"width\":-10,\"height\":99999}".utf8)
        let layout = try JSONDecoder().decode(WebBrowserWindowLayout.self, from: data)
        #expect(layout.frame(in: CGSize(width: 800, height: 400))
            == CGRect(x: 0, y: 0, width: 120, height: 400))
    }
}
