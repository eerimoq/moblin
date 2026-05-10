import Foundation
import Network

protocol RemoteControlWebDelegate: AnyObject {
    func remoteControlWebConnected()
    func remoteControlWebGetStatus()
        -> (RemoteControlStatusGeneral, RemoteControlStatusTopLeft, RemoteControlStatusTopRight)
    func remoteControlWebGetSettings() -> RemoteControlSettings
    func remoteControlWebSetScene(id: UUID)
    func remoteControlWebSetAutoSceneSwitcher(id: UUID?)
    func remoteControlWebSetMic(id: String)
    func remoteControlWebSetBitratePreset(id: UUID)
    func remoteControlWebSetRecord(on: Bool)
    func remoteControlWebSetStream(on: Bool)
    func remoteControlWebSetZoom(x: Float)
    func remoteControlWebSetZoomPreset(id: UUID)
    func remoteControlWebSetDebugLogging(on: Bool)
    func remoteControlWebSetMute(on: Bool)
    func remoteControlWebSetTorch(on: Bool)
    func remoteControlWebReloadBrowserWidgets()
    func remoteControlWebSetSrtConnectionPrioritiesEnabled(enabled: Bool)
    func remoteControlWebSetSrtConnectionPriority(id: UUID, priority: Int, enabled: Bool)
    func remoteControlWebMoveToGimbalPreset(id: UUID)
    func remoteControlWebGetScoreboardSports() -> [String]
    func remoteControlWebSetScoreboardSport(sportId: String)
    func remoteControlWebUpdateScoreboard(config: RemoteControlScoreboardMatchConfig)
    func remoteControlWebToggleScoreboardClock()
    func remoteControlWebSetScoreboardDuration(minutes: Int)
    func remoteControlWebSetScoreboardClock(time: String)
    func remoteControlWebGetGolfScoreboard() -> RemoteControlGolfScoreboard
    func remoteControlWebUpdateGolfScoreboard(data: RemoteControlGolfScoreboard)
    func remoteControlWebSetFilter(filter: RemoteControlFilter, on: Bool)
    func remoteControlWebTriggerReaction(reaction: RemoteControlReaction)
    func remoteControlWebGetRecordings() -> [[String: String]]
    func remoteControlWebGetRecordingUrl(filename: String) -> URL?
    func remoteControlWebGetRecordingThumbnail(filename: String) -> Data?
    func remoteControlWebDeleteRecording(filename: String)
}

private struct StaticFile {
    let path: String
    let name: String
    let ext: String

    init(_ path: String, _ name: String, _ ext: String) {
        self.path = path
        self.name = name
        self.ext = ext
    }

    func makePath() -> String {
        "\(path)\(name).\(ext)"
    }
}

private let staticFiles: [StaticFile] = [
    StaticFile("/", "favicon", "ico"),
    StaticFile("/", "golf", "html"),
    StaticFile("/", "index", "html"),
    StaticFile("/", "recordings", "html"),
    StaticFile("/", "remote", "html"),
    StaticFile("/", "scoreboard", "html"),
    StaticFile("/", "volleyball", "png"),
    StaticFile("/css/", "app", "css"),
    StaticFile("/css/", "common", "css"),
    StaticFile("/css/", "golf", "css"),
    StaticFile("/css/", "recordings", "css"),
    StaticFile("/css/", "remote", "css"),
    StaticFile("/css/", "scoreboard", "css"),
    StaticFile("/js/", "app", "mjs"),
    StaticFile("/js/", "golf", "mjs"),
    StaticFile("/js/", "index", "mjs"),
    StaticFile("/js/", "components", "mjs"),
    StaticFile("/js/", "recordings", "mjs"),
    StaticFile("/js/", "remote", "mjs"),
    StaticFile("/js/", "scoreboard", "mjs"),
    StaticFile("/js/", "utils", "mjs"),
    StaticFile("/js/", "vendor", "mjs"),
]

