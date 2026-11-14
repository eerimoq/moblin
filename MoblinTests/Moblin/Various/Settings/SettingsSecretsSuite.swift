import Foundation
@testable import Moblin
import Testing

private func copied<T: Codable>(_ value: T) -> T {
    value.deepCopy()!
}

private func encoded(_ value: some Encodable) -> String {
    try! String(bytes: JSONEncoder().encode(value), encoding: .utf8)!
}

private func destination(_ name: String, _ url: String) -> SettingsStreamMultiStreamingDestination {
    let destination = SettingsStreamMultiStreamingDestination()
    destination.name = name
    destination.url = url
    return destination
}

private func makePhoneStream() -> SettingsStream {
    let stream = SettingsStream(name: "Main")
    stream.url = "rtmps://live.example.com/app/stream-url-secret"
    stream.obsWebSocketUrl = "ws://obs.example.com:4455/obs-url-secret"
    stream.obsWebSocketPassword = "obs-password-secret"
    stream.realtimeIrlBaseUrl = "https://rtirl.example.com/rtirl-url-secret"
    stream.realtimeIrlPushKey = "rtirl-push-key-secret"
    stream.discordSnapshotWebhook = "https://discord.com/api/webhooks/1/snapshot-webhook-secret"
    stream.discordChatBotSnapshotWebhook = "https://discord.com/api/webhooks/2/chat-bot-webhook-secret"
    stream.goLiveNotificationDiscordWebhookUrl = "https://discord.com/api/webhooks/3/go-live-webhook-secret"
    stream.whip.headers = [
        SettingsHttpHeader(name: "Authorization", value: "Bearer whip-token-secret"),
        SettingsHttpHeader(name: "X-Custom", value: "whip-custom-secret"),
    ]
    stream.previewStream.url = "whips://preview.example.com/whip/preview-url-secret"
    stream.multiStreaming.destinations = [
        destination("First", "rtmp://first.example.com/live/first-destination-secret"),
        destination("Second", "rtmps://second.example.com/live/second-destination-secret"),
    ]
    stream.twitchAccessToken = "twitch-token-secret"
    stream.kickAccessToken = "kick-token-secret"
    return stream
}

private func makePhoneWidget() -> SettingsWidget {
    let widget = SettingsWidget(name: "Alerts")
    widget.type = .alerts
    widget.alerts.ai.baseUrl = "https://ai.example.com/ai-url-secret"
    widget.alerts.ai.apiKey = "ai-api-key-secret"
    widget.alerts.ttsMonster.apiToken = "tts-monster-token-secret"
    return widget
}

private func headers(_ stream: SettingsStream) -> String {
    stream.whip.headers.map { "\($0.name): \($0.value)" }.joined(separator: ", ")
}

private func destinationUrls(_ stream: SettingsStream) -> String {
    stream.multiStreaming.destinations.map(\.url).joined(separator: ", ")
}

private let streamSecrets = [
    "stream-url-secret",
    "obs-url-secret",
    "obs-password-secret",
    "rtirl-url-secret",
    "rtirl-push-key-secret",
    "snapshot-webhook-secret",
    "chat-bot-webhook-secret",
    "go-live-webhook-secret",
    "whip-token-secret",
    "whip-custom-secret",
    "preview-url-secret",
    "first-destination-secret",
    "second-destination-secret",
    "twitch-token-secret",
    "kick-token-secret",
]

private let widgetSecrets = [
    "ai-url-secret",
    "ai-api-key-secret",
    "tts-monster-token-secret",
]

struct SettingsSecretsSuite {
    struct StreamCase: CustomTestStringConvertible {
        let testDescription: String
        let value: @Sendable (SettingsStream) -> String
        let expected: String

        init(
            _ description: String,
            _ expected: String,
            value: @escaping @Sendable (SettingsStream) -> String
        ) {
            testDescription = description
            self.expected = expected
            self.value = value
        }
    }

