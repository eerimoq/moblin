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
    var onSubmit: (String) -> Void

    func add(offset: Double) {
        if let value = Double(value) {
            self.value = String(value + offset)
        }
    }

    var body: some View {
        Form {
            PreviewSectionView(model: model, widget: widget)
            Section {
                HStack {
                    TextField("", text: $value)
                        .onSubmit {
                            onSubmit(value.trim())
                        }
                    Spacer()
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
        .navigationTitle(title)
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
            if isImage {
                Section {
                    NavigationLink(destination: ValueEditView(
                        model: model,
                        widget: widget,
                        title: "X",
                        value: String(widget.x),
                        onSubmit: submitX
                    )) {
                        TextItemView(name: "X", value: String(widget.x))
                    }
                    NavigationLink(destination: ValueEditView(
                        model: model,
                        widget: widget,
                        title: "Y",
                        value: String(widget.y),
                        onSubmit: submitY
                    )) {
                        TextItemView(name: "Y", value: String(widget.y))
                    }
                    NavigationLink(destination: ValueEditView(
                        model: model,
                        widget: widget,
                        title: "Width",
                        value: String(widget.width),
                        onSubmit: submitW
                    )) {
                        TextItemView(name: "Width", value: String(widget.width))
                    }
                    NavigationLink(destination: ValueEditView(
                        model: model,
                        widget: widget,
                        title: "Height",
                        value: String(widget.height),
                        onSubmit: submitH
                    )) {
                        TextItemView(name: "Height", value: String(widget.height))
                    }
                } footer: {
                    Text(
                        "Origo is in the top left corner. Leave width and/or height empty to expand to border."
                    )
                }
            } else {
                Section {
                    TextItemView(name: "X", value: String(widget.x))
                    TextItemView(name: "Y", value: String(widget.y))
                    TextItemView(name: "Width", value: String(widget.width))
                    TextItemView(name: "Height", value: String(widget.height))
                } footer: {
                    Text("Only full screen cameras and video effects are supported.")
                }
            }
        }
        .navigationTitle("Widget")
    }
}
