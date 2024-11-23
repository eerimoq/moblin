import AVFoundation
import SwiftUI

struct ZoomPresetSettingsView: View {
    @EnvironmentObject var model: Model
    var preset: SettingsZoomPreset
    let minX: Float
    let maxX: Float

    func submitX(x: String) {
        guard let x = Float(x) else {
            return
        }
        guard x >= minX && x <= maxX else {
            model.makeErrorToast(title: String(localized: "X must be \(minX) - \(maxX)"))
            return
        }
        preset.x = x
        preset.name = "\(formatOneDecimal(x))x".replacingOccurrences(of: ".0", with: "")
    }

    private func formatX(x: Float) -> String {
        return formatOneDecimal(x)
    }

    var body: some View {
        TextEditView(
            title: String(localized: "X"),
            value: String(preset.x!),
            footers: [
                String(localized: "Allowed range is \(formatX(x: minX)) - \(formatX(x: maxX))."),
            ],
            keyboardType: .numbersAndPunctuation
        ) {
            submitX(x: $0)
        }
    }
}
