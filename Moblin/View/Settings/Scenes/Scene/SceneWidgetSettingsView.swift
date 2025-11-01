import SwiftUI

private struct SceneSettings: Codable {
    let x: Double
    let y: Double
    let size: Double
    let alignment: SettingsAlignment
}

private func widgetHasPosition(widget: SettingsWidget) -> Bool {
    return [
        .image,
        .browser,
        .text,
        .crop,
        .map,
        .qrCode,
        .alerts,
        .videoSource,
        .vTuber,
        .pngTuber,
        .snapshot,
    ].contains(widget.type)
}

private func widgetHasSize(widget: SettingsWidget) -> Bool {
    return [
        .image,
        .browser,
        .crop,
        .map,
        .qrCode,
        .videoSource,
        .vTuber,
        .pngTuber,
        .snapshot,
    ].contains(widget.type)
}

private func widgetHasAlignment(widget: SettingsWidget) -> Bool {
    return [
        .image,
        .browser,
        .text,
        .crop,
        .map,
        .qrCode,
        .videoSource,
        .vTuber,
        .pngTuber,
        .snapshot,
    ].contains(widget.type)
}

private func canWidgetExpand(widget: SettingsWidget) -> Bool {
    return widgetHasPosition(widget: widget) || widgetHasSize(widget: widget)
}

private struct LayoutView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var sceneWidget: SettingsSceneWidget
    @ObservedObject var widget: SettingsWidget
    @Binding var numericInput: Bool

    var body: some View {
        if widgetHasPosition(widget: widget) || widgetHasSize(widget: widget) ||
            widgetHasAlignment(widget: widget)
        {
            Section {
                if widgetHasPosition(widget: widget) {
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
                }
                if widgetHasSize(widget: widget) {
                    SizeEditView(
                        number: $sceneWidget.size,
                        value: $sceneWidget.sizeString,
                        onSubmit: { _ in
                            model.sceneUpdated()
                        },
                        numericInput: $numericInput
                    )
                }
                if widgetHasAlignment(widget: widget) {
                    Picker("Alignment", selection: $sceneWidget.alignment) {
                        ForEach(SettingsAlignment.allCases, id: \.self) {
                            Text($0.toString())
                                .tag($0)
                        }
                    }
                    .onChange(of: sceneWidget.alignment) { _ in
                        model.sceneUpdated()
                    }
                }
            } header: {
                Text("Layout")
            }
        }
    }
}

private struct ExportImportView: View {
    @EnvironmentObject private var model: Model
    @ObservedObject var sceneWidget: SettingsSceneWidget
    @ObservedObject var widget: SettingsWidget

    private func exportToClipboard() {
        let settings = SceneSettings(
            x: sceneWidget.x,
            y: sceneWidget.y,
            size: sceneWidget.size,
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
        sceneWidget.size = settings.size.clamped(to: 1 ... 100)
        sceneWidget.sizeString = String(sceneWidget.size)
        sceneWidget.alignment = settings.alignment
        model.sceneUpdated(imageEffectChanged: true)
    }

    var body: some View {
        if canWidgetExpand(widget: widget) {
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
}

struct SceneWidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    let sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget

    var body: some View {
        Form {
            LayoutView(sceneWidget: sceneWidget, widget: widget, numericInput: $database.sceneNumericInput)
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
                    Toggle("Numeric input", isOn: $database.sceneNumericInput)
                }
                ExportImportView(sceneWidget: sceneWidget, widget: widget)
            }
        }
        .navigationTitle(widget.name)
    }
}
