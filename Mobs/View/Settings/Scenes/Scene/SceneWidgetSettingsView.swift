import SwiftUI

struct ValueEditView: View {
    var title: String
    @State var value: String
    var minimum: Double
    var maximum: Double
    var onSubmit: (String) -> Void

    func add(offset: Double) {
        if var value = Double(value) {
            value += offset
            if value >= minimum && value <= maximum {
                self.value = String(value)
            }
        }
    }

    var body: some View {
        HStack {
            HStack {
                Text(title)
                Spacer()
            }
            .frame(width: 70)
            TextField("", text: $value, onEditingChanged: { isEditing in
                if !isEditing {
                    value = value.trim()
                    onSubmit(value)
                }
            })
            .onSubmit {
                value = value.trim()
                onSubmit(value)
            }
            Divider()
            Button(action: {
                add(offset: -1)
                value = value.trim()
                onSubmit(value)
            }, label: {
                Text("-")
                    .frame(width: 40)
                    .font(.system(size: 25))
            })
            Divider()
            Button(action: {
                add(offset: 1)
                value = value.trim()
                onSubmit(value)
            }, label: {
                Text("+")
                    .frame(width: 40)
                    .font(.system(size: 25))
            })
            Divider()
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}

struct SceneWidgetSettingsView: View {
    @ObservedObject private var model: Model
    private var widget: SettingsSceneWidget
    private var isImage: Bool

    init(model: Model, widget: SettingsSceneWidget) {
        self.model = model
        self.widget = widget
        if let widget = model.findWidget(id: widget.widgetId) {
            isImage = widget.type == .image
        } else {
            logger.error("Unable to find widget type")
            isImage = false
        }
    }

    func submitX(value: String) {
        if let value = Double(value) {
            widget.x = min(max(value, 0), 99)
            model.store()
            model.resetSelectedScene()
        }
    }

    func submitY(value: String) {
        if let value = Double(value) {
            widget.y = min(max(value, 0), 99)
            model.store()
            model.resetSelectedScene()
        }
    }

    func submitW(value: String) {
        if let value = Double(value) {
            widget.width = min(max(value, 1), 100)
            model.store()
            model.resetSelectedScene()
        }
    }

    func submitH(value: String) {
        if let value = Double(value) {
            widget.height = min(max(value, 1), 100)
            model.store()
            model.resetSelectedScene()
        }
    }

    var body: some View {
        Section {
            ValueEditView(
                title: "X",
                value: String(widget.x),
                minimum: 0,
                maximum: 99,
                onSubmit: submitX
            )
            ValueEditView(
                title: "Y",
                value: String(widget.y),
                minimum: 0,
                maximum: 99,
                onSubmit: submitY
            )
            ValueEditView(
                title: "Width",
                value: String(widget.width),
                minimum: 1,
                maximum: 100,
                onSubmit: submitW
            )
            ValueEditView(
                title: "Height",
                value: String(widget.height),
                minimum: 1,
                maximum: 100,
                onSubmit: submitH
            )
        }
    }
}
