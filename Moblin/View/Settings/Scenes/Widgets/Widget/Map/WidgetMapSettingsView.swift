import SwiftUI

struct WidgetMapSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var delay: Double

    var body: some View {
        Section {
            Toggle(isOn: Binding(get: {
                widget.map!.northUp!
            }, set: { value in
                widget.map!.northUp = value
                model.store()
                model.resetSelectedScene(changeScene: false)
            })) {
                Text("North up")
            }
        } footer: {
            Text("The map will rotate based of movement direction if disabled.")
        }
        Section {
            HStack {
                Slider(
                    value: $delay,
                    in: 0 ... 10,
                    step: 0.5,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        widget.map!.delay = delay
                        model.store()
                        model.resetSelectedScene(changeScene: false)
                    }
                )
                Text(String(String(delay)))
                    .frame(width: 35)
            }
        } header: {
            Text("Delay")
        } footer: {
            Text("To show the widget in sync with high latency cameras.")
        }
    }
}
