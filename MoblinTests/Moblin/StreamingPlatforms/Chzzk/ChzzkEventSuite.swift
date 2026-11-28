import Foundation
@testable import Moblin
import Testing

struct ChzzkEventSuite {
    @Test(arguments: ["86400", #""86400""#])
    func tokenLifetime(seconds: String) throws {
        let json = """
        {"accessToken":"access","refreshToken":"refresh","expiresIn":\(seconds)}
        """
        let token = try JSONDecoder().decode(ChzzkTokenResponse.self, from: Data(json.utf8))
        #expect(token.expiresIn == 86400)
    }

    @Test
    func connectedSessionWithStringPayload() throws {
        let json = #"["SYSTEM","{\"type\":\"connected\",\"data\":{\"sessionKey\":\"test-session\"}}"]"#
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: Data(json.utf8))
        guard case let .system(system) = event else {
            Issue.record("Expected a system event")
            return
        }
        #expect(system.type == "connected")
        #expect(system.data.sessionKey == "test-session")
    }

    @Test
    func chatWithNestedRoleAndKoreanText() throws {
        let payload = """
        {
            "channelId":"host","senderChannelId":"viewer",
            "profile":{"nickname":"방송매니저","userRoleCode":"streaming_chat_manager"},
            "content":"어서 오세요 {:wave:}","emojis":{"wave":"https://example.com/wave.png"}
        }
        """
        let data = try JSONEncoder().encode(["CHAT", payload])
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: data)
        guard case let .chat(message) = event else {
            Issue.record("Expected a chat message")
            return
        }
        #expect(message.content == "어서 오세요 {:wave:}")
        #expect(message.profile.nickname == "방송매니저")
        #expect(message.userRoleCode == "streaming_chat_manager")
        #expect(message.emojis?["wave"] == "https://example.com/wave.png")
    }

    @Test(arguments: ["1000", #""1000""#])
    func anonymousDonation(amount: String) throws {
        let json = """
        ["DONATION", {"channelId":"host","donatorChannelId":"anonymous",
                      "donatorNickname":"","payAmount":\(amount)}]
        """
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: Data(json.utf8))
        guard case let .donation(donation) = event else {
            Issue.record("Expected a donation")
            return
        }
        #expect(donation.payAmount == "1000")
        #expect(donation.donatorChannelId == "anonymous")
        #expect(donation.donationText == nil)
        #expect(donation.moderationTarget == nil)
    }

    @Test(arguments: ["CHAT", "VIDEO", "UNKNOWN"])
    func donationType(kind: String) throws {
        let data = Data(#"["DONATION",{"channelId":"host","donationType":"\#(kind)","payAmount":1000}]"#.utf8)
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: data)
        guard case let .donation(donation) = event else {
            Issue.record("Expected donation")
            return
        }
        #expect(donation.donationType == kind)
    }

    @Test
    func subscriptionWithoutOptionalFields() throws {
        let data = Data(#"["SUBSCRIPTION",{"channelId":"host","subscriberNickname":"viewer"}]"#.utf8)
        let event = try JSONDecoder().decode(ChzzkEvent.self, from: data)
        guard case let .subscription(subscription) = event else {
            Issue.record("Expected subscription")
            return
        }
        #expect(subscription.month == nil)
        #expect(subscription.tierNo == nil)
        #expect(subscription.subscriberNickname == "viewer")
    }

    @MainActor
    @Test(arguments: [200, 403, 500])
    func searchCategories(status: Int) async throws {
        let api = ChzzkApi(clientId: "client", clientSecret: "secret") { request in
            let url = try #require(request.url)
            #expect(url.path == "/open/v1/categories/search")
            let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
            #expect(query?.first?.value == "A+B")
            #expect(request.value(forHTTPHeaderField: "Client-Secret") == "secret")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
            let body = """
            {"code":200,"content":{"data":[{"categoryId":"test","categoryType":"ETC","categoryValue":"Test"}]}}
            """
            let response = try #require(HTTPURLResponse(
                url: url,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            ))
            return (Data(body.utf8), response)
        }
        do {
            let categories = try await api.categories(query: "A+B")
            #expect(status == 200)
            #expect(categories.first?.categoryId == "test")
        } catch let ChzzkApiError.status(code) {
            #expect(status != 200 && code == status)
        }
    }

