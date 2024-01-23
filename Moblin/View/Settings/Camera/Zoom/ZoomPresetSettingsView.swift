import AVFoundation
import SwiftUI

struct ZoomPresetSettingsView: View {
    @EnvironmentObject var model: Model
    var preset: SettingsZoomPreset
    let minX: Float
    let maxX: Float

    func submitName(name: String) {
        preset.name = name
        model.store()
    }

    func submitX(x: String) {
        guard let x = Float(x) else {
            return
        }
        guard x >= minX && x <= maxX else {
            model.makeErrorToast(title: String(localized: "X must be \(minX) - \(maxX)"))
            return
        }
        preset.x = x
        model.store()
    }

    private func formatX(x: Float) -> String {
        return formatOneDecimal(value: x)
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: preset.name,
                onSubmit: submitName
            )) {
                TextItemView(name: String(localized: "Name"), value: preset.name)
            }
            NavigationLink(destination: TextEditView(
                title: "X",
                value: String(preset.x!),
                onSubmit: submitX,
                footer: Text(
                    "Allowed range is \(formatX(x: minX)) - \(formatX(x: maxX))."
                )
            )) {
                TextItemView(name: "X", value: String(preset.x!))
            }
        }
        .navigationTitle("Zoom preset")
        .toolbar {
            SettingsToolbar()
        }
    }
}
