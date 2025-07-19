import AVFoundation
import SwiftUI

struct ZoomSwitchToSettingsView: View {
    @EnvironmentObject var model: Model
    let name: String
    let position: AVCaptureDevice.Position
    @ObservedObject var defaultZoom: SettingsZoomSwitchTo

    private func x() -> Float {
        return defaultZoom.x
    }

    private func formatX(x: Float) -> String {
        return formatOneDecimal(x)
    }

    var body: some View {
        NavigationLink {
            TextEditView(
                title: String(localized: "To \(name) camera"),
                value: formatX(x: x()),
                keyboardType: .numbersAndPunctuation
            ) {
                guard let x = Float($0) else {
                    return
                }
                let (minX, maxX) = model.getMinMaxZoomX(position: position)
                guard x >= minX, x <= maxX else {
                    model.makeErrorToast(title: String(localized: "X must be \(minX) - \(maxX)"))
                    return
                }
                defaultZoom.x = x
            }
        } label: {
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