    @Test
    func partialLiveUpdates() {
        let category = ChzzkLiveCategory(categoryId: "talk", categoryType: "ETC", categoryValue: "Talk")
        #expect(ChzzkLiveUpdate.title("Testing").fields == ["defaultLiveTitle": "Testing"])
        #expect(ChzzkLiveUpdate.category(category).fields == ["categoryType": "ETC", "categoryId": "talk"])
    }

    @Test
    func identifiedDonorSupportsUserRestrictions() throws {
        let sender = String(repeating: "a", count: 32)
        let json = #"{"channelId":"host","donatorChannelId":"\#(sender)","payAmount":1000}"#
        let donation = try JSONDecoder().decode(ChzzkDonation.self, from: Data(json.utf8))
        let target = try #require(donation.moderationTarget)
        #expect(target.senderChannelId == sender)
        #expect(target.supports(.restrict))
        #expect(!target.supports(.temporaryRestrict))
        #expect(!target.supports(.hideMessage))
    }

    @Test
    func moderationIdentifiers() throws {
        let payload = """
        {"channelId":"host","senderChannelId":"viewer","chatChannelId":"room",
         "messageTime":1795410000123,"profile":{"nickname":"Viewer"},"content":"hello"}
        """
        let message = try JSONDecoder().decode(ChzzkChatMessage.self, from: Data(payload.utf8))
        #expect(message.moderationTarget.channelId == "host")
        #expect(message.moderationTarget.senderChannelId == "viewer")
        #expect(message.moderationTarget.chatChannelId == "room")
        #expect(message.moderationTarget.messageTime == 1_795_410_000_123)
        #expect(message.moderationTarget.messageId == "chzzk:host:room:viewer:1795410000123")
    }

    @Test(arguments: ["CLOSE", "CLOSED"])
    func offlineLiveStatus(status: String) throws {
        #expect(try ChzzkLiveStatus(status: status, concurrentUserCount: nil).platformStatus() == .offline)
    }

