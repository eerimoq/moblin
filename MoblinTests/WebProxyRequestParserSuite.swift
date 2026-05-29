@testable import Moblin
import Testing

struct WebProxyRequestParserSuite {
    @Test
    func parsesConnectRequest() {
        let parser = WebProxyRequestParser()
        parser.append(data: "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n".utf8Data)

        let (done, request) = parser.parse()

        #expect(done)
        #expect(request == .connect(host: "example.com", port: 443, headerLength: 59))
    }

    @Test
    func parsesAbsoluteHttpRequest() {
        let parser = WebProxyRequestParser()
        let data = """
        GET http://example.com/path?a=b HTTP/1.1\r
        Host: example.com\r
        Proxy-Connection: keep-alive\r
        Proxy-Authorization: Basic aaa\r
        \r
        """.utf8Data
        parser.append(data: data)

        let (done, request) = parser.parse()

        #expect(done)
        #expect(request == .http(host: "example.com",
                                 port: 80,
                                 request: "GET /path?a=b HTTP/1.1\r\nHost: example.com\r\n\r\n".utf8Data))
    }

    @Test
    func waitsForCompleteHeaders() {
        let parser = WebProxyRequestParser()
        parser.append(data: "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com".utf8Data)

        let (done, request) = parser.parse()

        #expect(!done)
        #expect(request == nil)
    }

    @Test
    func rejectsAbsoluteHttpsRequest() {
        let parser = WebProxyRequestParser()
        parser.append(data: "GET https://example.com/ HTTP/1.1\r\nHost: example.com\r\n\r\n".utf8Data)

        let (done, request) = parser.parse()

        #expect(done)
        #expect(request == nil)
    }
}
