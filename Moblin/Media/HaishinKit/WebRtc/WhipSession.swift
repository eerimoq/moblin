import Foundation

private let whipQueue = DispatchQueue(label: "com.eerimoq.Moblin.webrtc.whip")

protocol WhipSessionDelegate: AnyObject {
    func whipSessionOnConnected(_ session: WhipSession)
    func whipSessionOnDisconnected(_ session: WhipSession)
    func whipSessionOnError(_ session: WhipSession, message: String)
}

class WhipSession {
    private var url: String = ""
    private var resourceUrl: String?
    private var localSdp: SdpMessage?
    private var remoteSdp: SdpMessage?
    private let iceAgent: IceAgent
    weak var delegate: WhipSessionDelegate?
    private(set) var remoteIceUfrag: String?
    private(set) var remoteIcePwd: String?

    init() {
        iceAgent = IceAgent()
    }

    var localIceUfrag: String {
        iceAgent.ufrag
    }

    var localIcePwd: String {
        iceAgent.pwd
    }

    func start(url: String, offer: SdpMessage) {
        whipQueue.async {
            self.startInternal(url: url, offer: offer)
        }
    }

    func stop() {
        whipQueue.async {
            self.stopInternal()
        }
    }

    private func startInternal(url: String, offer: SdpMessage) {
        self.url = whipToHttpsUrl(url)
        localSdp = offer
        sendOffer(offer)
    }

    private func stopInternal() {
        deleteResource()
        resourceUrl = nil
        remoteSdp = nil
    }

    private func sendOffer(_ offer: SdpMessage) {
        guard let url = URL(string: url) else {
            delegate?.whipSessionOnError(self, message: "Invalid WHIP URL")
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.httpBody = offer.encode().data(using: .utf8)
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            whipQueue.async {
                self?.handleOfferResponse(data: data, response: response, error: error)
            }
        }
        task.resume()
    }

    private func handleOfferResponse(data: Data?, response: URLResponse?, error: Error?) {
        if let error {
            delegate?.whipSessionOnError(self, message: "WHIP offer failed: \(error.localizedDescription)")
            return
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            delegate?.whipSessionOnError(self, message: "WHIP: Invalid response")
            return
        }
        guard httpResponse.statusCode == 201 else {
            delegate?.whipSessionOnError(
                self,
                message: "WHIP: Server returned status \(httpResponse.statusCode)"
            )
            return
        }
        if let location = httpResponse.value(forHTTPHeaderField: "Location") {
            if location.hasPrefix("http://") || location.hasPrefix("https://") {
                resourceUrl = location
            } else {
                guard let baseUrl = URL(string: url) else {
                    return
                }
                resourceUrl = URL(string: location, relativeTo: baseUrl)?.absoluteString
            }
        }
        guard let data, let sdpString = String(data: data, encoding: .utf8) else {
            delegate?.whipSessionOnError(self, message: "WHIP: No SDP in response")
            return
        }
        let answer = SdpMessage.decode(from: sdpString)
        remoteSdp = answer
        remoteIceUfrag = answer.iceUfrag ?? answer.media.first?.iceUfrag
        remoteIcePwd = answer.icePwd ?? answer.media.first?.icePwd
        if remoteIceUfrag != nil, remoteIcePwd != nil {
            delegate?.whipSessionOnConnected(self)
        } else {
            delegate?.whipSessionOnError(
                self,
                message: "WHIP: Missing ICE credentials in answer"
            )
        }
    }

    private func deleteResource() {
        guard let resourceUrl, let url = URL(string: resourceUrl) else {
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let task = URLSession.shared.dataTask(with: request) { _, _, _ in }
        task.resume()
    }
}

func whipToHttpsUrl(_ url: String) -> String {
    if url.hasPrefix("whip://") {
        return "https://" + url.dropFirst("whip://".count)
    }
    return url
}
