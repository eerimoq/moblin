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
    private let hasPosition: Bool
    private let hasSize: Bool
    private var widget: SettingsSceneWidget

    init(model: Model, widget: SettingsSceneWidget, hasPosition: Bool, hasSize: Bool) {
        self.model = model
        self.widget = widget
        self.hasPosition = hasPosition
        self.hasSize = hasSize
    }

    func submitX(value: String) {
        if let value = Double(value) {
            widget.x = value.clamped(to: 0 ... 99)
            model.store()
            model.resetSelectedScene()
        }
    }

    func submitY(value: String) {
        if let value = Double(value) {
            widget.y = value.clamped(to: 0 ... 99)
            model.store()
            model.resetSelectedScene()
        }
    }

    func submitW(value: String) {
        if let value = Double(value) {
            widget.width = value.clamped(to: 1 ... 100)
            model.store()
            model.resetSelectedScene()
        }
    }

    func submitH(value: String) {
        if let value = Double(value) {
            widget.height = value.clamped(to: 1 ... 100)
            model.store()
            model.resetSelectedScene()
        }
    }

    var body: some View {
        Section {
            if hasPosition {
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
            }
            if hasSize {
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
}
