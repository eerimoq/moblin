import Foundation
@testable import Moblin
import Testing

struct MoblinkProtocolSuite {
    @Test
    func statusWithTemperatureRoundTrips() throws {
        let message = MoblinkMessageToStreamer.response(
            id: 1,
            result: .ok,
            data: .status(
                batteryPercentage: 100,
                thermalState: nil,
                temperatureCelsius: 38
            )
        )
        let json = try message.toJson()
        #expect(json.contains(#""temperatureCelsius":38"#))

        let decoded = try MoblinkMessageToStreamer.fromJson(data: json)
        guard case let .response(id, result, data) = decoded else {
            Issue.record("Not a response")
            return
        }
        #expect(id == 1)
        guard case .ok = result else {
            Issue.record("Result is not ok")
            return
        }
        guard let data,
              case let .status(batteryPercentage, thermalState, temperatureCelsius) = data
        else {
            Issue.record("Not a status response")
            return
        }
        #expect(batteryPercentage == 100)
        #expect(thermalState == nil)
        #expect(temperatureCelsius == 38)
    }

    @Test
    func legacyStatusWithoutTemperatureDecodes() throws {
        let json = #"{"response":{"data":{"status":{"batteryPercentage":100}},"id":1,"result":{"ok":{}}}}"#
        let decoded = try MoblinkMessageToStreamer.fromJson(data: json)
        guard case let .response(_, _, data) = decoded,
              let data,
              case let .status(batteryPercentage, thermalState, temperatureCelsius) = data
        else {
            Issue.record("Not a status response")
            return
        }
        #expect(batteryPercentage == 100)
        #expect(thermalState == nil)
        #expect(temperatureCelsius == nil)
    }
