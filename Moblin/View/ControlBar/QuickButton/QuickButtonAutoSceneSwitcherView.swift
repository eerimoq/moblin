import SwiftUI

struct QuickButtonAutoSceneSwitcherView: View {
    @ObservedObject var autoSceneSwitcher: AutoSceneSwitcherProvider
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers

    var body: some View {
        Form {
            Section {
                AutoSwitchersSelectView(
                    autoSceneSwitcher: autoSceneSwitcher,
                    autoSceneSwitchers: autoSceneSwitchers
                )
                .pickerStyle(.inline)
                .labelsHidden()
            }
            ShortcutSectionView {
                AutoSwitchersSettingsView(autoSceneSwitchers: autoSceneSwitchers, showSelector: false)
            }
        }
        .navigationTitle("Auto scene switcher")
    }
}