    @Test(arguments: [0, 12, 100_000])
    func directViewerCount(count: Int) throws {
        #expect(try ChzzkLiveStatus(status: "OPEN", concurrentUserCount: count).platformStatus()
            == .live(viewerCount: count))
    }

    @Test
    func missingViewerCountIsNotZero() {
        #expect(throws: (any Error).self) {
            try ChzzkLiveStatus(status: "OPEN", concurrentUserCount: nil).platformStatus()
        }
    }

    enum ViewerCase: String, CaseIterable, CustomTestStringConvertible {
        case zero, closed, offlineChannel, openChannel, wrongChannel, missingCount, missingContent,
             metadataFailure

        var testDescription: String {
            rawValue
        }
    }

    @MainActor
    @Test(arguments: ViewerCase.allCases)
    func viewerRequests(scenario: ViewerCase) async {
        let channel = String(repeating: "a", count: 32)
        let polling = "/polling/v2/channels/\(channel)/live-status"
        let metadata = "/service/v1/channels/\(channel)"
        var paths: [String] = []
        let status = try? await ChzzkApi.liveStatus(channelId: channel) { request in
            let url = try #require(request.url)
            paths.append(url.path)
            let json: String
            if url.path == polling {
                json = switch scenario {
                case .zero: #"{"code":200,"content":{"status":"OPEN","concurrentUserCount":0}}"#
                case .closed: #"{"code":200,"content":{"status":"CLOSE"}}"#
                case .missingCount: #"{"code":200,"content":{"status":"OPEN"}}"#
                case .missingContent: #"{"code":200}"#
                default: #"{"code":200,"content":null}"#
                }
            } else {
                #expect(url.path == metadata)
                if scenario == .metadataFailure {
                    throw URLError(.timedOut)
                }
                let id = scenario == .wrongChannel ? "other" : channel
                json = #"{"code":200,"content":{"channelId":"\#(id)","openLive":\#(scenario == .openChannel)}}"#
            }
            return try (Data(json.utf8), #require(HTTPURLResponse(url: url, statusCode: 200,
                                                                  httpVersion: nil, headerFields: nil)))
        }
        switch scenario {
        case .zero:
            #expect(paths == [polling])
            #expect(status == .live(viewerCount: 0))
        case .closed:
            #expect(paths == [polling])
            #expect(status == .offline)
        case .offlineChannel:
            #expect(paths == [polling, metadata])
            #expect(status == .offline)
        case .missingCount, .missingContent:
            #expect(paths == [polling])
            #expect(status == nil)
        case .openChannel, .wrongChannel, .metadataFailure:
            #expect(paths == [polling, metadata])
            #expect(status == nil)
        }
    }

    @Test
    func viewerHistoryExpiresAndRecovers() {
        var history = ChzzkViewerHistory()
        let start = ContinuousClock.now
        let live = PlatformStatus.live(viewerCount: 4)
        let initial = history.update(live, at: start)
        let held = history.update(nil, at: start.advanced(by: .seconds(119)))
        let expired = history.update(nil, at: start.advanced(by: .seconds(120)))
        let recovered = history.update(.live(viewerCount: 0), at: start.advanced(by: .seconds(150)))
        let ended = history.update(.offline, at: start.advanced(by: .seconds(180)))
        #expect(initial == live)
        #expect(held == live)
        #expect(expired == .unknown)
        #expect(recovered == .live(viewerCount: 0))
        #expect(ended == .offline)
    }

    enum TargetCase: String, CaseIterable, CustomTestStringConvertible {
        case anonymous, senderOnly, roomOnly, emptyRoom, complete

        var testDescription: String {
            rawValue
        }
    }

    @Test(arguments: TargetCase.allCases)
    func moderationActions(scenario: TargetCase) {
        let room: String? = switch scenario {
        case .senderOnly: nil
        case .emptyRoom: ""
        default: "room"
        }
        let target = ChzzkModerationTarget(channelId: "host",
                                           senderChannelId: scenario == .anonymous ? "" : "user",
                                           chatChannelId: room,
                                           messageTime: scenario == .roomOnly ? nil : 123)
        #expect(target.supports(.restrict) == (scenario != .anonymous))
        #expect(target.supports(.unrestrict) == (scenario != .anonymous))
        #expect(target.supports(.temporaryRestrict) == (scenario == .roomOnly || scenario == .complete))
        #expect(target.supports(.temporaryUnrestrict) == (scenario == .roomOnly || scenario == .complete))
        #expect(target.supports(.hideMessage) == (scenario == .complete))
    }

    @MainActor
    @Test(arguments: [200, 401, 403, 404, 429])
    func writeRetry(status: Int) async {
        var refresh: [Bool] = []
        var attempts: [String] = []
        var finalStatus = 200
        do {
            try await performChzzkWrite { force in
                refresh.append(force)
                return force ? "new" : "old"
            } write: { token in
                attempts.append(token)
                if status != 200 {
                    throw ChzzkApiError.status(status)
                }
            }
        } catch let ChzzkApiError.status(code) {
            finalStatus = code
        } catch {
            Issue.record("Unexpected error")
        }
        #expect(refresh == (status == 401 ? [false, true] : [false]))
        #expect(attempts == (status == 401 ? ["old", "new"] : ["old"]))
        #expect(finalStatus == status)
    }

    @Test
    func writePermissions() {
        let forbidden = ChzzkApiError.status(403)
        let chat = String(
            localized: "Check the CHZZK chat write permission and log in again.",
            bundle: Bundle(for: Model.self)
        )
        let restriction = String(
            localized: "Check the CHZZK restriction write permission and log in again.",
            bundle: Bundle(for: Model.self)
        )
        #expect(chzzkWriteErrorDetail(forbidden, action: nil) == chat)
        #expect(chzzkWriteErrorDetail(forbidden, action: .hideMessage) == chat)
        #expect(chzzkWriteErrorDetail(forbidden, action: .restrict) == restriction)
        #expect(chzzkWriteErrorDetail(forbidden, action: .temporaryUnrestrict) == restriction)
    }

    @MainActor
    @Test(arguments: ["chat", "donation", "subscription", "all", "neither"])
    func subscriptionPermissions(denied: String) async {
        var requests: [String] = []
        var stopped = false
        do {
            try await subscribeToChzzkEvents { event in
                requests.append(event)
                if denied == event || denied == "all" {
                    throw ChzzkApiError.status(403)
                }
            }
        } catch ChzzkSubscriptionError.permissionsDenied {
            stopped = true
        } catch {
            Issue.record("Unexpected error")
        }
        #expect(requests == ["chat", "donation", "subscription"])
        #expect(stopped == (denied == "all"))
    }
}
