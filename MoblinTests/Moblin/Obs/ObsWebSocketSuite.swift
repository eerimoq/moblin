import Foundation
@testable import Moblin
import Testing

@MainActor
private final class Delegate: ObsWebsocketDelegate {
    let connected = MessageQueue<Void>()
    let sceneChanges = MessageQueue<String>()
    let muteChanges = MessageQueue<(String, Bool)>()
    let streamStatuses = MessageQueue<(Bool, ObsOutputState?)>()
    let recordStatuses = MessageQueue<(Bool, ObsOutputState?)>()
    let audioVolumes = MessageQueue<[(String, [Float])]>()

    func obsWebsocketConnected() {
        connected.put(())
    }

    func obsWebsocketSceneChanged(sceneName: String) {
        sceneChanges.put(sceneName)
    }

    func obsWebsocketInputMuteStateChangedEvent(inputName: String, muted: Bool) {
        muteChanges.put((inputName, muted))
    }

    func obsWebsocketStreamStatusChanged(active: Bool, state: ObsOutputState?) {
        streamStatuses.put((active, state))
    }

    func obsWebsocketRecordStatusChanged(active: Bool, state: ObsOutputState?) {
        recordStatuses.put((active, state))
    }

    func obsWebsocketAudioVolume(volumes: [ObsAudioInputVolume]) {
        audioVolumes.put(volumes.map { ($0.name, $0.volumes) })
    }
}

@MainActor
private final class Completion<Value: Sendable> {
    private let results = MessageQueue<Result<Value, String>>()

    func onSuccess(_ value: Value) {
        results.put(.success(value))
    }

    func onError(_ message: String) {
        results.put(.failure(message))
    }

    func get() async throws -> Value {
        try await results.get().get()
    }

    func getError() async -> String? {
        if case let .failure(message) = await results.get() {
            return message
        }
        return nil
    }
}

private extension Completion where Value == Void {
    func onSuccess() {
        onSuccess(())
    }
}

@MainActor
private struct Connection {
    let server: ObsWebSocketServerMock
    let delegate: Delegate
    let obs: ObsWebSocket

    static func make(serverPassword: String? = nil, clientPassword: String = "") async throws -> Connection {
        let server = try ObsWebSocketServerMock(password: serverPassword)
        let delegate = Delegate()
        let obs = await ObsWebSocket(url: server.url(), password: clientPassword, delegate: delegate)
        obs.start()
        return Connection(server: server, delegate: delegate, obs: obs)
    }

    static func makeConnected() async throws -> Connection {
        let connection = try await make()
        try await connection.server.connect()
        await connection.delegate.connected.get()
        return connection
    }

    func expectRequest(type: String, data: String? = nil) async throws -> ObsMockRequest {
        let request = try await server.receiveRequest()
        #expect(request.type == type)
        #expect(request.data == data)
        return request
    }
}

@MainActor
struct ObsWebSocketSuite {
    @Test
    func connectWithoutAuthentication() async throws {
        let connection = try await Connection.make()
        #expect(!connection.obs.isConnected())
        await connection.server.acceptConnection()
        connection.server.sendHello()
        let identify = try await connection.server.receiveIdentify()
        #expect(identify.rpcVersion == 1)
        #expect(identify.authentication == nil)
        #expect(!connection.obs.isConnected())
        connection.server.sendIdentified()
        await connection.delegate.connected.get()
        #expect(connection.obs.isConnected())
        connection.obs.stop()
        #expect(!connection.obs.isConnected())
    }

    @Test
    func connectWithAuthentication() async throws {
        let connection = try await Connection.make(serverPassword: "secret", clientPassword: "secret")
        await connection.server.acceptConnection()
        connection.server.sendHello()
        let identify = try await connection.server.receiveIdentify()
        #expect(identify.authentication == "0xGVPQbDiHRgqezuAY0t8iJy5bjIOgG42ebJNd0yDps=")
        #expect(identify.authentication == connection.server.expectedAuthentication())
        connection.server.sendIdentified()
        await connection.delegate.connected.get()
        #expect(connection.obs.isConnected())
        connection.obs.stop()
    }