private let recordingsPrefix = "/recordings/"
private let thumbnailsPrefix = "/thumbnails/"

class RemoteControlWeb {
    private var server: HttpServer?
    private var started: Bool = false
    private var websocketServer: NWListener?
    private var websocketPort: UInt16 = 0
    private let websocketRetryTimer = SimpleTimer(queue: .main)
    private weak var delegate: (any RemoteControlWebDelegate)?
    private var connections: [NWConnection] = []

    init(delegate: any RemoteControlWebDelegate) {
        self.delegate = delegate
    }

    func start(port: UInt16) {
        started = true
        startServer(port: port)
        startWebsocketServer(port: port + 1)
    }

    func stop() {
        started = false
        stopServer()
        stopWebsocketServer()
    }

    func stateChanged(state: RemoteControlAssistantStreamerState) {
        for connection in connections {
            send(connection: connection, message: .event(data: .state(data: state)))
        }
    }

    func log(entry: String) {
        for connection in connections {
            send(connection: connection, message: .event(data: .log(entry: entry)))
        }
    }

    func sendScoreboardUpdate(config: RemoteControlScoreboardMatchConfig) {
        for connection in connections {
            send(connection: connection, message: .event(data: .scoreboard(config: config)))
        }
    }

    func sendGolfScoreboardUpdate(data: RemoteControlGolfScoreboard) {
        for connection in connections {
            send(connection: connection, message: .event(data: .golfScoreboard(data: data)))
        }
    }

    private func startServer(port: UInt16) {
        var routes = staticFiles.map {
            HttpServerRoute(path: $0.makePath(), handler: handleStatic)
        }
        routes.append(HttpServerRoute(path: "/", handler: handleRoot))
        routes.append(HttpServerRoute(path: "/js/config.mjs", handler: handleConfigMjs))
        routes.append(HttpServerRoute(path: "/recordings.json", handler: handleRecordingsJson))
        routes.append(HttpServerRoute(
            path: recordingsPrefix,
            prefixMatch: true,
            handler: handleRecordingsFile
        ))
        routes.append(HttpServerRoute(
            path: thumbnailsPrefix,
            prefixMatch: true,
            handler: handleRecordingsThumbnail
        ))
        server = HttpServer(queue: .main,
                            routes: routes,
                            service: .init(name: "moblin", type: "_http._tcp"))
        server?.start(port: .init(integer: Int(port)))
    }

    private func startWebsocketServer(port: UInt16) {
        websocketPort = port
        setupWebsocketServer()
    }

    private func setupWebsocketServer() {
        let parameters = NWParameters.tcp
        let options = NWProtocolWebSocket.Options()
        options.autoReplyPing = true
        parameters.defaultProtocolStack.applicationProtocols.append(options)
        websocketServer = try? NWListener(using: parameters, on: .init(integer: Int(websocketPort)))
        websocketServer?.stateUpdateHandler = handleWebsocketStateUpdate
        websocketServer?.newConnectionHandler = handleNewWebsocketConnection
        websocketServer?.start(queue: .main)
    }

    private func stopServer() {
        server?.stop()
        server = nil
    }

    private func stopWebsocketServer() {
        for connection in connections {
            connection.cancel()
        }
        connections.removeAll()
        websocketRetryTimer.stop()
        websocketServer?.cancel()
        websocketServer = nil
    }

