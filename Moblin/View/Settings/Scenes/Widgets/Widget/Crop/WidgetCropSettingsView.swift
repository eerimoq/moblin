import SwiftUI

struct WidgetCropSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget

    private func submitX(value: String) {
        guard let x = Int(value) else {
            return
        }
        guard x >= 0 else {
            return
        }
        widget.crop!.x = x
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitY(value: String) {
        guard let y = Int(value) else {
            return
        }
        guard y >= 0 else {
            return
        }
        widget.crop!.y = y
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        guard width > 0 else {
            return
        }
        widget.crop!.width = width
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0 else {
            return
        }
        widget.crop!.height = height
        model.store()
        model.resetSelectedScene(changeScene: false)
    }

    var body: some View {
        Section {
            HStack {
                Text("Source widget")
                Spacer()
                Picker("", selection: Binding(get: {
                    widget.crop!.sourceWidgetId
                }, set: { value in
                    widget.crop!.sourceWidgetId = value
                    model.store()
                    model.resetSelectedScene(changeScene: false)
                })) {
                    ForEach(model.database.widgets.filter { $0.type == .browser }) {
                        Text($0.name)
                            .tag($0.id)
                    }
                }
            }
            TextEditNavigationView(
                title: String(localized: "X"),
                value: String(widget.crop!.x),
                onSubmit: submitX
            )
            TextEditNavigationView(
                title: String(localized: "Y"),
                value: String(widget.crop!.y),
                onSubmit: submitY
            )
            TextEditNavigationView(
                title: String(localized: "Width"),
                value: String(widget.crop!.width),
                onSubmit: submitWidth
            )
            TextEditNavigationView(
                title: String(localized: "Height"),
                value: String(widget.crop!.height),
                onSubmit: submitHeight
            )
        }
    }
}
