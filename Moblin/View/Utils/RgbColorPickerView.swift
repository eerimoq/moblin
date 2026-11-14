import SwiftUI

struct RgbColorPickerView: View {
    let title: LocalizedStringKey
    @Binding var color: Color
    var opacity: Bool = false
    let onChange: (RgbColor) -> Void

    var body: some View {
        ColorPicker(title, selection: $color, supportsOpacity: opacity)
            .onChange(of: color) { color in
                guard let color = color.toRgb() else {
                    return
                }
                onChange(color)
            }
    }
}
