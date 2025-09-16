import SwiftUI

private struct SceneSettings: Codable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    let alignment: SettingsAlignment
}

struct SceneWidgetSettingsView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var sceneWidget: SettingsSceneWidget
    @ObservedObject var widget: SettingsWidget
    @Binding var numericInput: Bool

    private let widgetsWithPosition: [SettingsWidgetType] = [
        .image, .browser, .text, .crop, .map, .qrCode, .alerts, .videoSource, .vTuber, .pngTuber, .snapshot,
    ]

    private func widgetHasPosition(widget: SettingsWidget) -> Bool {
        return widgetsWithPosition.contains(widget.type)
    }

    private let widgetsWithSize: [SettingsWidgetType] = [
        .image, .qrCode, .map, .videoSource, .vTuber, .pngTuber, .snapshot,
    ]

    private func widgetHasSize(widget: SettingsWidget) -> Bool {
        return widgetsWithSize.contains(widget.type)
    }

    private let widgetsWithAlignment: [SettingsWidgetType] = [
        .image, .vTuber, .pngTuber, .snapshot,
    ]

    private func widgetHasAlignment(widget: SettingsWidget) -> Bool {
        return widgetsWithAlignment.contains(widget.type)
    }

    private func canWidgetExpand(widget: SettingsWidget) -> Bool {
        return widgetHasPosition(widget: widget) || widgetHasSize(widget: widget)
    }

    private func exportToClipboard() {
        let settings = SceneSettings(
            x: sceneWidget.x,
            y: sceneWidget.y,
            width: sceneWidget.width,
            height: sceneWidget.height,
            alignment: sceneWidget.alignment
        )
        if let data = try? String.fromUtf8(data: JSONEncoder().encode(settings)) {
            UIPasteboard.general.string = data
        }
    }

    private func importFromClipboard() {
        guard let settings = UIPasteboard.general.string else {
            return
        }
        guard let settings = try? JSONDecoder().decode(SceneSettings.self, from: settings.data(using: .utf8)!) else {
            return
        }
        sceneWidget.x = settings.x.clamped(to: 0 ... 100)
        sceneWidget.xString = String(sceneWidget.x)
        sceneWidget.y = settings.y.clamped(to: 0 ... 100)
        sceneWidget.yString = String(sceneWidget.y)
        sceneWidget.width = settings.width.clamped(to: 1 ... 100)
        sceneWidget.widthString = String(sceneWidget.width)
        sceneWidget.height = settings.height.clamped(to: 1 ... 100)
        sceneWidget.heightString = String(sceneWidget.height)
        sceneWidget.alignment = settings.alignment
        model.sceneUpdated(imageEffectChanged: true)
    }

    var body: some View {
        Form {
            if widgetHasPosition(widget: widget) {
                Section {
                    PositionEditView(
                        number: $sceneWidget.x,
                        value: $sceneWidget.xString,
                        onSubmit: { _ in
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput,
                        incrementImageName: "arrow.forward.circle",
                        decrementImageName: "arrow.backward.circle",
                        mirror: sceneWidget.alignment == .topRight || sceneWidget.alignment == .bottomRight
                    )
                    PositionEditView(
                        number: $sceneWidget.y,
                        value: $sceneWidget.yString,
                        onSubmit: { _ in
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput,
                        incrementImageName: "arrow.down.circle",
                        decrementImageName: "arrow.up.circle",
                        mirror: sceneWidget.alignment == .bottomLeft || sceneWidget.alignment == .bottomRight
                    )
                    if widgetHasAlignment(widget: widget) {
                        HStack {
                            Text("Alignment")
                            Spacer()
                            Picker("", selection: $sceneWidget.alignment) {
                                ForEach(SettingsAlignment.allCases, id: \.self) {
                                    Text($0.toString())
                                        .tag($0)
                                }
                            }
                            .onChange(of: sceneWidget.alignment) { _ in
                                model.sceneUpdated()
                            }
                        }
                    }
                } header: {
                    Text("Position")
                }
            }
            if widgetHasSize(widget: widget) {
                Section {
                    SizeEditView(
                        number: $sceneWidget.width,
                        value: $sceneWidget.widthString,
                        onSubmit: { _ in
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput
                    )
                    SizeEditView(
                        number: $sceneWidget.height,
                        value: $sceneWidget.heightString,
                        onSubmit: { _ in
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput
                    )
                } header: {
                    Text("Size")
                }
            }
            Section {
                NavigationLink {
                    WidgetSettingsView(database: model.database, widget: widget)
                } label: {
                    Text("Widget")
                }
                if widget.type == .scene,
                   let scene = model.database.scenes.first(where: { $0.id == widget.scene.sceneId })
                {
                    NavigationLink {
                        SceneSettingsView(database: model.database, scene: scene)
                    } label: {
                        Text("Scene")
                    }
                }
            } header: {
                Text("Shortcut")
            }
            if canWidgetExpand(widget: widget) {
                Section {
                    Toggle("Numeric input", isOn: $numericInput)
                        .onChange(of: numericInput) { value in
                            model.database.sceneNumericInput = value
                        }
                }
                Section {
                    HCenter {
                        Button("Export to clipboard") {
                            exportToClipboard()
                        }
                    }
                }
                Section {
                    HCenter {
                        Button("Import from clipboard") {
                            importFromClipboard()
                        }
                    }
                }
            }
        }
        .navigationTitle(widget.name)
    }
}
