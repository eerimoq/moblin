import SwiftUI

struct QuickButtonAutoSceneSwitcherView: View {
    @ObservedObject var autoSceneSwitcher: AutoSceneSwitcherProvider
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers

    var body: some View {
        Form {
            Section {
                AutoSwitchersSelectView(autoSceneSwitcher: autoSceneSwitcher, autoSceneSwitchers: autoSceneSwitchers)
                    .pickerStyle(.inline)
                    .labelsHidden()
            }
            Section {
                AutoSwitchersSettingsView(autoSceneSwitchers: autoSceneSwitchers, showSelector: false)
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("Auto scene switcher")
    }
}
