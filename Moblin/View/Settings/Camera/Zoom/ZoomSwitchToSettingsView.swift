import AVFoundation
import SwiftUI

struct ZoomSwitchToSettingsView: View {
    @EnvironmentObject var model: Model
    let name: String
    let position: AVCaptureDevice.Position
    let defaultZoom: SettingsZoomSwitchTo

    private func x() -> Float {
        return defaultZoom.x!
    }

    private func formatX(x: Float) -> String {
        return formatOneDecimal(value: x)
    }

    var body: some View {
        NavigationLink(destination: TextEditView(
            title: String(localized: "To \(name) camera"),
            value: formatX(x: x()),
            onSubmit: { x in
                guard let x = Float(x) else {
                    return
                }
                let (minX, maxX) = model.getMinMaxZoomX(position: position)
                guard x >= minX, x <= maxX else {
                    model.makeErrorToast(title: String(localized: "X must be \(minX) - \(maxX)"))
                    return
                }
                defaultZoom.x = x
            },
            keyboardType: .numbersAndPunctuation
        )) {
            Toggle(isOn: Binding(get: {
                defaultZoom.enabled
            }, set: { value in
                defaultZoom.enabled = value
            })) {
                TextItemView(
                    name: String(localized: "To \(name) camera"),
                    value: formatX(x: x())
                )
            }
        }
    }
}
