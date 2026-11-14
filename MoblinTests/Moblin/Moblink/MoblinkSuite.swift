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
}
