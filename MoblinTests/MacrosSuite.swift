import Foundation
@testable import Moblin
import Testing

struct MacrosSuite {
    @Test
    func numbersAreComparedNumerically() {
        #expect(SettingsMacrosActionIfComparison.greaterThan.evaluate(value: "9", otherValue: "10") == false)
        #expect(SettingsMacrosActionIfComparison.lessThan.evaluate(value: "9", otherValue: "10"))
        #expect(SettingsMacrosActionIfComparison.equal.evaluate(value: "10.0", otherValue: "10"))
        #expect(SettingsMacrosActionIfComparison.greaterEqual.evaluate(value: "10", otherValue: "10"))
        #expect(SettingsMacrosActionIfComparison.notEqual.evaluate(value: "-1", otherValue: "1"))
    }

    @Test
    func unitsAfterTheNumberAreIgnored() {
        #expect(SettingsMacrosActionIfComparison.greaterThan.evaluate(value: "35 km/h", otherValue: "30"))
        #expect(SettingsMacrosActionIfComparison.lessEqual.evaluate(value: "-5 m", otherValue: "0"))
        #expect(SettingsMacrosActionIfComparison.greaterThan.evaluate(value: " 45%", otherValue: "10"))
    }

    @Test
    func textIsComparedCaseInsensitively() {
        #expect(SettingsMacrosActionIfComparison.equal.evaluate(value: "Yes", otherValue: "yes"))
        #expect(SettingsMacrosActionIfComparison.lessThan.evaluate(value: "apple", otherValue: "Banana"))
        #expect(SettingsMacrosActionIfComparison.contains.evaluate(value: "Heavy rain", otherValue: "RAIN"))
        #expect(SettingsMacrosActionIfComparison.contains
            .evaluate(value: "Sunny", otherValue: "rain") == false)
    }

    @Test
    func ifActionSurvivesEncodeAndDecode() throws {
        let action = SettingsMacrosAction()
        action.function = .ifCondition
        action.ifValue = "{speed}"
        action.ifComparison = .greaterEqual
        action.ifOtherValue = "30"
        action.ifRunCount = 3
        let decoded = try JSONDecoder().decode(SettingsMacrosAction.self,
                                               from: JSONEncoder().encode(action))
        #expect(decoded.function == .ifCondition)
        #expect(decoded.ifValue == "{speed}")
        #expect(decoded.ifComparison == .greaterEqual)
        #expect(decoded.ifOtherValue == "30")
        #expect(decoded.ifRunCount == 3)
    }

    @Test
    func ifActionDefaultsWhenMissingFromSettings() throws {
        let action = try JSONDecoder().decode(SettingsMacrosAction.self, from: Data("{}".utf8))
        #expect(action.ifValue == "")
        #expect(action.ifComparison == .equal)
        #expect(action.ifOtherValue == "")
        #expect(action.ifRunCount == 1)
    }
}