    private func handleRoot(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET" else {
            return
        }
        response.send(data: loadResource(name: "index", ext: "html"))
    }

    private func handleStatic(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET",
              let staticPath = staticFiles.first(where: {
                  request.path == $0.makePath()
              })
        else {
            return
        }
        response.send(data: loadResource(name: staticPath.name, ext: staticPath.ext))
    }

    private func handleConfigMjs(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET" else {
            return
        }
        let configMjs = """
        export const websocketPort = \(websocketPort);
        """
        response.send(text: configMjs)
    }

    private func handleRecordingsJson(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET" else {
            return
        }
        guard let delegate else {
            response.send(status: .notFound)
            return
        }
        let recordings = delegate.remoteControlWebGetRecordings()
        guard let json = try? JSONSerialization.data(withJSONObject: recordings) else {
            response.send(status: .notFound)
            return
        }
        response.send(data: json, status: .ok, contentType: "application/json")
    }

    private func handleRecordingsFile(request: HttpServerRequest, response: HttpServerResponse) {
        let filename = String(request.path.dropFirst(recordingsPrefix.count))
        switch request.method {
        case "GET":
            guard let fileUrl = delegate?.remoteControlWebGetRecordingUrl(filename: filename) else {
                response.send(status: .notFound)
                return
            }
            let headers = [
                SettingsHttpHeader(name: "Content-Disposition",
                                   value: "attachment; filename=\"\(filename)\""),
            ]
            response.sendFile(url: fileUrl, contentType: "video/mp4", headers: headers)
        case "DELETE":
            delegate?.remoteControlWebDeleteRecording(filename: filename)
            response.send(status: .ok)
        default:
            break
        }
    }

    private func handleRecordingsThumbnail(request: HttpServerRequest, response: HttpServerResponse) {
        guard request.method == "GET" else {
            return
        }
        let filename = String(request.path.dropFirst(thumbnailsPrefix.count))
        guard let thumbnail = delegate?.remoteControlWebGetRecordingThumbnail(filename: filename) else {
            response.send(status: .notFound)
            return
        }
        response.send(data: thumbnail, status: .ok, contentType: "image/jpeg")
    }

    private func handleWebsocketStateUpdate(_ newState: NWListener.State) {
        switch newState {
        case .failed:
            websocketRetryTimer.startSingleShot(timeout: 1) { [weak self] in
                guard let self, started else {
                    return
                }
                setupWebsocketServer()
            }
        default:
            break
        }
    }

    private func handleNewWebsocketConnection(_ connection: NWConnection) {
        connections.append(connection)
        connection.start(queue: .main)
        receiveWebsocketPacket(connection: connection)
        delegate?.remoteControlWebConnected()
    }

    private func receiveWebsocketPacket(connection: NWConnection) {
        connection.receiveMessage { data, context, _, _ in
            switch context?.webSocketOperation() {
            case .text:
                if let data, !data.isEmpty {
                    self.handleWebsocketMessage(connection: connection, packet: data)
                    self.receiveWebsocketPacket(connection: connection)
                } else {
                    self.handleDisconnected(connection: connection)
                }
            case .ping:
                connection.sendWebSocket(data: data, opcode: .pong)
                self.receiveWebsocketPacket(connection: connection)
            case .pong:
                self.receiveWebsocketPacket(connection: connection)
            default:
                self.handleDisconnected(connection: connection)
            }
        }
    }

    private func handleDisconnected(connection: NWConnection) {
        connection.cancel()
        connections.removeAll(where: { $0 === connection })
    }

    private func handleWebsocketMessage(connection: NWConnection, packet: Data) {
        guard let message = String(bytes: packet, encoding: .utf8) else {
            return
        }
        do {
            switch try RemoteControlMessageToStreamer.fromJson(data: message) {
            case let .request(id: id, data: data):
                handleRequest(connection: connection, id: id, data: data)
            default:
                break
            }
        } catch {
            logger.info("remote-control-web: Decode error \(error) for message \(message)")
        }
    }

    private func handleRequest(connection: NWConnection, id: Int, data: RemoteControlRequest) {
        guard let delegate else {
            return
        }
        switch data {
        case .getStatus:
            let (general, topLeft, topRight) = delegate.remoteControlWebGetStatus()
            send(connection: connection,
                 message: .response(
                     id: id,
                     result: .ok,
                     data: .getStatus(general: general, topLeft: topLeft, topRight: topRight)
                 ))
        case .getSettings:
            let data = delegate.remoteControlWebGetSettings()
            send(connection: connection,
                 message: .response(id: id, result: .ok, data: .getSettings(data: data)))
        case let .setScene(id: sceneId):
            delegate.remoteControlWebSetScene(id: sceneId)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setAutoSceneSwitcher(id: autoSceneSwitcherId):
            delegate.remoteControlWebSetAutoSceneSwitcher(id: autoSceneSwitcherId)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setMic(id: micId):
            delegate.remoteControlWebSetMic(id: micId)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setBitratePreset(id: bitratePresetId):
            delegate.remoteControlWebSetBitratePreset(id: bitratePresetId)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setRecord(on: on):
            delegate.remoteControlWebSetRecord(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setStream(on: on):
            delegate.remoteControlWebSetStream(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setZoom(x: x):
            delegate.remoteControlWebSetZoom(x: x)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setZoomPreset(id: presetId):
            delegate.remoteControlWebSetZoomPreset(id: presetId)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setMute(on: on):
            delegate.remoteControlWebSetMute(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setTorch(on: on):
            delegate.remoteControlWebSetTorch(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setDebugLogging(on: on):
            delegate.remoteControlWebSetDebugLogging(on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case .reloadBrowserWidgets:
            delegate.remoteControlWebReloadBrowserWidgets()
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setSrtConnectionPrioritiesEnabled(enabled: enabled):
            delegate.remoteControlWebSetSrtConnectionPrioritiesEnabled(enabled: enabled)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setSrtConnectionPriority(id: priorityId, priority: priority, enabled: enabled):
            delegate.remoteControlWebSetSrtConnectionPriority(
                id: priorityId,
                priority: priority,
                enabled: enabled
            )
            sendEmptyOkResponse(connection: connection, id: id)
        case let .moveToGimbalPreset(id: presetId):
            delegate.remoteControlWebMoveToGimbalPreset(id: presetId)
            sendEmptyOkResponse(connection: connection, id: id)
        case .getScoreboardSports:
            let sports = delegate.remoteControlWebGetScoreboardSports()
            send(connection: connection,
                 message: .response(id: id,
                                    result: .ok,
                                    data: .getScoreboardSports(names: sports)))
        case let .setScoreboardSport(sportId):
            delegate.remoteControlWebSetScoreboardSport(sportId: sportId)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .updateScoreboard(config):
            delegate.remoteControlWebUpdateScoreboard(config: config)
            sendEmptyOkResponse(connection: connection, id: id)
        case .toggleScoreboardClock:
            delegate.remoteControlWebToggleScoreboardClock()
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setScoreboardDuration(minutes):
            delegate.remoteControlWebSetScoreboardDuration(minutes: minutes)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setScoreboardClock(time):
            delegate.remoteControlWebSetScoreboardClock(time: time)
            sendEmptyOkResponse(connection: connection, id: id)
        case .getGolfScoreboard:
            let data = delegate.remoteControlWebGetGolfScoreboard()
            send(connection: connection,
                 message: .response(id: id, result: .ok, data: .getGolfScoreboard(data: data)))
        case let .updateGolfScoreboard(data):
            delegate.remoteControlWebUpdateGolfScoreboard(data: data)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .setFilter(filter: filter, on: on):
            delegate.remoteControlWebSetFilter(filter: filter, on: on)
            sendEmptyOkResponse(connection: connection, id: id)
        case let .triggerReaction(reaction: reaction):
            delegate.remoteControlWebTriggerReaction(reaction: reaction)
            sendEmptyOkResponse(connection: connection, id: id)
        default:
            break
        }
    }

    private func send(connection: NWConnection, message: RemoteControlMessageToAssistant) {
        do {
            let message = try message.toJson()
            connection.sendWebSocket(data: message.utf8Data, opcode: .text)
        } catch {
            logger.info("remote-control-web: Encode failed")
        }
    }

    private func sendEmptyOkResponse(connection: NWConnection, id: Int) {
        send(connection: connection, message: .response(id: id, result: .ok, data: nil))
    }
}
