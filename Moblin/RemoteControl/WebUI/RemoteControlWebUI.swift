private struct StaticPath {
    let path: String
    let name: String
    let ext: String

    init(_ path: String, _ name: String, _ ext: String) {
        self.path = path
        self.name = name
        self.ext = ext
    }

    func makePath() -> String {
        return "\(path)\(name).\(ext)"
    }
}

private let staticPaths: [StaticPath] = [
    StaticPath("/", "index", "html"),
    StaticPath("/css/", "vanilla-framework-version-4.14.0.min", "css"),
    StaticPath("/css/", "f3b9cc97-Ubuntu[wdth,wght]-latin", "woff2"),
    StaticPath("/css/", "c1b12cdf-Ubuntu-Italic[wdth,wght]-latin", "woff2"),
    StaticPath("/css/", "0bd4277a-UbuntuMono[wght]-latin", "woff2"),
    StaticPath("/js/", "index", "mjs"),
    StaticPath("/js/", "utils", "mjs"),
]

class RemoteControlWebUI {
    private var server: HttpServer?

    func reload() {
        server?.stop()
        let routes = staticPaths.map {
            HttpServerRoute(path: $0.makePath(), handler: handleStatic)
        }
        server = HttpServer(queue: .main, routes: routes)
        server?.start(port: .init(integer: 80))
    }

    private func handleStatic(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET",
              let staticPath = staticPaths.first(where: {
                  request.path == $0.makePath()
              })
        else {
            return
        }
        response.send(text: loadStringResource(name: staticPath.name, ext: staticPath.ext))
    }
}
