import SwiftUI

private struct AutoSceneSwitcherItemView: View {
    @ObservedObject var autoSceneSwitcher: SettingsAutoSceneSwitcher

    var body: some View {
        Text(autoSceneSwitcher.name)
            .tag(autoSceneSwitcher.id as UUID?)
    }
}

struct QuickButtonAutoSceneSwitcherView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var autoSceneSwitcher: AutoSceneSwitcherProvider
    @ObservedObject var autoSceneSwitchers: SettingsAutoSceneSwitchers

    var body: some View {
        Form {
            Section {
                Picker("", selection: $autoSceneSwitcher.currentSwitcherId) {
                    Text("-- Off --")
                        .tag(nil as UUID?)
                    ForEach(autoSceneSwitchers.switchers) {
                        AutoSceneSwitcherItemView(autoSceneSwitcher: $0)
                    }
                }
                .onChange(of: autoSceneSwitcher.currentSwitcherId) {
                    model.setAutoSceneSwitcher(id: $0)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            Section {
                NavigationLink {
                    Form {
                        AutoSwitchersSettingsView(autoSceneSwitchers: autoSceneSwitchers)
                    }
                } label: {
                    Text("Auto scene switchers")
                }
            } header: {
                Text("Shortcut")
            }
        }
        .navigationTitle("Auto scene switcher")
    }
}
