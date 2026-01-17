import SwiftUI

let wheelOfLuckOptionWeights = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 20, 40, 60, 80, 100]

private struct OptionView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck
    @ObservedObject var options: SettingsWidgetWheelOfLuckOption

    private func updateEffect() {
        model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: wheelOfLuck)
    }

    private func calcPercent() -> Int {
        return 100 * options.weight / wheelOfLuck.totalWeight
    }

    var body: some View {
        NavigationLink {
            Form {
                TextEditNavigationView(title: "Text", value: options.text) {
                    options.text = $0
                    updateEffect()
                }
                Picker("Weight", selection: $options.weight) {
                    ForEach(wheelOfLuckOptionWeights, id: \.self) {
                        Text(String($0))
                    }
                }
                .onChange(of: options.weight) { _ in
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
            }
            .navigationTitle("Option")
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(options.text)
                Spacer()
                Text("\(calcPercent())%")
            }
        }
    }
}

struct WheelOfLuckWidgetOptionsView: View {
    @Binding var value: String
    @FocusState private var editingText: Bool

    var body: some View {
        Section {
            MultiLineTextFieldView(value: $value)
                .focused($editingText)
        } header: {
            Text("Options")
        } footer: {
            if isPhone() {
                HStack {
                    Spacer()
                    Button("Done") {
                        editingText = false
                    }
                }
                .disabled(!editingText)
            }
        }
    }
}

struct WidgetWheelOfLuckSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var wheelOfLuck: SettingsWidgetWheelOfLuck

    private func updateEffect() {
        model.getWheelOfLuckEffect(id: widget.id)?.setSettings(settings: wheelOfLuck)
    }

    var body: some View {
        if wheelOfLuck.advanced {
            Section {
                ForEach(wheelOfLuck.options) {
                    OptionView(model: model, widget: widget, wheelOfLuck: wheelOfLuck, options: $0)
                }
                .onMove { froms, to in
                    wheelOfLuck.options.move(fromOffsets: froms, toOffset: to)
                    wheelOfLuck.updateText()
                    updateEffect()
                }
                .onDelete { offsets in
                    wheelOfLuck.options.remove(atOffsets: offsets)
                    wheelOfLuck.updateText()
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
                .deleteDisabled(wheelOfLuck.options.count < 2)
                CreateButtonView {
                    wheelOfLuck.options.append(SettingsWidgetWheelOfLuckOption())
                    wheelOfLuck.updateText()
                    wheelOfLuck.updateTotalWeight()
                    updateEffect()
                }
            } header: {
                Text("Options")
            }
        } else {
            WheelOfLuckWidgetOptionsView(value: $wheelOfLuck.text)
                .onChange(of: wheelOfLuck.text) { _ in
                    wheelOfLuck.optionsFromText(text: wheelOfLuck.text)
                    updateEffect()
                }
                .onAppear {
                    wheelOfLuck.optionsFromText(text: wheelOfLuck.text)
                    updateEffect()
                }
        }
        Section {
            Toggle("Advanced", isOn: $wheelOfLuck.advanced)
        }
        Section {
            if let effect = model.getWheelOfLuckEffect(id: widget.id) {
                WheelOfLuckWidgetView(model: model, widget: widget, effect: effect, indented: false)
            }
        }
    }
}