    struct WidgetCase: CustomTestStringConvertible {
        let testDescription: String
        let value: @Sendable (SettingsWidget) -> String
        let expected: String

        init(
            _ description: String,
            _ expected: String,
            value: @escaping @Sendable (SettingsWidget) -> String
        ) {
            testDescription = description
            self.expected = expected
            self.value = value
        }
    }

    @Test(arguments: streamSecrets)
    func removedStreamSecretsAreNotEncoded(secret: String) {
        let stream = copied(makePhoneStream())
        stream.twitchAccessToken = "twitch-token-secret"
        stream.kickAccessToken = "kick-token-secret"
        stream.removeSecrets()
        #expect(!encoded(stream).contains(secret))
    }

    @Test
    func removedTokensAreNotEncoded() {
        let stream = copied(makePhoneStream())
        stream.twitchAccessToken = "twitch-token-secret"
        stream.kickAccessToken = "kick-token-secret"
        stream.removeAccessTokens()
        let json = encoded(stream)
        #expect(!json.contains("twitch-token-secret") && !json.contains("kick-token-secret"))
        #expect(json.contains("stream-url-secret"))
    }

    @Test(arguments: [
        StreamCase("URL", "rtmps://") { $0.url },
        StreamCase("Preview stream URL", "whips://") { $0.previewStream.url },
        StreamCase("Destination URLs", "rtmp://, rtmps://") { destinationUrls($0) },
        StreamCase("WHIP headers", "") { headers($0) },
        StreamCase("OBS URL", "") { $0.obsWebSocketUrl },
        StreamCase("OBS password", "") { $0.obsWebSocketPassword },
        StreamCase("RealtimeIRL base URL", "") { $0.realtimeIrlBaseUrl },
        StreamCase("Twitch access token", "") { $0.twitchAccessToken },
        StreamCase("Kick access token", "") { $0.kickAccessToken },
    ])
    func removedStreamSecretsKeepSchemes(testCase: StreamCase) {
        let stream = makePhoneStream()
        stream.removeSecrets()
        #expect(testCase.value(stream) == testCase.expected)
    }

    @Test(arguments: [
        StreamCase("URL", "rtmps://live.example.com/app/stream-url-secret") { $0.url },
        StreamCase("OBS URL", "ws://obs.example.com:4455/obs-url-secret") { $0.obsWebSocketUrl },
        StreamCase("OBS password", "obs-password-secret") { $0.obsWebSocketPassword },
        StreamCase("RealtimeIRL base URL", "https://rtirl.example.com/rtirl-url-secret") {
            $0.realtimeIrlBaseUrl
        },
        StreamCase("RealtimeIRL push key", "rtirl-push-key-secret") { $0.realtimeIrlPushKey },
        StreamCase("Discord snapshot webhook", "https://discord.com/api/webhooks/1/snapshot-webhook-secret") {
            $0.discordSnapshotWebhook
        },
        StreamCase("Discord chat bot webhook", "https://discord.com/api/webhooks/2/chat-bot-webhook-secret") {
            $0.discordChatBotSnapshotWebhook
        },
        StreamCase("Go live webhook", "https://discord.com/api/webhooks/3/go-live-webhook-secret") {
            $0.goLiveNotificationDiscordWebhookUrl
        },
        StreamCase("WHIP headers", "Authorization: Bearer whip-token-secret, X-Custom: whip-custom-secret") {
            headers($0)
        },
        StreamCase("Preview stream URL", "whips://preview.example.com/whip/preview-url-secret") {
            $0.previewStream.url
        },
        StreamCase("Destination URLs matched by name when added or removed",
                   "rtmps://second.example.com/live/second-destination-secret, "
                       + "rtmp://first.example.com/live/first-destination-secret, "
                       + "rtmp://my_public_ip:1935/live/foobar") { destinationUrls($0) },
        StreamCase("Twitch access token", "twitch-token-secret") { $0.twitchAccessToken },
        StreamCase("Kick access token", "kick-token-secret") { $0.kickAccessToken },
    ])
    func keptStreamSecretsAreThePhones(testCase: StreamCase) {
        let phone = makePhoneStream()
        let request = copied(phone)
        request.removeSecrets()
        request.multiStreaming.destinations = [
            destination("Second", "rtmps://"),
            destination("First", "rtmp://"),
            destination("Third", "rtmp://"),
        ]
        request.keepSecrets(from: phone)
        #expect(testCase.value(request) == testCase.expected)
    }

