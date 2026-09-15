import Foundation
@testable import Moblin
import Testing

struct SettingsMacrosSuite {
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

    @Test
    func waitForEventMatchesOnlyItsEvent() {
        let action = makeWaitForEventAction(event: .twitchFollow)
        #expect(action.matches(event: MacroEvent(event: .twitchFollow)))
        #expect(!action.matches(event: MacroEvent(event: .twitchSubscription)))
    }

    @Test
    func waitForEventWithMinimumAmountMatchesAtOrAboveIt() {
        let action = makeWaitForEventAction(event: .twitchCheer)
        action.eventMinimumAmount = 100
        #expect(!action.matches(event: MacroEvent(event: .twitchCheer, amount: 99)))
        #expect(action.matches(event: MacroEvent(event: .twitchCheer, amount: 100)))
        #expect(action.matches(event: MacroEvent(event: .twitchCheer, amount: 500)))
    }

    @Test
    func waitForEventTextIgnoresCaseAndSurroundingWhitespace() {
        let action = makeWaitForEventAction(event: .twitchReward)
        action.eventText = " Hydrate "
        #expect(action.matches(event: MacroEvent(event: .twitchReward, text: "hydrate")))
        #expect(!action.matches(event: MacroEvent(event: .twitchReward, text: "Stretch")))
    }

    @Test
    func waitForEventWithEmptyTextMatchesAnyText() {
        let action = makeWaitForEventAction(event: .twitchReward)
        #expect(action.matches(event: MacroEvent(event: .twitchReward, text: "Hydrate")))
        #expect(action.matches(event: MacroEvent(event: .twitchReward)))
    }

    @Test
    func waitForSceneSwitchedMatchesSelectedOrAnyScene() {
        let sceneId = UUID()
        let action = makeWaitForEventAction(event: .switchScene)
        #expect(action.matches(event: MacroEvent(event: .switchScene, sceneId: sceneId)))
        action.eventSceneId = sceneId
        #expect(action.matches(event: MacroEvent(event: .switchScene, sceneId: sceneId)))
        #expect(!action.matches(event: MacroEvent(event: .switchScene, sceneId: UUID())))
    }

    @Test
    func waitForEventActionSurvivesEncodeAndDecode() throws {
        let sceneId = UUID()
        let action = makeWaitForEventAction(event: .kickKicks)
        action.eventMinimumAmount = 42
        action.eventText = "boom"
        action.eventSceneId = sceneId
        let decoded = try JSONDecoder().decode(SettingsMacrosAction.self,
                                               from: JSONEncoder().encode(action))
        #expect(decoded.function == .waitForEvent)
        #expect(decoded.event == .kickKicks)
        #expect(decoded.eventMinimumAmount == 42)
        #expect(decoded.eventText == "boom")
        #expect(decoded.eventSceneId == sceneId)
    }

    @Test
    func waitForEventActionDefaultsWhenMissingFromSettings() throws {
        let action = try JSONDecoder().decode(SettingsMacrosAction.self, from: Data("{}".utf8))
        #expect(action.event == .twitchFollow)
        #expect(action.eventMinimumAmount == 0)
        #expect(action.eventText == "")
        #expect(action.eventSceneId == nil)
    }

    @Test
    func runAtAppStartDefaultsToOffWhenMissingFromSettings() throws {
        let macro = try JSONDecoder().decode(SettingsMacrosMacro.self, from: Data("{}".utf8))
        #expect(!macro.runAtAppStart)
    }

    private func makeWaitForEventAction(event: SettingsMacrosEvent) -> SettingsMacrosAction {
        let action = SettingsMacrosAction()
        action.function = .waitForEvent
        action.event = event
        return action
    }
}
