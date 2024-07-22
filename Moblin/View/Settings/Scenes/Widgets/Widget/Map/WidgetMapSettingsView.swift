import SwiftUI

struct WidgetMapSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var delay: Double

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        guard width > 0, width < 4000 else {
            return
        }
        widget.map!.width = width
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0, height < 4000 else {
            return
        }
        widget.map!.height = height
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Section {
            TextEditNavigationView(
                title: String(localized: "Width"),
                value: String(widget.map!.width),
                onSubmit: submitWidth,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(title: String(localized: "Height"),
                                   value: String(widget.map!.height),
                                   onSubmit: submitHeight,
                                   keyboardType: .numbersAndPunctuation)
        }
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
