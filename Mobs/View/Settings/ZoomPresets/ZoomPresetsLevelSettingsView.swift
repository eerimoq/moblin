import AVFoundation
import SwiftUI

struct ZoomPresetsLevelSettingsView: View {
    @ObservedObject var model: Model
    private var level: SettingsZoomLevel
    private var position: AVCaptureDevice.Position

    init(model: Model, level: SettingsZoomLevel, position: AVCaptureDevice.Position) {
        self.model = model
        self.level = level
        self.position = position
    }

    func submitName(name: String) {
        level.name = name
        model.store()
    }

    func submitLevel(x: String) {
        guard let x = Float(x) else {
            return
        }
        guard let device = preferredCamera(position: position) else {
            return
        }
        let minX = levelToX(
            position: position,
            level: Float(device.minAvailableVideoZoomFactor)
        )
        let maxX = levelToX(
            position: position,
            level: Float(device.maxAvailableVideoZoomFactor)
        )
        guard x >= minX && x <= maxX else {
            model.makeErrorToast(title: "Zoom level must be \(minX) - \(maxX)")
            return
        }
        let level = xToLevel(position: position, x: x)
        self.level.level = level
        model.store()
    }

    private func x() -> Float {
        return levelToX(position: position, level: level.level)
    }

    var body: some View {
        Form {
            NavigationLink(destination: NameEditView(
                name: level.name,
                onSubmit: submitName
            )) {
                TextItemView(name: "Name", value: level.name)
            }
            NavigationLink(destination: TextEditView(
                title: "Level",
                value: String(x()),
                onSubmit: submitLevel
            )) {
                TextItemView(name: "Level", value: String(x()))
            }
        }.navigationTitle("Zoom level")
    }
}
