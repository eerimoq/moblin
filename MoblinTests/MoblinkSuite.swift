@testable import Moblin
import Testing

struct MoblinkSuite {
    @Test
    func decodeStatusResponse() throws {
        let message = try MoblinkMessageToStreamer.fromJson(data: """
        {"response":{\
        "id":5,\
        \"data":{"status":{"thermalState":"white","batteryPercentage":30,"temperature": 39}},\
        "result":{"ok":{}}}}
        """)
        switch message {
        case let .response(id, result, data):
            #expect(id == 5)
            #expect(result == .ok)
            switch data {
            case let .status(batteryPercentage, thermalState):
                #expect(batteryPercentage == 30)
                #expect(thermalState == .white)
            default:
                Issue.record("Expected status")
            }
        default:
            Issue.record("Expected response")
        }
    }

    @Test
    func decodeIdentifyWithoutCapabilities() throws {
        let message = try MoblinkMessageToStreamer.fromJson(data: """
        {"identify":{"id":"D95E5BE5-42F0-4C35-8E49-F09F7B4EAD77","name":"Relay","authentication":"abc"}}
        """)
        switch message {
        case let .identify(id, name, authentication, capabilities):
            #expect(id == UUID(uuidString: "D95E5BE5-42F0-4C35-8E49-F09F7B4EAD77"))
            #expect(name == "Relay")
            #expect(authentication == "abc")
            #expect(capabilities == nil)
        default:
            Issue.record("Expected identify")
        }
    }

    @Test
    func decodeIdentifyWithWebProxyCapability() throws {
        let message = try MoblinkMessageToStreamer.fromJson(data: """
        {"identify":{\
        "id":"D95E5BE5-42F0-4C35-8E49-F09F7B4EAD77",\
        "name":"Relay",\
        "authentication":"abc",\
        "capabilities":["webProxy"]}}
        """)
        switch message {
        case let .identify(_, _, _, capabilities):
            #expect(capabilities == [.webProxy])
        default:
            Issue.record("Expected identify")
        }
    }

    @Test
    func encodeWebProxyOpenRequest() {
        let id = UUID(uuidString: "D95E5BE5-42F0-4C35-8E49-F09F7B4EAD77")!
        let message = MoblinkMessageToRelay.request(
            id: 7,
            data: .webProxyOpen(id: id, host: "example.com", port: 443)
        )
        let json = message.toJson() ?? ""

        #expect(json.contains("\"webProxyOpen\""))
        #expect(json.contains("\"example.com\""))
        #expect(json.contains("\"port\":443"))
    }

    @Test
    func decodeWebProxyData() throws {
        let message = try MoblinkMessageToStreamer.fromJson(data: """
        {"webProxyData":{"id":"D95E5BE5-42F0-4C35-8E49-F09F7B4EAD77","data":"AQID"}}
        """)
        switch message {
        case let .webProxyData(id, data):
            #expect(id == UUID(uuidString: "D95E5BE5-42F0-4C35-8E49-F09F7B4EAD77"))
            #expect(data == Data([1, 2, 3]))
        default:
            Issue.record("Expected web proxy data")
        }
    }
}
