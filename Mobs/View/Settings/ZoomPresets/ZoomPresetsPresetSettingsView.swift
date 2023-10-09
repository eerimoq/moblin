import AVFoundation
import SwiftUI

struct ZoomPresetsPresetSettingsView: View {
    @ObservedObject var model: Model
    private var preset: SettingsZoomPreset
    private var position: AVCaptureDevice.Position
    private let minX: Float
    private let maxX: Float

    init(model: Model, preset: SettingsZoomPreset, position: AVCaptureDevice.Position) {
        self.model = model
        self.preset = preset
        self.position = position
        if let device = preferredCamera(position: position) {
            minX = factorToX(
                position: position,
                factor: Float(device.minAvailableVideoZoomFactor)
            )
            maxX = factorToX(
                position: position,
                factor: Float(device.maxAvailableVideoZoomFactor)
            )
        } else {
            minX = 1.0
            maxX = 1.0
        }
    }

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
        return String(format: "%.01f", x)
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
    }
}
