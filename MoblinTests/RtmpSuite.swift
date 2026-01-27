import AVFoundation
@testable import Moblin
import Testing

struct RtmpSuite {
    @Test
    func twitchUrl() {
        let url = "rtmp://foo.com/app/live_asefwefwefwef"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com/app")
        #expect(streamKey == "live_asefwefwefwef")
    }

    @Test
    func kickUrl() {
        let url = "rtmp://foo.com/foobar"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com")
        #expect(streamKey == "foobar")
    }

    @Test
    func bilibiliUrl() {
        let url = "rtmp://foo.com/live/?foo=bar&a=b"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com/live")
        #expect(streamKey == "?foo=bar&a=b")
    }

    @Test
    func twitcastingUrl() {
        let url = "rtmp://foo.com/live/g:3234234?key=1234"
        let streamUrl = makeRtmpUri(url: url)
        let streamKey = makeRtmpStreamKey(url: url)
        #expect(streamUrl == "rtmp://foo.com/live")
        #expect(streamKey == "g:3234234?key=1234")
    }
}
