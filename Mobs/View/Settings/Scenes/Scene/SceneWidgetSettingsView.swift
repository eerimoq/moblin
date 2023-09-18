import SwiftUI

func colorOf(model: Model, widget: SettingsSceneWidget) -> Color {
    guard let index = model.database.widgets
        .firstIndex(where: { item in item.id == widget.widgetId })
    else {
        return .blue
    }
    return widgetColors[index % widgetColors.count]
}

func drawWidget(model: Model, context: GraphicsContext, widget: SettingsSceneWidget) {
    let stroke = 4.0
    let xScale = (1920.0 / 6 - stroke) / 100
    let yScale = (1080.0 / 6 - stroke) / 100
    let x = CGFloat(widget.x) * xScale + stroke / 2
    let y = CGFloat(widget.y) * yScale + stroke / 2
    let width = CGFloat(widget.width) * xScale
    let height = CGFloat(widget.height) * yScale
    let origin = CGPoint(x: x, y: y)
    let size = CGSize(width: width, height: height)
    context.stroke(
        Path(roundedRect: CGRect(origin: origin, size: size), cornerRadius: 2.0),
        with: .color(colorOf(model: model, widget: widget)),
        lineWidth: stroke
    )
}

struct PreviewSectionView: View {
    @ObservedObject var model: Model
    var widget: SettingsSceneWidget

    var body: some View {
        Section {
            HStack {
                Spacer()
                Canvas { context, _ in
                    drawWidget(model: model, context: context, widget: widget)
                }
                .frame(width: 1920 / 6, height: 1080 / 6)
                .border(.secondary)
                Spacer()
            }
        } header: {
            Text("Preview")
        }
    }
}

struct ValueEditView: View {
    @ObservedObject var model: Model
    var widget: SettingsSceneWidget
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
            TextField("", text: $value)
                .onSubmit {
                    onSubmit(value.trim())
                }
            Divider()
            Button(action: {
                add(offset: -1)
                onSubmit(value.trim())
            }, label: {
                Text("-")
                    .frame(width: 40)
                    .font(.system(size: 25))
            })
            Divider()
            Button(action: {
                add(offset: 1)
                onSubmit(value.trim())
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
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }

    func submitY(value: String) {
        if let value = Double(value) {
            widget.y = min(max(value, 0), 99)
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }

    func submitW(value: String) {
        if let value = Double(value) {
            widget.width = min(max(value, 1), 100)
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }

    func submitH(value: String) {
        if let value = Double(value) {
            widget.height = min(max(value, 1), 100)
            model.sceneUpdated(imageEffectChanged: isImage)
        }
    }

    var body: some View {
        Form {
            PreviewSectionView(model: model, widget: widget)
            Section {
                ValueEditView(
                    model: model,
                    widget: widget,
                    title: "X",
                    value: String(widget.x),
                    minimum: 0,
                    maximum: 99,
                    onSubmit: submitX
                )
                ValueEditView(
                    model: model,
                    widget: widget,
                    title: "Y",
                    value: String(widget.y),
                    minimum: 0,
                    maximum: 99,
                    onSubmit: submitY
                )
                ValueEditView(
                    model: model,
                    widget: widget,
                    title: "Width",
                    value: String(widget.width),
                    minimum: 1,
                    maximum: 100,
                    onSubmit: submitW
                )
                ValueEditView(
                    model: model,
                    widget: widget,
                    title: "Height",
                    value: String(widget.height),
                    minimum: 1,
                    maximum: 100,
                    onSubmit: submitH
                )
            } footer: {
                Text("Origo is in the top left corner.")
            }
        }
        .navigationTitle("Widget")
    }
}
