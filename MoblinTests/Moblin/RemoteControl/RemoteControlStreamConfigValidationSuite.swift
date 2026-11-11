import Foundation
@testable import Moblin
import Testing

private func modified(_ stream: SettingsStream, _ edit: (SettingsStream) -> Void = { _ in
}) -> SettingsStream {
    let stream = try! JSONDecoder().decode(SettingsStream.self, from: JSONEncoder().encode(stream))
    edit(stream)
    return stream
}

private func destination(_ name: String,
                         _ url: String = defaultRtmpStreamUrl) -> SettingsStreamMultiStreamingDestination
{
    let destination = SettingsStreamMultiStreamingDestination()
    destination.name = name
    destination.url = url
    return destination
}

private let idle = RemoteControlStreamState()
private let live = RemoteControlStreamState(isLive: true)
private let recording = RemoteControlStreamState(isRecording: true)

struct RemoteControlStreamConfigValidationSuite {
    final class Fixture {
        let main = SettingsStream(name: "Main")
        let other = SettingsStream(name: "Other")
        let streams: [SettingsStream]

        init() {
            main.enabled = true
            main.url = "srtla://example.com:5000"
            main.multiStreaming.destinations = [destination("First"), destination("Second")]
            main.whip.headers = [SettingsHttpHeader(name: "Authorization", value: "Bearer secret")]
            main.obsBrbScene = "BRB"
            let relay = SettingsStreamSrtConnectionPriority(name: "Relay")
            relay.relayId = UUID()
            main.srt.connectionPriorities.priorities.append(relay)
            streams = [main, other]
        }

        func stream(_ name: String) -> SettingsStream {
            streams.first { $0.name == name }!
        }
    }

    struct StreamCase: CustomTestStringConvertible {
        let testDescription: String
        let stream: String
        let state: RemoteControlStreamState
        let edit: @Sendable (SettingsStream) -> Void

        init(_ description: String,
             _ stream: String = "Main",
             _ state: RemoteControlStreamState = .init(),
             edit: @escaping @Sendable (SettingsStream) -> Void)
        {
            testDescription = description
            self.stream = stream
            self.state = state
            self.edit = edit
        }
    }

