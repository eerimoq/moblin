import Foundation

protocol IrlToolkitFetcherDelegate: AnyObject {
    func irlToolkitFetcherSuccess(url: String, reconnectTime: Double)
    func irlToolkitFetcherError(message: String)
}

private struct IrlToolkitResponse: Codable {
    let url: String
}

class IrlToolkitFetcher {
    private let url: String
    private let timeout: Double
    private var running = false
    private var task: URLSessionDataTask?
    var delegate: (any IrlToolkitFetcherDelegate)?

    init(url: String, timeout: Double) {
        self.url = url
        self.timeout = timeout
    }

    func start() {
        guard let url = URL(string: url) else {
            logger.info("irltoolkit: Bad URL \(url)")
            return
        }
        guard let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            logger.info("irltoolkit: Bad URL")
            return
        }
        guard let targetUrl = urlComponents.queryItems?.first(where: { $0.name == "url" }) else {
            logger.info("irltoolkit: URL query parameter missing in \(url)")
            return
        }
        guard let url = URL(string: "https://mys-lang.org/bar") else {
            logger.info("irltoolkit: Bad bonding service URL")
            return
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.httpBody = Data("{\"url\": \(targetUrl)}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        task = URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                guard self.running else {
                    return
                }
                if let error {
                    self.reportError(message: error.localizedDescription)
                    return
                }
                guard let response = response?.http else {
                    self.reportError(message: "Not an HTTP response")
                    return
                }
                guard response.isSuccessful, let data else {
                    self.reportError(message: "HTTP request failed with \(response.statusCode)")
                    return
                }
                do {
                    let response = try JSONDecoder().decode(IrlToolkitResponse.self, from: data)
                    if let message = isValidUrl(url: response.url, allowedSchemes: ["srtla"]) {
                        self.reportError(message: "Invalid SRT URL in response \(message)")
                        return
                    }
                    self.delegate?.irlToolkitFetcherSuccess(
                        url: response.url,
                        reconnectTime: self.timeout
                    )
                } catch {
                    self.reportError(message: "Failed to decode response")
                }
            }
        }
        task?.resume()
        running = true
    }

    func stop() {
        running = false
        task?.cancel()
        task = nil
    }

    private func reportError(message: String) {
        delegate?.irlToolkitFetcherError(message: "IRLToolkit: \(message)")
        logger.info("irltoolkit: \(message)")
    }
}