    @Test
    func wrongPassword() async throws {
        let connection = try await Connection.make(serverPassword: "secret", clientPassword: "wrong")
        await connection.server.acceptConnection()
        connection.server.sendHello()
        let identify = try await connection.server.receiveIdentify()
        #expect(identify.authentication != nil)
        #expect(identify.authentication != connection.server.expectedAuthentication())
        connection.server.close(code: 4009)
        await connection.server.acceptConnection()
        #expect(!connection.obs.isConnected())
        #expect(connection.obs.connectionErrorMessage == "Disconnected")
        connection.obs.stop()
    }

    @Test
    func reconnectAfterServerDisconnect() async throws {
        let connection = try await Connection.makeConnected()
        connection.server.disconnect()
        try await connection.server.connect()
        await connection.delegate.connected.get()
        #expect(connection.obs.isConnected())
        #expect(connection.obs.connectionErrorMessage == "Disconnected")
        connection.obs.stop()
    }

    @Test
    func restart() async throws {
        let connection = try await Connection.makeConnected()
        connection.obs.stop()
        connection.obs.start()
        try await connection.server.connect()
        await connection.delegate.connected.get()
        #expect(connection.obs.isConnected())
        connection.obs.stop()
    }

    @Test
    func requestWhenNotConnected() async throws {
        let connection = try await Connection.make()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        #expect(await completion.getError() == "Not connected to server")
        connection.obs.stop()
    }

