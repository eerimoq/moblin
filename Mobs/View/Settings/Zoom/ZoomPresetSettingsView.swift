import AVFoundation
import SwiftUI

struct ZoomPresetSettingsView: View {
    @ObservedObject var model: Model
    var toolbar: Toolbar
    private var preset: SettingsZoomPreset
    private var position: AVCaptureDevice.Position
    private let minX: Float
    private let maxX: Float

    init(
        model: Model,
        preset: SettingsZoomPreset,
        position: AVCaptureDevice.Position,
        toolbar: Toolbar
    ) {
        self.model = model
        self.preset = preset
        self.position = position
        self.toolbar = toolbar
        (minX, maxX) = getMinMaxZoomX(position: position)
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
        return formatOneDecimal(value: x)
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                toolbar: toolbar,
                name: preset.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: preset.name)
            }
            NavigationLink(destination: TextEditView(
                toolbar: toolbar,
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
            toolbar
        }
    }
}
