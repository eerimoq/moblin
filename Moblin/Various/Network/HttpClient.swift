import Foundation
import Network

class HttpResponseParser {
    private var data = Data()

    init() {}

    func append(data: Data) {
        self.data += data
    }

    func parse() -> (Bool, Data?) {
        var offset = 0
        guard let (statusLine, nextLineOffset) = getLine(data: data, offset: offset) else {
            return (false, nil)
        }
        offset = nextLineOffset
        let statusParts = statusLine.split(separator: " ")
        guard statusLine.starts(with: "HTTP"),
              statusParts.count >= 3,
              let statusCode = Int(statusParts[1]), (200 ... 299).contains(statusCode)
        else {
            return (true, nil)
        }
        var contentLength = 0
        while let (line, nextLineOffset) = getLine(data: data, offset: offset) {
            let parts = line.lowercased().split(separator: " ")
            if parts.count == 2, parts.first == "content-length:", let length = parts.last, let length = Int(length) {
                contentLength = length
            } else if line.isEmpty {
                let body = data.advanced(by: nextLineOffset)
                if body.count == contentLength {
                    return (true, body)
                }
            }
            offset = nextLineOffset
        }
        return (false, nil)
    }

    private func getLine(data: Data, offset: Int) -> (String, Int)? {
        let data = data.advanced(by: offset)
        guard let rIndex = data.firstIndex(of: 0xD), data.count > rIndex, data[rIndex + 1] == 0xA else {
            return nil
        }
        guard let line = String(bytes: data[0 ..< rIndex], encoding: .utf8) else {
            return nil
        }
        return (line, offset + rIndex + 2)
    }
}

private class InterfaceTypeHttpClient {
    private static var interfaceTypes: Atomic<[NWInterface.InterfaceType]> = .init([.cellular, .wifi, .wiredEthernet])
    private var interfaceTypes: [NWInterface.InterfaceType] = []
    private var interfaceTypeIndex: Int = 0
    private var connection: NWConnection?
    private let timer = SimpleTimer(queue: .main)
    private var completion: ((Data?) -> Void)?
    private var responseParser = HttpResponseParser()

    init() {
        interfaceTypes = Self.interfaceTypes.value
    }

    private func stop() {
        completion = nil
        timer.stop()
        connection?.stateUpdateHandler = nil
        connection?.cancel()
        connection = nil
    }

    private func completed(data: Data?) {
        completion?(data)
        stop()
    }

    func call(request: URLRequest, body: Data?, completion: @escaping (Data?) -> Void) {
        guard let (host, port, useTls, content) = createRequest(request: request, body: body) else {
            completion(nil)
            return
        }
        let endpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integer: port))
        self.completion = completion
        timer.startSingleShot(timeout: 60) {
            self.completed(data: nil)
        }
        connect(endpoint, useTls) { interfaceTypeIndex in
            self.connection?.send(content: content, completion: .contentProcessed { error in
                if error != nil {
                    self.completed(data: nil)
                    return
                }
                self.receiveData(interfaceTypeIndex)
            })
        }
    }

    private func connect(_ endpoint: NWEndpoint, _ useTls: Bool, _ onConnected: @escaping (Int) -> Void) {
        guard interfaceTypeIndex < interfaceTypes.count else {
            completed(data: nil)
            return
        }
        responseParser = HttpResponseParser()
        let interfaceType = interfaceTypes[interfaceTypeIndex]
        let interfaceTypeIndex = interfaceTypeIndex
        let parameters: NWParameters = (useTls ? .tls : .tcp)
        parameters.requiredInterfaceType = interfaceType
        connection = NWConnection(to: endpoint, using: parameters)
        connection?.stateUpdateHandler = { state in
            guard self.isCurrentConnection(interfaceTypeIndex) else {
                return
            }
            switch state {
            case .preparing:
                break
            case .ready:
                self.updateGlobalInterfaceTypesIfNeeded()
                onConnected(interfaceTypeIndex)
            default:
                self.connection?.stateUpdateHandler = nil
                self.connection?.cancel()
                self.interfaceTypeIndex += 1
                self.connect(endpoint, useTls, onConnected)
            }
        }
        connection?.start(queue: .main)
    }

    private func isCurrentConnection(_ interfaceTypeIndex: Int) -> Bool {
        return self.interfaceTypeIndex == interfaceTypeIndex
    }

    private func updateGlobalInterfaceTypesIfNeeded() {
        guard interfaceTypeIndex != 0 else {
            return
        }
        var interfaceTypes = interfaceTypes
        let interfaceType = interfaceTypes[0]
        interfaceTypes[0] = interfaceTypes[interfaceTypeIndex]
        interfaceTypes[interfaceTypeIndex] = interfaceType
        Self.interfaceTypes.mutate { $0 = interfaceTypes }
    }

    private func createRequest(request: URLRequest, body: Data?) -> (String, Int, Bool, Data)? {
        guard let url = request.url,
              let host = url.host,
              let scheme = url.scheme,
              let method = request.httpMethod
        else {
            return nil
        }
        let useTls = scheme == "https"
        let port = url.port ?? (useTls ? 443 : 80)
        var path = url.path()
        if path.isEmpty {
            path = "/"
        }
        if let query = url.query {
            path += "?\(query)"
        }
        var data = "\(method) \(path) HTTP/1.1\r\nHost: \(host)\r\n"
        if let headers = request.allHTTPHeaderFields {
            for (name, value) in headers {
                data += "\(name): \(value)\r\n"
            }
        }
        if let body {
            data += "Content-Length: \(body.count)\r\n"
        }
        data += "\r\n"
        var content = data.utf8Data
        if let body {
            content += body
        }
        return (host, port, useTls, content)
    }

    private func receiveData(_ interfaceTypeIndex: Int) {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, _, error in
            guard self.isCurrentConnection(interfaceTypeIndex) else {
                return
            }
            guard let data, error == nil else {
                self.completed(data: nil)
                return
            }
            self.handleResponse(data: data)
            self.receiveData(interfaceTypeIndex)
        }
    }

    private func handleResponse(data: Data) {
        responseParser.append(data: data)
        let (done, body) = responseParser.parse()
        if done {
            completed(data: body)
        }
    }
}

func httpCall(request: URLRequest, body: Data?, completion: @escaping (Data?) -> Void) {
    InterfaceTypeHttpClient().call(request: request, body: body) { data in
        if let data {
            completion(data)
        } else {
            httpCallUrlSession(request: request, body: body, completion: completion)
        }
    }
}

private func httpCallUrlSession(request: URLRequest, body: Data?, completion: @escaping (Data?) -> Void) {
    if let body {
        URLSession.shared.uploadTask(with: request, from: body) { data, response, error in
            guard error == nil, response?.http?.isSuccessful == true else {
                completion(nil)
                return
            }
            completion(data)
        }.resume()
    } else {
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, response?.http?.isSuccessful == true else {
                completion(nil)
                return
            }
            completion(data)
        }.resume()
    }
}
