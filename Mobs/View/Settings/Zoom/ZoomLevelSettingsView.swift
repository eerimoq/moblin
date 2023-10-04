import AVFoundation
import SwiftUI

struct ZoomLevelSettingsView: View {
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

    func submitLevel(level: String) {
        guard let level = Float(level) else {
            return
        }
        guard let device = preferredCamera(position: position) else {
            return
        }
        let minLevel = Float(device.minAvailableVideoZoomFactor)
        let maxLevel = Float(device.maxAvailableVideoZoomFactor)
        guard level >= minLevel && level <= maxLevel else {
            model.makeErrorToast(title: "Zoom level must be \(minLevel) - \(maxLevel)")
            return
        }
        self.level.level = level
        model.store()
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
                value: String(level.level),
                onSubmit: submitLevel
            )) {
                TextItemView(name: "Level", value: String(level.level))
            }
        }.navigationTitle("Zoom level")
    }
}