    @Test
    func renamedDestinationsKeepTheirUrls() {
        let phone = makePhoneStream()
        let request = copied(phone)
        request.removeSecrets()
        request.multiStreaming.destinations[0].name = "Renamed"
        request.keepSecrets(from: phone)
        #expect(destinationUrls(request) == "rtmp://first.example.com/live/first-destination-secret, "
            + "rtmps://second.example.com/live/second-destination-secret")
    }

    @Test(arguments: [
        StreamCase("URL", "srt://my_public_ip:4000") { $0.url },
        StreamCase("OBS URL", "") { $0.obsWebSocketUrl },
        StreamCase("OBS password", "") { $0.obsWebSocketPassword },
        StreamCase("RealtimeIRL base URL", "https://rtirl.com/api") { $0.realtimeIrlBaseUrl },
        StreamCase("RealtimeIRL push key", "") { $0.realtimeIrlPushKey },
        StreamCase("Discord snapshot webhook", "") { $0.discordSnapshotWebhook },
        StreamCase("Discord chat bot webhook", "") { $0.discordChatBotSnapshotWebhook },
        StreamCase("Go live webhook", "") { $0.goLiveNotificationDiscordWebhookUrl },
        StreamCase("WHIP headers", "") { headers($0) },
        StreamCase("Preview stream URL", "") { $0.previewStream.url },
        StreamCase(
            "Destination URLs",
            "rtmp://my_public_ip:1935/live/foobar, rtmp://my_public_ip:1935/live/foobar"
        ) {
            destinationUrls($0)
        },
        StreamCase("Twitch access token", "") { $0.twitchAccessToken },
        StreamCase("Kick access token", "") { $0.kickAccessToken },
    ])
    func newStreamSecretsAreDefaults(testCase: StreamCase) {
        let stream = makePhoneStream()
        stream.keepSecrets(from: SettingsStream(name: ""))
        #expect(testCase.value(stream) == testCase.expected)
    }

    @Test(arguments: widgetSecrets)
    func removedWidgetSecretsAreNotEncoded(secret: String) {
        let widget = copied(makePhoneWidget())
        widget.removeSecrets()
        #expect(!encoded(widget).contains(secret))
    }

    @Test(arguments: [
        WidgetCase("AI base URL", "https://ai.example.com/ai-url-secret") { $0.alerts.ai.baseUrl },
        WidgetCase("AI API key", "ai-api-key-secret") { $0.alerts.ai.apiKey },
        WidgetCase("TTS.Monster token", "tts-monster-token-secret") { $0.alerts.ttsMonster.apiToken },
    ])
    func keptWidgetSecretsAreThePhones(testCase: WidgetCase) {
        let phone = makePhoneWidget()
        let request = copied(phone)
        request.removeSecrets()
        request.keepSecrets(from: phone)
        #expect(testCase.value(request) == testCase.expected)
    }

    @Test(arguments: [
        WidgetCase("AI base URL", "https://generativelanguage.googleapis.com/v1beta/openai") {
            $0.alerts.ai.baseUrl
        },
        WidgetCase("AI API key", "") { $0.alerts.ai.apiKey },
        WidgetCase("TTS.Monster token", "") { $0.alerts.ttsMonster.apiToken },
    ])
    func newWidgetSecretsAreDefaults(testCase: WidgetCase) {
        let widget = makePhoneWidget()
        widget.keepSecrets(from: SettingsWidget(name: ""))
        #expect(testCase.value(widget) == testCase.expected)
    }
}
