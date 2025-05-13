import SwiftUI

struct QuickButtonAutoSceneSwitcherView: View {
    @EnvironmentObject var model: Model
    @State var switcherId: UUID?

    var body: some View {
        Form {
            Section {
                Picker("", selection: $switcherId) {
                    Text("-- Off --")
                        .tag(nil as UUID?)
                    ForEach(model.database.autoSceneSwitchers!.switchers) { autoSceneSwitcher in
                        Text(autoSceneSwitcher.name)
                            .tag(autoSceneSwitcher.id as UUID?)
                    }
                }
                .onChange(of: switcherId) {
                    model.setAutoSceneSwitcher(id: $0)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .navigationTitle("Auto scene switcher")
    }
}
