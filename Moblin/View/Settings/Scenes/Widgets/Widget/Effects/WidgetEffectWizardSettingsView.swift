import SwiftUI

struct WidgetEffectWizardSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var effect: SettingsVideoEffect
    @Binding var presentingCreateWizard: Bool

    private func create() {
        presentingCreateWizard = false
        widget.effects.append(effect)
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Form {
            Section {
                Picker("Type", selection: $effect.type) {
                    ForEach(SettingsVideoEffectType.allCases, id: \.self) {
                        Text($0.toString())
                            .tag($0)
                    }
                }
            }
            Section {
                TextButtonView("Create") {
                    create()
                }
            }
        }
        .navigationTitle("Create effect wizard")
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
