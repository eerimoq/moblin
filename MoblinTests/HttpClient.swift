import AVFoundation
@testable import Moblin
import Testing

struct HttpClientSuite {
    @Test func responseParserNoData() async throws {
        let parser = HttpResponseParser()
        let (done, data) = parser.parse()
        #expect(!done)
        #expect(data == nil)
    }

    @Test func responseParserEmptyBody() async throws {
        let parser = HttpResponseParser()
        parser.append(data: "HTTP/1.1 200 OK\r\n\r\n".utf8Data)
        let (done, data) = parser.parse()
        #expect(done)
        #expect(data == Data())
    }

    @Test func responseParserBody() async throws {
        let parser = HttpResponseParser()
        let body = "1234567890".utf8Data
        parser.append(data: "HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n".utf8Data + body)
        let (done, data) = parser.parse()
        #expect(done)
        #expect(data == body)
    }

    @Test func responseParserHalfHeader() async throws {
        let parser = HttpResponseParser()
        let body = "1234567890".utf8Data
        parser.append(data: "HTTP/1.1 200 OK\r\nContent-Le".utf8Data)
        var (done, data) = parser.parse()
        #expect(!done)
        #expect(data == nil)
        parser.append(data: "ngth: \(body.count)\r\n\r\n".utf8Data + body)
        (done, data) = parser.parse()
        #expect(done)
        #expect(data == body)
    }

    @Test func responseParserHalfBody() async throws {
        let parser = HttpResponseParser()
        let body = "1234567890".utf8Data
        parser.append(data: "HTTP/1.1 200 OK\r\nContent-Length: \(body.count)\r\n\r\n".utf8Data + body[0 ..< 5])
        var (done, data) = parser.parse()
        #expect(!done)
        #expect(data == nil)
        parser.append(data: body[5...])
        (done, data) = parser.parse()
        #expect(done)
        #expect(data == body)
    }

    @Test func responseParserStatus400() async throws {
        let parser = HttpResponseParser()
        parser.append(data: "HTTP/1.1 400 OK\r\n\r\n".utf8Data)
        let (done, data) = parser.parse()
        #expect(done)
        #expect(data == nil)
    }
}
