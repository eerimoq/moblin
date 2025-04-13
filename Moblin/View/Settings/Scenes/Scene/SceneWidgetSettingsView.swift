import SwiftUI

private struct SceneSettings: Codable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

struct SceneWidgetSettingsView: View {
    @EnvironmentObject private var model: Model
    var sceneWidget: SettingsSceneWidget
    var widget: SettingsWidget
    @Binding var numericInput: Bool
    @State var x: Double
    @State var y: Double
    @State var width: Double
    @State var height: Double
    @State var xString: String
    @State var yString: String
    @State var widthString: String
    @State var heightString: String

    func submitX(value: Double) {
        sceneWidget.x = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitY(value: Double) {
        sceneWidget.y = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitWidth(value: Double) {
        sceneWidget.width = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    func submitHeight(value: Double) {
        sceneWidget.height = value
        model.sceneUpdated(imageEffectChanged: true)
    }

    private let widgetsWithPosition: [SettingsWidgetType] = [
        .image, .browser, .text, .crop, .map, .qrCode, .alerts, .videoSource,
    ]

    private func widgetHasPosition(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widgetsWithPosition.contains(widget.type)
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private let widgetsWithSize: [SettingsWidgetType] = [
        .image, .qrCode, .map, .videoSource,
    ]

    private func widgetHasSize(id: UUID) -> Bool {
        if let widget = model.findWidget(id: id) {
            return widgetsWithSize.contains(widget.type)
        } else {
            logger.error("Unable to find widget type")
            return false
        }
    }

    private func canWidgetExpand(widget: SettingsWidget) -> Bool {
        return widgetHasPosition(id: widget.id) || widgetHasSize(id: widget.id)
    }

    private func exportToClipboard() {
        let settings = SceneSettings(
            x: sceneWidget.x,
            y: sceneWidget.y,
            width: sceneWidget.width,
            height: sceneWidget.height
        )
        if let data = try? String.fromUtf8(data: JSONEncoder().encode(settings)) {
            UIPasteboard.general.string = data
            model.makeToast(title: "Settings exported")
        }
    }

    private func importFromClipboard() {
        guard let settings = UIPasteboard.general.string else {
            model.makeErrorToast(title: String(localized: "Empty clipboard"))
            return
        }
        guard let settings = try? JSONDecoder().decode(SceneSettings.self, from: settings.data(using: .utf8)!) else {
            model.makeErrorToast(title: String(localized: "Malformed settings"))
            return
        }
        sceneWidget.x = settings.x.clamped(to: 0 ... 100)
        sceneWidget.y = settings.y.clamped(to: 0 ... 100)
        sceneWidget.width = settings.width.clamped(to: 1 ... 100)
        sceneWidget.height = settings.height.clamped(to: 1 ... 100)
        x = sceneWidget.x
        y = sceneWidget.y
        width = sceneWidget.width
        height = sceneWidget.height
        xString = String(sceneWidget.x)
        yString = String(sceneWidget.y)
        widthString = String(sceneWidget.width)
        heightString = String(sceneWidget.height)
        model.sceneUpdated(imageEffectChanged: true)
        model.makeToast(title: String(localized: "Settings imported"))
    }

    var body: some View {
        Form {
            if widgetHasPosition(id: widget.id) {
                Section {
                    PositionEditView(
                        number: $x,
                        value: $xString,
                        onSubmit: submitX,
                        numericInput: $numericInput
                    )
                    PositionEditView(
                        number: $y,
                        value: $yString,
                        onSubmit: submitY,
                        numericInput: $numericInput
                    )
                } header: {
                    Text("Position")
                }
            }
            if widgetHasSize(id: widget.id) {
                Section {
                    SizeEditView(
                        number: $width,
                        value: $widthString,
                        onSubmit: submitWidth,
                        numericInput: $numericInput
                    )
                    SizeEditView(
                        number: $height,
                        value: $heightString,
                        onSubmit: submitHeight,
                        numericInput: $numericInput
                    )
                } header: {
                    Text("Size")
                }
            }
            Section {
                NavigationLink {
                    WidgetSettingsView(
                        widget: widget,
                        type: widget.type.toString(),
                        name: widget.name
                    )
                } label: {
                    Text("Widget")
                }
            } header: {
                Text("Shortcut")
            }
            Section {
                Toggle("Numeric input", isOn: $numericInput)
                    .onChange(of: numericInput) { value in
                        model.database.sceneNumericInput = value
                    }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Export to clipboard") {
                        exportToClipboard()
                    }
                    Spacer()
                }
            }
            Section {
                HStack {
                    Spacer()
                    Button("Import from clipboard") {
                        importFromClipboard()
                    }
                    Spacer()
                }
            }
        }
        .navigationTitle(widget.name)
    }
}
