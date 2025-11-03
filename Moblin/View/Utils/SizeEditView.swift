import SwiftUI

struct SizeEditView: View {
    @Binding var number: Double
    @Binding var value: String
    let onSubmit: () -> Void
    @Binding var numericInput: Bool

    func submit(value: String) -> String {
        if var value = Double(value) {
            value = value.clamped(to: 1 ... 100)
            onSubmit()
            return String(value)
        }
        return value
    }

    var body: some View {
        ValueEditCompactView(
            number: $number,
            value: $value,
            minimum: 1,
            maximum: 100,
            onSubmit: submit,
            numericInput: $numericInput,
            incrementImageName: "square.resize.up",
            decrementImageName: "square.resize.down",
            mirror: false,
            increment: 0.125
        )
    }
}