    @Test(arguments: [idle, live, recording, RemoteControlStreamState(isLive: true, isRecording: true)])
    func echoIsAccepted(state: RemoteControlStreamState) {
        let fixture = Fixture()
        #expect(isValidRemoteControlStreamUpdate(stream: fixture.main,
                                                 new: modified(fixture.main),
                                                 streams: fixture.streams,
                                                 state: state,
                                                 creating: false))
    }

    @Test(arguments: [
        StreamCase("Empty name") { $0.name = "" },
        StreamCase("Name of other stream") { $0.name = "Other" },
        StreamCase("Malformed URL") { $0.url = "no url" },
        StreamCase("RTMP URL without host") { $0.url = "rtmp:///live/key" },
        StreamCase("URL with unsupported scheme") { $0.url = "ftp://example.com" },
        StreamCase("URL while live", "Main", live) { $0.url = "srt://example.com:4000" },
        StreamCase("URL of other stream while live", "Other", live) { $0.url = "srt://example.com:4000" },
        StreamCase("URL of other stream while recording", "Other", recording) {
            $0.url = "srt://example.com:4000"
        },
        StreamCase("Portrait while recording", "Main", recording) { $0.portrait = true },
        StreamCase("Resolution while live", "Main", live) { $0.resolution = .r1280x720 },
        StreamCase("Resolution while recording", "Main", recording) { $0.resolution = .r1280x720 },
        StreamCase("FPS while recording", "Main", recording) { $0.fps = 60 },
        StreamCase("FPS not in list") { $0.fps = 24 },
        StreamCase("Codec while live", "Main", live) { $0.codec = .h264avc },
        StreamCase("Profile while live", "Main", live) { $0.h264Profile = .high },
        StreamCase("Rate control while live", "Main", live) { $0.rateControl = .cbr },
        StreamCase("Bitrate too low") { $0.bitrate = 10000 },
        StreamCase("Key frame interval while live", "Main", live) { $0.maxKeyFrameInterval = 1 },
        StreamCase("Key frame interval too big") { $0.maxKeyFrameInterval = 11 },
        StreamCase("B-frames while live", "Main", live) { $0.bFrames = true },
        StreamCase("Color range while recording", "Main", recording) { $0.colorRange = .limited },
        StreamCase("Adaptive resolution while live", "Main", live) { $0.adaptiveEncoderResolution = true },
        StreamCase("Adaptive resolution threshold too big") { $0.adaptiveEncoderResolutionThreashold = 4 },
        StreamCase("Timecodes with RTMP") {
            $0.url = "rtmp://example.com/live/key"
            $0.timecodesEnabled = true
        },
        StreamCase("Timecodes with H.264") {
            $0.codec = .h264avc
            $0.timecodesEnabled = true
        },
        StreamCase("Timecodes while live", "Main", live) { $0.timecodesEnabled = true },
        StreamCase("NTP pool address with H.264") {
            $0.codec = .h264avc
            $0.ntpPoolAddress = "pool.ntp.org"
        },
        StreamCase("Audio codec while live", "Main", live) { $0.audioCodec = .opus },
        StreamCase("Audio bitrate while live", "Main", live) { $0.audioBitrate = 64000 },
        StreamCase("Audio bitrate not multiple of 32 Kbps") { $0.audioBitrate = 100_000 },
        StreamCase("Audio bitrate too big") { $0.audioBitrate = 352_000 },
        StreamCase("Estimated viewer delay too big") { $0.estimatedViewerDelay = 16 },
        StreamCase("Estimated viewer delay negative") { $0.estimatedViewerDelay = -1 },
        StreamCase("SRT latency too big") { $0.srt.latency = 70000 },
        StreamCase("SRT latency while live", "Main", live) { $0.srt.latency = 2000 },
        StreamCase("SRT adaptive bitrate while live", "Main", live) { $0.srt.adaptiveBitrateEnabled = false },
        StreamCase("SRT overhead bandwidth too small") { $0.srt.overheadBandwidth = 4 },
        StreamCase("SRT overhead bandwidth too big") { $0.srt.overheadBandwidth = 101 },
        StreamCase("SRT big packets while live", "Main", live) { $0.srt.bigPackets = false },
        StreamCase("SRT DNS lookup strategy while live", "Main", live) { $0.srt.dnsLookupStrategy = .ipv4 },
        StreamCase("SRT implementation while live", "Main", live) { $0.srt.implementation = .official },
        StreamCase("Fast IRL packets in flight") {
            $0.srt.adaptiveBitrate.fastIrlSettings.packetsInFlight = 100
        },
        StreamCase("BELABOX minimum bitrate") { $0.srt.adaptiveBitrate.belaboxSettings.minimumBitrate = 10 },
        StreamCase("Custom IRL decrease factor") {
            $0.srt.adaptiveBitrate.customSettings.rttDiffHighDecreaseFactor = 0.5
        },
        StreamCase("Connection priority too big") { $0.srt.connectionPriorities.priorities[0].priority = 11 },
        StreamCase("Connection priority too small") { $0.srt.connectionPriorities.priorities[0].priority = 0
        },
        StreamCase("Deleted cellular connection priority") {
            $0.srt.connectionPriorities.priorities.remove(at: 0)
        },
        StreamCase("Deleted WiFi connection priority") { $0.srt.connectionPriorities.priorities.remove(at: 1)
        },
        StreamCase("Unknown connection priority") {
            $0.srt.connectionPriorities.priorities.append(.init(name: "New"))
        },
        StreamCase("Duplicated connection priority") {
            $0.srt.connectionPriorities.priorities.append($0.srt.connectionPriorities.priorities[0])
        },
        StreamCase("RTMP adaptive bitrate while live", "Main", live) { $0.rtmp.adaptiveBitrateEnabled = false
        },
        StreamCase("RIST bonding while live", "Main", live) { $0.rist.bonding = false },
        StreamCase("WHIP bearer token while live", "Main", live) { $0.whip.headers[0].value = "Bearer other"
        },
        StreamCase("WHIP header without bearer") { $0.whip.headers[0].value = "other" },
        StreamCase("WHIP other header") { $0.whip.headers.append(.init(name: "X-Foo", value: "bar")) },
        StreamCase("WHIP second authorization header") {
            $0.whip.headers.append(.init(name: "Authorization", value: "Bearer other"))
        },
        StreamCase("WHIP HTTP transport while live", "Main", live) { $0.whip.httpTransport = .remoteControl },
        StreamCase("Destination URL without host") {
            $0.multiStreaming.destinations[0].url = "rtmps:///live/key"
        },
        StreamCase("Destination SRT URL") { $0.multiStreaming.destinations[0].url = "srt://example.com:4000"
        },
        StreamCase("Destination URL while live", "Main", live) {
            $0.multiStreaming.destinations[0].url = "rtmp://example.com/live/key"
        },
        StreamCase("Destination enabled while recording", "Main", recording) {
            $0.multiStreaming.destinations[0].enabled = true
        },
        StreamCase("Destination added while live", "Main", live) {
            $0.multiStreaming.destinations.append(destination("Third"))
        },
        StreamCase("Destination deleted while recording", "Main", recording) {
            $0.multiStreaming.destinations.removeLast()
        },
        StreamCase("Destination empty name") { $0.multiStreaming.destinations[0].name = "" },
        StreamCase("Destination duplicated name") { $0.multiStreaming.destinations[0].name = "Second" },
        StreamCase("Added destination with invalid URL") {
            $0.multiStreaming.destinations.append(destination("Third", "no url"))
        },
        StreamCase("Recording override while recording", "Main", recording) {
            $0.recording.overrideStream = true
        },
        StreamCase("Recording resolution while live", "Main", live) { $0.recording.resolution = .r1280x720 },
        StreamCase("Recording video codec while recording", "Main", recording) {
            $0.recording.videoCodec = .h264avc
        },
        StreamCase("Recording video bitrate too big") { $0.recording.videoBitrate = 60_000_000 },
        StreamCase("Recording key frame interval too big") { $0.recording.maxKeyFrameInterval = 11 },
        StreamCase("Recording audio bitrate not multiple of 32 Kbps") { $0.recording.audioBitrate = 100_000 },
        StreamCase("Recording audio bitrate while recording", "Main", recording) {
            $0.recording.audioBitrate = 64000
        },
        StreamCase("Preview stream RTMP URL") { $0.previewStream.url = "rtmp://example.com/live/key" },
        StreamCase("Preview stream resolution") { $0.previewStream.resolution = .r1920x1080 },
        StreamCase("Preview stream bitrate") { $0.previewStream.bitrate = 3_000_000 },
        StreamCase("Replay post trigger delay") { $0.replay.postTriggerDelay = 6 },
        StreamCase("Replay x") { $0.replay.layout.x = 101 },
        StreamCase("Replay size") { $0.replay.layout.size = 0 },
        StreamCase("Replay stinger transition point") { $0.replay.inStinger.transitionPoint = 2 },
        StreamCase("OBS WebSocket URL") { $0.obsWebSocketUrl = "http://example.com" },
        StreamCase("OBS BRB scene when video source broken without BRB scene") {
            $0.obsBrbScene = ""
            $0.obsBrbSceneVideoSourceBroken = true
        },
        StreamCase("Open Streaming Platform URL") { $0.openStreamingPlatformUrl = "https://example.com" },
        StreamCase("RealtimeIRL base URL") { $0.realtimeIrlBaseUrl = "ws://example.com" },
        StreamCase("Twitch minimum watch streak") { $0.twitchChatAlerts.minimumWatchStreak = 2 },
    ])
    func updateIsRejected(testCase: StreamCase) {
        let fixture = Fixture()
        let stream = fixture.stream(testCase.stream)
        #expect(!isValidRemoteControlStreamUpdate(stream: stream,
                                                  new: modified(stream, testCase.edit),
                                                  streams: fixture.streams,
                                                  state: testCase.state,
                                                  creating: false))
    }

    @Test(arguments: [
        StreamCase("New name") { $0.name = "Renamed" },
        StreamCase("URL") { $0.url = "rtmp://example.com/live/key" },
        StreamCase("URL that needs cleaning") { $0.url = "SRT://example.com: 4000" },
        StreamCase("Portrait") { $0.portrait = true },
        StreamCase("Portrait of other stream while live", "Other", live) { $0.portrait = true },
        StreamCase("Resolution of other stream while live", "Other", live) { $0.resolution = .r1280x720 },
        StreamCase("Codec while recording", "Main", recording) { $0.codec = .h264avc },
        StreamCase("Bitrate while live", "Main", live) { $0.bitrate = 3_000_000 },
        StreamCase("Low light boost while live", "Main", live) { $0.lowLightBoost = true },
        StreamCase("Key frame interval while recording", "Main", recording) { $0.maxKeyFrameInterval = 0 },
        StreamCase("Timecodes") { $0.timecodesEnabled = true },
        StreamCase("Timecodes when changing to RIST and H.265") {
            $0.url = "rist://example.com:2030"
            $0.timecodesEnabled = true
        },
        StreamCase("Audio bitrate") { $0.audioBitrate = 320_000 },
        StreamCase("SRT latency while recording", "Main", recording) { $0.srt.latency = 2000 },
        StreamCase("Fast IRL settings while live", "Main", live) {
            $0.srt.adaptiveBitrate.algorithm = .fastIrl
            $0.srt.adaptiveBitrate.fastIrlSettings.packetsInFlight = 700
            $0.srt.adaptiveBitrate.fastIrlSettings.minimumBitrate = 2000
        },
        StreamCase("Custom IRL settings") {
            let custom = $0.srt.adaptiveBitrate.customSettings
            custom.pifDiffIncreaseFactor = 5
            custom.rttDiffHighDecreaseFactor = powf(0.5, 0.2)
            custom.rttDiffHighMinimumDecrease = 400
            custom.packetsInFlight = 5000
            custom.rttDiffHighAllowedSpike = 25
            custom.minimumBitrate = 50
        },
        StreamCase("Connection priorities while live", "Main", live) {
            $0.srt.connectionPriorities.enabled = true
            $0.srt.connectionPriorities.priorities[0].priority = 10
            $0.srt.connectionPriorities.priorities[1].enabled = false
        },
        StreamCase("Deleted relay connection priority") {
            $0.srt.connectionPriorities.priorities.remove(at: 2)
        },
        StreamCase("WHIP bearer token") { $0.whip.headers[0].value = "Bearer other" },
        StreamCase("WHIP bearer token while recording", "Main", recording) {
            $0.whip.headers[0].value = "Bearer other"
        },
        StreamCase("WHIP added bearer token", "Other") {
            $0.whip.headers = [.init(name: "Authorization", value: "Bearer token")]
        },
        StreamCase("Destination URL") {
            $0.multiStreaming.destinations[0].url = "rtmps://example.com/live/key"
        },
        StreamCase("Destination enabled") { $0.multiStreaming.destinations[0].enabled = true },
        StreamCase("Destination added") { $0.multiStreaming.destinations.append(destination("Third")) },
        StreamCase("Destination deleted") { $0.multiStreaming.destinations.removeFirst() },
        StreamCase("Destination renamed while live", "Main", live) {
            $0.multiStreaming.destinations[0].name = "Renamed"
        },
        StreamCase("Recording video codec while live", "Main", live) { $0.recording.videoCodec = .h264avc },
        StreamCase("Recording audio bitrate auto") { $0.recording.audioBitrate = 0 },
        StreamCase("Recording video bitrate") { $0.recording.videoBitrate = 50_000_000 },
        StreamCase("Clean recordings while recording", "Main", recording) {
            $0.recording.cleanRecordings = true
        },
        StreamCase("Preview stream URL") { $0.previewStream.url = "whips://example.com/live" },
        StreamCase("Preview stream resolution and bitrate") {
            $0.previewStream.resolution = .r854x480
            $0.previewStream.bitrate = 2_000_000
        },
        StreamCase("Replay while live", "Main", live) {
            $0.replay.enabled = true
            $0.replay.layout.x = 100
            $0.replay.layout.size = 1
            $0.replay.postTriggerDelay = 5
            $0.replay.outStinger.transitionPoint = 1
        },
        StreamCase("Empty OBS WebSocket URL") { $0.obsWebSocketUrl = "" },
        StreamCase("OBS WebSocket URL") { $0.obsWebSocketUrl = "wss://example.com:4455" },
        StreamCase("OBS BRB scene when video source broken") { $0.obsBrbSceneVideoSourceBroken = true },
        StreamCase("Open Streaming Platform URL") { $0.openStreamingPlatformUrl = "ws://example.com:5443/ws"
        },
        StreamCase("RealtimeIRL base URL") { $0.realtimeIrlBaseUrl = "https://example.com/api" },
        StreamCase("Empty RealtimeIRL base URL") { $0.realtimeIrlBaseUrl = "" },
        StreamCase("Estimated viewer delay") { $0.estimatedViewerDelay = 15 },
        StreamCase("Platforms while live", "Main", live) {
            $0.twitchChannelName = "twitch"
            $0.kickChannelName = "kick"
            $0.youTubeVideoIds = "a, b"
            $0.twitchToastAlerts.minimumWatchStreak = 25
            $0.kickChatAlerts.minimumKicks = 100
        },
    ])
    func updateIsAccepted(testCase: StreamCase) {
        let fixture = Fixture()
        let stream = fixture.stream(testCase.stream)
        #expect(isValidRemoteControlStreamUpdate(stream: stream,
                                                 new: modified(stream, testCase.edit),
                                                 streams: fixture.streams,
                                                 state: testCase.state,
                                                 creating: false))
    }

    @Test(arguments: [
        StreamCase("URL while live", "Other", live) { $0.url = "rtmp://example.com/live/key" },
        StreamCase("Resolution while live", "Other", live) { $0.resolution = .r1280x720 },
        StreamCase("Destination", "Other", recording) {
            $0.multiStreaming.destinations = [destination("First", "rtmp://example.com/live/key")]
        },
    ])
    func createIsAccepted(testCase: StreamCase) {
        let fixture = Fixture()
        let new = modified(SettingsStream(name: "New"), testCase.edit)
        let stream = SettingsStream(name: new.name)
        stream.id = new.id
        stream.srt.connectionPriorities.priorities = new.srt.connectionPriorities.priorities
        #expect(isValidRemoteControlStreamUpdate(stream: stream,
                                                 new: new,
                                                 streams: fixture.streams,
                                                 state: testCase.state,
                                                 creating: true))
    }

    @Test(arguments: [
        StreamCase("Empty name") { $0.name = "" },
        StreamCase("Name of other stream") { $0.name = "Main" },
        StreamCase("Malformed URL") { $0.url = "no url" },
        StreamCase("FPS not in list") { $0.fps = 24 },
    ])
    func createIsRejected(testCase: StreamCase) {
        let fixture = Fixture()
        let new = modified(SettingsStream(name: "New"), testCase.edit)
        let stream = SettingsStream(name: new.name)
        stream.id = new.id
        stream.srt.connectionPriorities.priorities = new.srt.connectionPriorities.priorities
        #expect(!isValidRemoteControlStreamUpdate(stream: stream,
                                                  new: new,
                                                  streams: fixture.streams,
                                                  state: testCase.state,
                                                  creating: true))
    }
}
