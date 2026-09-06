import Foundation
@testable import Moblin
import Testing

struct MacrosSettingsViewSuite {
    @Test
    func actionsRunByIfShareItsLevel() {
        let actions = [makeAction(), makeIfAction(runCount: 2), makeAction(), makeAction(), makeAction()]
        let bars = macroActionIfBars(actions: actions)
        #expect(bars.map { $0.map(\.level) } == [[], [0], [0], [0], []])
        #expect(bars.map { $0.map(\.isFirst) } == [[], [true], [false], [false], []])
        #expect(bars.map { $0.map(\.isLast) } == [[], [false], [false], [true], []])
    }

    @Test
    func nestedIfsAreOneLevelApart() {
        let actions = [makeIfAction(runCount: 3), makeIfAction(runCount: 1), makeAction(), makeAction()]
        let bars = macroActionIfBars(actions: actions)
        #expect(bars.map { $0.map(\.level) } == [[0], [0, 1], [0, 1], [0]])
        #expect(bars.map { $0.map(\.isLast) } == [[false], [false, false], [false, true], [true]])
    }

    @Test
    func ifsRunningActionsOutsideTheOuterIfKeepTheirOwnLevel() {
        let actions = [makeIfAction(runCount: 1), makeIfAction(runCount: 2), makeAction(), makeAction()]
        let bars = macroActionIfBars(actions: actions)
        #expect(bars.map { $0.map(\.level) } == [[0], [0, 1], [1], [1]])
    }

    @Test
    func ifsAfterEachOtherAreSeparateBlocksOnTheSameLevel() {
        let actions = [makeIfAction(runCount: 1), makeAction(), makeIfAction(runCount: 1), makeAction()]
        let bars = macroActionIfBars(actions: actions)
        #expect(bars.map { $0.map(\.level) } == [[0], [0], [0], [0]])
        #expect(bars.map { $0.map(\.isFirst) } == [[true], [false], [true], [false]])
        #expect(bars.map { $0.map(\.isLast) } == [[false], [true], [false], [true]])
    }

    @Test
    func ifWithoutActionsToRunHasNoBar() {
        let actions = [makeIfAction(runCount: 0), makeAction()]
        #expect(macroActionIfBars(actions: actions).map { $0.map(\.level) } == [[], []])
    }

    @Test
    func ifRunningMoreActionsThanExistEndsAtTheLastAction() {
        let actions = [makeAction(), makeIfAction(runCount: 10), makeAction()]
        let bars = macroActionIfBars(actions: actions)
        #expect(bars.map { $0.map(\.level) } == [[], [0], [0]])
        #expect(bars.map { $0.map(\.isLast) } == [[], [false], [true]])
    }

    private func makeAction() -> SettingsMacrosAction {
        let action = SettingsMacrosAction()
        action.function = .snapshot
        return action
    }

    private func makeIfAction(runCount: Int) -> SettingsMacrosAction {
        let action = SettingsMacrosAction()
        action.function = .ifCondition
        action.ifRunCount = runCount
        return action
    }
}
