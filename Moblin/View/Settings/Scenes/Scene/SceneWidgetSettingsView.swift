import SwiftUI

private struct SceneSettings: Codable {
    let x: Double
    let y: Double
    let size: Double
    let alignment: SettingsAlignment
}

private struct ExportImportView: View {
    @EnvironmentObject private var model: Model
    @Binding var layout: SettingsWidgetLayout
    @ObservedObject var widget: SettingsWidget

    private func exportToClipboard() {
        let settings = SceneSettings(
            x: layout.x,
            y: layout.y,
            size: layout.size,
            alignment: layout.alignment
        )
        if let data = try? String.fromUtf8(data: JSONEncoder().encode(settings)) {
            UIPasteboard.general.string = data
        }
    }

    private func importFromClipboard() {
        guard let settings = UIPasteboard.general.string,
              let settings = try? JSONDecoder().decode(SceneSettings.self, from: settings.data(using: .utf8)!)
        else {
            return
        }
        layout.x = settings.x.clamped(to: 0 ... 100)
        layout.updateXString()
        layout.y = settings.y.clamped(to: 0 ... 100)
        layout.updateYString()
        layout.size = settings.size.clamped(to: 1 ... 100)
        layout.updateSizeString()
        layout.alignment = settings.alignment
        model.sceneUpdated(imageEffectChanged: true)
    }

    var body: some View {
        if widget.canExpand() {
            Section {
                TextButtonView("Export to clipboard") {
                    exportToClipboard()
                }
            }
            Section {
                TextButtonView("Import from clipboard") {
                    importFromClipboard()
                }
            }
        }
    }
}

struct SceneWidgetSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget

    var body: some View {
        Form {
            WidgetLayoutView(model: model,
                             layout: $sceneWidget.layout,
                             widget: widget,
                             numericInput: $database.sceneNumericInput)
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
            if widget.canExpand() {
                Section {
                    Toggle("Numeric input", isOn: $database.sceneNumericInput)
                }
                ExportImportView(layout: $sceneWidget.layout, widget: widget)
            }
        }
        .navigationTitle(widget.name)
    }
}
