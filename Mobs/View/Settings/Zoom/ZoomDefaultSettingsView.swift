import AVFoundation
import SwiftUI

struct ZoomDefaultSettingsView: View {
    @ObservedObject var model: Model
    let name: String
    let position: AVCaptureDevice.Position
    let defaultZoom: SettingsZoomDefault

    var body: some View {
        NavigationLink(destination: TextEditView(
            title: "\(name) camera default zoom",
            value: String(factorToX(position: position, factor: defaultZoom.level)),
            onSubmit: { x in
                guard let x = Float(x) else {
                    return
                }
                let (minX, maxX) = getMinMaxZoomX(position: position)
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
                    name: "\(name) camera",
                    value: String(factorToX(
                        position: position,
                        factor: defaultZoom.level
                    ))
                )
            }
        }
    }
}
