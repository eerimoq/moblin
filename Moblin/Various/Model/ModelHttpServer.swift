extension Model {
    func reloadHttpServer() {
        httpServer?.stop()
        guard false else {
            return
        }
        httpServer = HttpServer(queue: .main, routes: [
            HttpServerRoute(path: "/index.html", handler: handleIndexHtml),
        ])
        httpServer?.start(port: .init(integer: 8080))
    }

    private func handleIndexHtml(request: HttpServerRequest, response: HttpServerResponse) {
        logger.info("http: Got index.html \(request.method)")
        response.send()
    }
}
