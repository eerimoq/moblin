import SwiftUI

struct WidgetCropSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget

    private func changeXY(value: String) -> String? {
        guard let x = Int(value) else {
            return String(localized: "Not a number")
        }
        guard x >= 0 else {
            return String(localized: "Too small")
        }
        return nil
    }

    private func changeWidthHeight(value: String) -> String? {
        guard let x = Int(value) else {
            return String(localized: "Not a number")
        }
        guard x > 0 else {
            return String(localized: "Too small")
        }
        return nil
    }

    private func submitX(value: String) {
        guard let x = Int(value) else {
            return
        }
        widget.crop.x = x
        model.resetSelectedScene(changeScene: false)
    }

    private func submitY(value: String) {
        guard let y = Int(value) else {
            return
        }
        widget.crop.y = y
        model.resetSelectedScene(changeScene: false)
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        widget.crop.width = width
        model.resetSelectedScene(changeScene: false)
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0 else {
            return
        }
        widget.crop.height = height
        model.resetSelectedScene(changeScene: false)
    }

    private func sourceWidgetExists() -> Bool {
        return model.database.widgets.contains(where: { $0.id == widget.crop.sourceWidgetId })
    }

    var body: some View {
        Section {
            Picker("Source widget", selection: Binding(get: {
                if sourceWidgetExists() {
                    widget.crop.sourceWidgetId
                } else {
                    nil as UUID?
                }
            }, set: { value in
                guard let value else {
                    return
                }
                widget.crop.sourceWidgetId = value
                model.resetSelectedScene(changeScene: false)
            })) {
                if !sourceWidgetExists() {
                    Text("")
                        .tag(nil as UUID?)
                }
                ForEach(model.database.widgets.filter { $0.type == .browser }) {
                    Text($0.name)
                        .tag($0.id as UUID?)
                }
            }
            TextEditNavigationView(
                title: String(localized: "X"),
                value: String(widget.crop.x),
                onChange: changeXY,
                onSubmit: submitX,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(
                title: String(localized: "Y"),
                value: String(widget.crop.y),
                onChange: changeXY,
                onSubmit: submitY,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(
                title: String(localized: "Width"),
                value: String(widget.crop.width),
                onChange: changeWidthHeight,
                onSubmit: submitWidth,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(
                title: String(localized: "Height"),
                value: String(widget.crop.height),
                onChange: changeWidthHeight,
                onSubmit: submitHeight,
                keyboardType: .numbersAndPunctuation
            )
        }
    }
}
