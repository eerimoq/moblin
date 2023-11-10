import AVFoundation
import SwiftUI

struct ZoomPresetSettingsView: View {
    @EnvironmentObject var model: Model
    var preset: SettingsZoomPreset
    var position: AVCaptureDevice.Position
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
            model.makeErrorToast(title: "X must be \(minX) - \(maxX)")
            return
        }
        preset.level = xToFactor(position: position, x: x)
        model.store()
    }

    private func x() -> Float {
        return factorToX(position: position, factor: preset.level)
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
                TextItemView(name: "Name", value: preset.name)
            }
            NavigationLink(destination: TextEditView(
                title: "X",
                value: String(x()),
                onSubmit: submitX,
                footer: Text(
                    "Allowed range is \(formatX(x: minX)) - \(formatX(x: maxX))."
                )
            )) {
                TextItemView(name: "X", value: String(x()))
            }
        }
        .navigationTitle("Zoom preset")
        .toolbar {
            SettingsToolbar()
        }
    }
}
