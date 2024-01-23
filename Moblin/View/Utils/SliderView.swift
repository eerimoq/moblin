import SwiftUI

struct SliderView: View {
    @State var value: Float
    let minimum: Float
    let maximum: Float
    let step: Float
    let onSubmit: (Float) -> Void
    let width: Float
    let format: (Float) -> String

    var body: some View {
        HStack {
            Slider(
                value: $value,
                in: minimum ... maximum,
                step: step,
                onEditingChanged: { begin in
                    guard !begin else {
                        return
                    }
                    onSubmit(value)
                }
            )
            Text(format(value))
                .frame(width: CGFloat(width))
        }
    }
}
