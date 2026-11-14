@testable import Moblin
import Testing

private func parse(_ request: String) -> (Bool, HttpRequestParseResult?) {
    let parser = HttpRequestParser()
    parser.append(data: request.utf8Data)
    return parser.parse()
}

struct HttpServerSuite {
    @Test
    func pathWithoutQuery() throws {
        let (done, result) = parse("GET /snapshot HTTP/1.1\r\n\r\n")
        #expect(done)
        let request = try #require(result)
        #expect(request.method == "GET")
        #expect(request.path == "/snapshot")
        #expect(request.query.isEmpty)
        #expect(request.version == "HTTP/1.1")
        #expect(request.data.isEmpty)
    }

    @Test
    func singleQueryParameter() throws {
        let (done, result) = parse("GET /snapshot?age=5.5 HTTP/1.1\r\n\r\n")
        #expect(done)
        let request = try #require(result)
        #expect(request.path == "/snapshot")
        #expect(request.query == ["age": "5.5"])
    }

    @Test
    func multipleQueryParameters() throws {
        let (_, result) = parse("GET /a/b?foo=1&bar=two&baz=3 HTTP/1.0\r\n\r\n")
        let request = try #require(result)
        #expect(request.path == "/a/b")
        #expect(request.query == ["foo": "1", "bar": "two", "baz": "3"])
    }

    @Test
    func percentEncodedQueryParameters() throws {
        let (_, result) = parse("GET /x?na%20me=hello%20world&eq=a%3Db%26c HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(request.query == ["na me": "hello world", "eq": "a=b&c"])
    }

    @Test
    func queryParameterWithoutValue() throws {
        let (_, result) = parse("GET /x?flag&empty=&other=1 HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(request.query == ["flag": "", "empty": "", "other": "1"])
    }

    @Test
    func emptyQuery() throws {
        let (_, result) = parse("GET /x? HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(request.path == "/x")
        #expect(request.query.isEmpty)
    }

    @Test
    func questionMarkInQueryValue() throws {
        let (_, result) = parse("GET /x?a=b?c HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(request.path == "/x")
        #expect(request.query == ["a": "b?c"])
    }

    @Test
    func lastDuplicateQueryParameterWins() throws {
        let (_, result) = parse("GET /x?a=1&a=2 HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(request.query == ["a": "2"])
    }

    @Test
    func invalidPercentEncodingSkipsParameter() throws {
        let (_, result) = parse("GET /x?a%ZZ=1&b=2 HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(request.query == ["b": "2"])
    }

    @Test
    func headersAndBody() throws {
        let (done,
             result) =
            parse("POST /x?a=1 HTTP/1.1\r\nContent-Type: text/plain\r\nContent-Length: 5\r\n\r\nhello")
        #expect(done)
        let request = try #require(result)
        #expect(request.method == "POST")
        #expect(request.path == "/x")
        #expect(request.query == ["a": "1"])
        #expect(request.headers.contains(where: { $0.name == "content-type:" && $0.value == "text/plain" }))
        #expect(request.data == "hello".utf8Data)
    }

    @Test
    func incompleteBodyIsNotDone() {
        let (done, result) = parse("POST /x HTTP/1.1\r\nContent-Length: 10\r\n\r\nhello")
        #expect(!done)
        #expect(result == nil)
    }

    @Test
    func incompleteHeadersIsNotDone() {
        let (done, result) = parse("GET /x?a=1 HTTP/1.1\r\nHost: foo\r\n")
        #expect(!done)
        #expect(result == nil)
    }

    @Test
    func malformedStartLineFails() {
        let (done, result) = parse("GET /x\r\n\r\n")
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func unsupportedVersionFails() {
        let (done, result) = parse("GET /x HTTP/2\r\n\r\n")
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func parentDirectoryInPathFails() {
        let (done, result) = parse("GET /../secret HTTP/1.1\r\n\r\n")
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func parentDirectoryInQueryFails() {
        let (done, result) = parse("GET /x?file=.. HTTP/1.1\r\n\r\n")
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func negativeContentLengthFails() {
        let (done, result) = parse("GET /x HTTP/1.1\r\nContent-Length: -1\r\n\r\n")
        #expect(done)
        #expect(result == nil)
    }

    @Test
    func routeMatchesPathWithoutQuery() throws {
        let route = HttpServerRoute(path: "/snapshot") { _, _ in }
        let (_, result) = parse("GET /snapshot?age=5 HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(route.matches(path: request.path))
        #expect(!route.matches(path: "/snapshot/x"))
    }

    @Test
    func prefixRouteMatchesPath() throws {
        let route = HttpServerRoute(path: "/recordings/", prefixMatch: true) { _, _ in }
        let (_, result) = parse("GET /recordings/a.mp4?x=1 HTTP/1.1\r\n\r\n")
        let request = try #require(result)
        #expect(route.matches(path: request.path))
        #expect(!route.matches(path: "/recordings"))
    }
}