    @Test
    func getSceneList() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSceneList")
        #expect(request.id == "1")
        connection.server.respond(to: request, data: """
        {"currentProgramSceneName":"Main","currentPreviewSceneName":null,"scenes":[\
        {"sceneName":"Camera","sceneIndex":0,"sceneUuid":"a"},\
        {"sceneName":"Main","sceneIndex":1,"sceneUuid":"b"}]}
        """)
        let sceneList = try await completion.get()
        #expect(sceneList.current == "Main")
        #expect(sceneList.scenes == ["Main", "Camera"])
        connection.obs.stop()
    }

    @Test
    func requestIdsIncrement() async throws {
        let connection = try await Connection.makeConnected()
        let first = Completion<ObsSceneList>()
        let second = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: first.onSuccess, onError: first.onError)
        connection.obs.getSceneList(onSuccess: second.onSuccess, onError: second.onError)
        let firstRequest = try await connection.expectRequest(type: "GetSceneList")
        let secondRequest = try await connection.expectRequest(type: "GetSceneList")
        #expect(firstRequest.id == "1")
        #expect(secondRequest.id == "2")
        connection.server.respond(to: secondRequest, data: #"{"currentProgramSceneName":"B","scenes":[]}"#)
        connection.server.respond(to: firstRequest, data: #"{"currentProgramSceneName":"A","scenes":[]}"#)
        #expect(try await first.get().current == "A")
        #expect(try await second.get().current == "B")
        connection.obs.stop()
    }

    @Test
    func requestErrorWithComment() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSceneList")
        connection.server.respond(to: request, errorCode: 600, comment: "No scenes")
        #expect(await completion.getError() == "Operation failed with resourceNotFound (No scenes)")
        connection.obs.stop()
    }

    @Test
    func requestErrorWithoutComment() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSceneList")
        connection.server.respond(to: request, errorCode: 205)
        #expect(await completion.getError() == "Operation failed with genericError")
        connection.obs.stop()
    }

    @Test
    func requestErrorWithUnknownCode() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSceneList")
        connection.server.respond(to: request, errorCode: 999)
        #expect(await completion.getError() == "Operation failed with unknown")
        connection.obs.stop()
    }

    @Test
    func responseDataMissing() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSceneList")
        connection.server.respond(to: request)
        #expect(await completion.getError() == "Response data missing")
        connection.obs.stop()
    }

    @Test
    func responseDataMalformed() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsSceneList>()
        connection.obs.getSceneList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSceneList")
        connection.server.respond(to: request, data: #"{"scenes":[]}"#)
        #expect(await completion.getError() == "JSON decode failed")
        connection.obs.stop()
    }

    @Test
    func getSceneItemList() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<[GetSceneItemListItem]>()
        connection.obs.getSceneItemList(sceneName: "Main",
                                        onSuccess: completion.onSuccess,
                                        onError: completion.onError)
        let request = try await connection.expectRequest(
            type: "GetSceneItemList",
            data: #"{"sceneName":"Main"}"#
        )
        connection.server.respond(to: request, data: """
        {"sceneItems":[\
        {"sourceName":"Group","inputKind":null,"isGroup":true,"sceneItemEnabled":true,"sceneItemId":1},\
        {"sourceName":"Mic","inputKind":"coreaudio_input_capture","isGroup":null,"sceneItemEnabled":false,\
        "sceneItemId":2}]}
        """)
        let items = try await completion.get()
        #expect(items.count == 2)
        #expect(items[0].sourceName == "Group")
        #expect(items[0].inputKind == nil)
        #expect(items[0].sceneItemEnabled)
        #expect(items[1].sourceName == "Mic")
        #expect(items[1].inputKind == "coreaudio_input_capture")
        #expect(!items[1].sceneItemEnabled)
        connection.obs.stop()
    }

    @Test
    func getSpecialInputs() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<GetSpecialInputsResponse>()
        connection.obs.getSpecialInputs(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetSpecialInputs")
        connection.server.respond(to: request, data: """
        {"desktop1":"Desktop Audio","desktop2":null,"mic1":"Mic/Aux","mic2":null,"mic3":"Headset","mic4":null}
        """)
        #expect(try await completion.get().mics() == ["Mic/Aux", "Headset"])
        connection.obs.stop()
    }

    @Test
    func getInputList() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<[String]>()
        connection.obs.getInputList(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetInputList")
        connection.server.respond(to: request, data: """
        {"inputs":[{"inputName":"Mic","inputKind":"coreaudio_input_capture","inputUuid":"a"},\
        {"inputName":"Media","inputKind":"ffmpeg_source","inputUuid":"b"}]}
        """)
        #expect(try await completion.get() == ["Mic", "Media"])
        connection.obs.stop()
    }

    @Test
    func setCurrentProgramScene() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.setCurrentProgramScene(name: "Camera",
                                              onSuccess: completion.onSuccess,
                                              onError: completion.onError)
        let request = try await connection.expectRequest(type: "SetCurrentProgramScene",
                                                         data: #"{"sceneName":"Camera"}"#)
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func setMediaSourceSettings() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.setMediaSourceSettings(name: "Media",
                                              input: "srt://127.0.0.1:9000",
                                              onSuccess: completion.onSuccess,
                                              onError: completion.onError)
        let request = try await connection.expectRequest(
            type: "SetInputSettings",
            data: #"{"inputName":"Media","inputSettings":{"input":"srt://127.0.0.1:9000"}}"#
        )
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func setInputSettings() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.setInputSettings(inputName: "Media",
                                        onSuccess: completion.onSuccess,
                                        onError: completion.onError)
        let request = try await connection.expectRequest(type: "SetInputSettings",
                                                         data: #"{"inputName":"Media","inputSettings":{}}"#)
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func getStreamStatus() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsStreamStatus>()
        connection.obs.getStreamStatus(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetStreamStatus")
        connection.server.respond(to: request, data: """
        {"outputActive":true,"outputReconnecting":false,"outputTimecode":"00:01:00.000",\
        "outputDuration":60000,"outputCongestion":0,"outputBytes":1000,"outputSkippedFrames":0,\
        "outputTotalFrames":1800}
        """)
        #expect(try await completion.get().active)
        connection.obs.stop()
    }

    @Test
    func getRecordStatus() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<ObsRecordStatus>()
        connection.obs.getRecordStatus(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetRecordStatus")
        connection.server.respond(to: request, data: """
        {"outputActive":false,"outputPaused":false,"outputTimecode":"00:00:00.000",\
        "outputDuration":0,"outputBytes":0}
        """)
        #expect(try await completion.get().active == false)
        connection.obs.stop()
    }

    @Test
    func startStream() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.startStream(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StartStream")
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func startStreamAlreadyStreaming() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.startStream(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StartStream")
        connection.server.respond(to: request, errorCode: 500, comment: "Output is running")
        #expect(await completion.getError() == "Already streaming")
        connection.obs.stop()
    }

    @Test
    func startStreamOtherError() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.startStream(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StartStream")
        connection.server.respond(to: request, errorCode: 207)
        #expect(await completion.getError() == "Operation failed with notReady")
        connection.obs.stop()
    }

    @Test
    func stopStream() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.stopStream(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StopStream")
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func stopStreamNotStreaming() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.stopStream(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StopStream")
        connection.server.respond(to: request, errorCode: 501)
        #expect(await completion.getError() == "Not streaming")
        connection.obs.stop()
    }

    @Test
    func startRecord() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.startRecord(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StartRecord")
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func startRecordAlreadyRecording() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.startRecord(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StartRecord")
        connection.server.respond(to: request, errorCode: 500)
        #expect(await completion.getError() == "Already recording")
        connection.obs.stop()
    }

    @Test
    func stopRecord() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.stopRecord(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StopRecord")
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func stopRecordNotRecording() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.stopRecord(onSuccess: completion.onSuccess, onError: completion.onError)
        let request = try await connection.expectRequest(type: "StopRecord")
        connection.server.respond(to: request, errorCode: 501)
        #expect(await completion.getError() == "Not recording")
        connection.obs.stop()
    }

    @Test
    func getSourceScreenshot() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Data>()
        connection.obs.getSourceScreenshot(name: "Main",
                                           onSuccess: completion.onSuccess,
                                           onError: completion.onError)
        let request = try await connection.expectRequest(
            type: "GetSourceScreenshot",
            data: #"{"imageCompressionQuality":30,"imageFormat":"jpg","imageWidth":640,"sourceName":"Main"}"#
        )
        connection.server.respond(to: request, data: #"{"imageData":"data:image/jpg;base64,SlBFRw=="}"#)
        #expect(try await completion.get() == Data("JPEG".utf8))
        connection.obs.stop()
    }

    @Test
    func getSourceScreenshotBadBase64() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Data>()
        connection.obs.getSourceScreenshot(name: "Main",
                                           onSuccess: completion.onSuccess,
                                           onError: completion.onError)
        let request = try await connection.server.receiveRequest()
        connection.server.respond(to: request, data: #"{"imageData":"data:image/jpg;base64,!!!"}"#)
        #expect(await completion.getError() == "Base64 decode failed")
        connection.obs.stop()
    }

    @Test
    func setInputAudioSyncOffset() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.setInputAudioSyncOffset(name: "Mic",
                                               offsetInMs: -250,
                                               onSuccess: completion.onSuccess,
                                               onError: completion.onError)
        let request = try await connection.expectRequest(type: "SetInputAudioSyncOffset",
                                                         data: #"{"inputAudioSyncOffset":-250,"inputName":"Mic"}"#)
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func getInputAudioSyncOffset() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Int>()
        connection.obs.getInputAudioSyncOffset(name: "Mic",
                                               onSuccess: completion.onSuccess,
                                               onError: completion.onError)
        let request = try await connection.expectRequest(type: "GetInputAudioSyncOffset",
                                                         data: #"{"inputName":"Mic"}"#)
        connection.server.respond(to: request, data: #"{"inputAudioSyncOffset":150}"#)
        #expect(try await completion.get() == 150)
        connection.obs.stop()
    }

    @Test
    func setInputMute() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<Void>()
        connection.obs.setInputMute(inputName: "Mic",
                                    muted: true,
                                    onSuccess: completion.onSuccess,
                                    onError: completion.onError)
        let request = try await connection.expectRequest(type: "SetInputMute",
                                                         data: #"{"inputMuted":true,"inputName":"Mic"}"#)
        connection.server.respond(to: request)
        try await completion.get()
        connection.obs.stop()
    }

    @Test
    func getInputMuteBatch() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<[Bool?]>()
        connection.obs.getInputMuteBatch(inputNames: ["Mic", "Missing", "Desktop"],
                                         onSuccess: completion.onSuccess,
                                         onError: completion.onError)
        let batch = try await connection.server.receiveRequestBatch()
        #expect(batch.id == "4")
        #expect(batch.requests.map(\.type) == ["GetInputMute", "GetInputMute", "GetInputMute"])
        #expect(batch.requests.map(\.id) == ["1", "2", "3"])
        #expect(batch.requests.map(\.data) == [
            #"{"inputName":"Mic"}"#,
            #"{"inputName":"Missing"}"#,
            #"{"inputName":"Desktop"}"#,
        ])
        connection.server.respond(to: batch, results: [
            .success(data: #"{"inputMuted":true}"#),
            .failure(code: 600, comment: "No source was found by the name of `Missing`."),
            .success(data: #"{"inputMuted":false}"#),
        ])
        #expect(try await completion.get() == [true, nil, false])
        connection.obs.stop()
    }

    @Test
    func getInputMuteBatchMalformedResult() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<[Bool?]>()
        connection.obs.getInputMuteBatch(inputNames: ["Mic"],
                                         onSuccess: completion.onSuccess,
                                         onError: completion.onError)
        let batch = try await connection.server.receiveRequestBatch()
        connection.server.respond(to: batch, results: [.success(data: #"{"muted":true}"#)])
        #expect(try await completion.get() == [nil])
        connection.obs.stop()
    }

    @Test
    func getMediaSourcesSettingsBatch() async throws {
        let connection = try await Connection.makeConnected()
        let completion = Completion<[(String, Bool)?]>()
        connection.obs.getMediaSourcesSettingsBatch(
            inputNames: ["Remote", "Local", "Missing"],
            onSuccess: { settings in
                completion.onSuccess(settings.map { $0.map { ($0.input, $0.isLocalFile) } })
            },
            onError: completion.onError
        )
        let batch = try await connection.server.receiveRequestBatch()
        #expect(batch.requests.map(\.type) == ["GetInputSettings", "GetInputSettings", "GetInputSettings"])
        #expect(batch.requests.map(\.data) == [
            #"{"inputName":"Remote"}"#,
            #"{"inputName":"Local"}"#,
            #"{"inputName":"Missing"}"#,
        ])
        connection.server.respond(to: batch, results: [
            .success(data: """
            {"inputKind":"ffmpeg_source","inputSettings":{"input":"srt://example.com:9000","is_local_file":false}}
            """),
            .success(data: """
            {"inputKind":"ffmpeg_source","inputSettings":{"input":"","local_file":"/tmp/a.mp4","is_local_file":true}}
            """),
            .failure(code: 600),
        ])
        let settings = try await completion.get()
        #expect(settings.count == 3)
        #expect(settings[0]?.0 == "srt://example.com:9000")
        #expect(settings[0]?.1 == false)
        #expect(settings[1]?.0 == "")
        #expect(settings[1]?.1 == true)
        #expect(settings[2] == nil)
        connection.obs.stop()
    }

    @Test
    func audioVolumeSubscription() async throws {
        let connection = try await Connection.makeConnected()
        connection.obs.startAudioVolume()
        #expect(try await connection.server.receiveReidentify() == 0x107FF)
        connection.obs.stopAudioVolume()
        #expect(try await connection.server.receiveReidentify() == 0x7FF)
        connection.obs.stop()
    }

    @Test
    func sceneChangedEvent() async throws {
        let connection = try await Connection.makeConnected()
        connection.server.sendEvent(type: "CurrentProgramSceneChanged",
                                    intent: 4,
                                    data: #"{"sceneName":"Camera","sceneUuid":"a"}"#)
        #expect(await connection.delegate.sceneChanges.get() == "Camera")
        connection.obs.stop()
    }

    @Test
    func streamStateChangedEvents() async throws {
        let connection = try await Connection.makeConnected()
        for (outputActive, outputState, expected) in [
            (false, "OBS_WEBSOCKET_OUTPUT_STARTING", ObsOutputState.starting),
            (true, "OBS_WEBSOCKET_OUTPUT_STARTED", .started),
            (true, "OBS_WEBSOCKET_OUTPUT_RECONNECTING", .stopped),
            (true, "OBS_WEBSOCKET_OUTPUT_RECONNECTED", .stopped),
            (true, "OBS_WEBSOCKET_OUTPUT_STOPPING", .stopping),
            (false, "OBS_WEBSOCKET_OUTPUT_STOPPED", .stopped),
        ] {
            connection.server.sendEvent(type: "StreamStateChanged",
                                        intent: 64,
                                        data: #"{"outputActive":\#(outputActive),"outputState":"\#(outputState)"}"#)
            let (active, state) = await connection.delegate.streamStatuses.get()
            #expect(active == outputActive)
            #expect(state == expected)
        }
        connection.obs.stop()
    }

    @Test
    func recordStateChangedEvents() async throws {
        let connection = try await Connection.makeConnected()
        for (outputActive, outputState, expected) in [
            (false, "OBS_WEBSOCKET_OUTPUT_STARTING", ObsOutputState.starting),
            (true, "OBS_WEBSOCKET_OUTPUT_STARTED", .started),
            (true, "OBS_WEBSOCKET_OUTPUT_PAUSED", .started),
            (true, "OBS_WEBSOCKET_OUTPUT_RESUMED", .started),
            (true, "OBS_WEBSOCKET_OUTPUT_STOPPING", .stopping),
            (false, "OBS_WEBSOCKET_OUTPUT_STOPPED", .stopped),
        ] {
            connection.server.sendEvent(
                type: "RecordStateChanged",
                intent: 64,
                data: #"{"outputActive":\#(outputActive),"outputState":"\#(outputState)","outputPath":null}"#
            )
            let (active, state) = await connection.delegate.recordStatuses.get()
            #expect(active == outputActive)
            #expect(state == expected)
        }
        connection.obs.stop()
    }

    @Test
    func inputMuteStateChangedEvent() async throws {
        let connection = try await Connection.makeConnected()
        connection.server.sendEvent(type: "InputMuteStateChanged",
                                    intent: 8,
                                    data: #"{"inputName":"Mic","inputUuid":"a","inputMuted":true}"#)
        let (inputName, muted) = await connection.delegate.muteChanges.get()
        #expect(inputName == "Mic")
        #expect(muted)
        connection.obs.stop()
    }

    @Test
    func inputVolumeMetersEvent() async throws {
        let connection = try await Connection.makeConnected()
        connection.server.sendEvent(type: "InputVolumeMeters", intent: 65536, data: """
        {"inputs":[\
        {"inputName":"Mic","inputUuid":"a","inputLevelsMul":[[1.0,1.0,1.0],[0.1,0.2,0.3]]},\
        {"inputName":"Silent","inputUuid":"b","inputLevelsMul":[]},\
        {"inputName":"Odd","inputUuid":"c","inputLevelsMul":[[],[0.5,0.5,0.5]]}]}
        """)
        let volumes = await connection.delegate.audioVolumes.get()
        #expect(volumes.count == 3)
        #expect(volumes[0].0 == "Mic")
        #expect(areEqual(volumes[0].1, [0, -20], epsilon: 0.001))
        #expect(volumes[1].0 == "Silent")
        #expect(volumes[1].1 == [])
        #expect(volumes[2].0 == "Odd")
        #expect(areEqual(volumes[2].1, [-6.0206], epsilon: 0.001))
        connection.obs.stop()
    }

    @Test
    func ignoresUnexpectedMessages() async throws {
        let connection = try await Connection.makeConnected()
        connection.server.send(text: "not json")
        connection.server.send(text: "[1, 2, 3]")
        connection.server.send(text: #"{"op":"x","d":{}}"#)
        connection.server.send(text: #"{"op":6}"#)
        connection.server.send(op: 42, data: "{}")
        connection.server.send(op: 8, data: #"{"requestId":1,"requests":[]}"#)
        connection.server.sendEvent(type: "SceneCreated", intent: 4, data: #"{"sceneName":"New"}"#)
        connection.server.sendEvent(type: "CurrentProgramSceneChanged", intent: 4, data: #"{"name":"Bad"}"#)
        connection.server.sendEvent(type: "CurrentProgramSceneChanged", intent: 4)
        connection.server.sendEvent(type: "StreamStateChanged", intent: 64, data: "{}")
        connection.server.sendEvent(type: "InputVolumeMeters", intent: 65536, data: #"{"inputs":{}}"#)
        connection.server.respond(to: ObsMockRequest(type: "GetSceneList", id: "99", data: nil), data: "{}")
        connection.server.respond(to: ObsMockRequestBatch(id: "99", requests: []), results: [])
        connection.server.sendEvent(
            type: "CurrentProgramSceneChanged",
            intent: 4,
            data: #"{"sceneName":"Good"}"#
        )
        #expect(await connection.delegate.sceneChanges.get() == "Good")
        #expect(connection.obs.isConnected())
        connection.obs.stop()
    }
}
