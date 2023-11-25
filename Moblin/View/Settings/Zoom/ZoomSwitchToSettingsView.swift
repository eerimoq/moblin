import AVFoundation
import SwiftUI

struct ZoomSwitchToSettingsView: View {
    @EnvironmentObject var model: Model
    let name: String
    let position: AVCaptureDevice.Position
    let defaultZoom: SettingsZoomSwitchTo

    private func x() -> Float {
        return factorToX(position: position, factor: defaultZoom.level)
    }

    private func formatX(x: Float) -> String {
        return formatOneDecimal(value: x)
    }

    var body: some View {
        NavigationLink(destination: TextEditView(
            title: "To \(name) camera",
            value: formatX(x: x()),
            onSubmit: { x in
                guard let x = Float(x) else {
                    return
                }
                let (minX, maxX) = model.getMinMaxZoomX(position: position)
                guard x >= minX, x <= maxX else {
                    model.makeErrorToast(title: "X must be \(minX) - \(maxX)")
                    return
                }
                defaultZoom.level = xToFactor(position: position, x: x)
                model.store()
            }
        )) {
            Toggle(isOn: Binding(get: {
                defaultZoom.enabled
            }, set: { value in
                defaultZoom.enabled = value
                model.store()
            })) {
                TextItemView(
                    name: "To \(name) camera",
                    value: formatX(x: x())
                )
            }
        }
    }
}
