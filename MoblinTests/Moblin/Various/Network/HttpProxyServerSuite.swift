@testable import Moblin
import Testing

struct HttpProxyServerSuite {
    @Test
    func connectParserNoData() {
        let parser = HttpConnectRequestParser()
        let (done, result) = parser.parse()
        #expect(!done)
        #expect(result == nil)
    }

    @Test
    func connectParserIncompleteHeader() {
        let parser = HttpConnectRequestParser()
        parser.append(data: "CONNECT example.com:443 HTTP/1.1\r\n".utf8Data)
        let (done, result) = parser.parse()
        #expect(!done)
        #expect(result == nil)
    }

    @Test
    func connectParserValid() {
        let parser = HttpConnectRequestParser()
        parser.append(data: "CONNECT example.com:443 HTTP/1.1\r\nHost: example.com:443\r\n\r\n".utf8Data)
        let (done, result) = parser.parse()
        #expect(done)
        #expect(result?.destination == .hostPort(host: .init("example.com"),
                                                 port: .init(integerLiteral: 443)))
        #expect(result?.version == "HTTP/1.1")
    }

    @Test
    func connectParserWrongMethod() {
        let parser = HttpConnectRequestParser()
        parser.append(data: "GET / HTTP/1.1\r\n\r\n".utf8Data)
        let (done, result) = parser.parse()
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func connectParserInvalidPort() {
        let parser = HttpConnectRequestParser()
        parser.append(data: "CONNECT example.com:notaport HTTP/1.1\r\n\r\n".utf8Data)
        let (done, result) = parser.parse()
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func connectParserInvalidHttpVersion() {
        let parser = HttpConnectRequestParser()
        parser.append(data: "CONNECT example.com:443 FTTP/1.1\r\n\r\n".utf8Data)
        let (done, result) = parser.parse()
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func connectParserBodyOffset() {
        let parser = HttpConnectRequestParser()
        let header = "CONNECT example.com:80 HTTP/1.0\r\n\r\n"
        let body = "some body data".utf8Data
        parser.append(data: header.utf8Data + body)
        let (done, result) = parser.parse()
        #expect(done)
        #expect(result != nil)
        #expect(result?.bodyOffset == header.utf8Data.count)
        #expect(result?.destination == .hostPort(host: .init("example.com"),
                                                 port: .init(integerLiteral: 80)))
        #expect(result?.version == "HTTP/1.0")
    }

    @Test
    func connectParserSplitAcrossChunks() {
        let parser = HttpConnectRequestParser()
        parser.append(data: "CONNECT example.com:8080 HTTP/1.1\r\n".utf8Data)
        var (done, result) = parser.parse()
        #expect(!done)
        #expect(result == nil)
        parser.append(data: "\r\n".utf8Data)
        (done, result) = parser.parse()
        #expect(done)
        #expect(result?.destination == .hostPort(host: .init("example.com"),
                                                 port: .init(integerLiteral: 8080)))
    }
}
