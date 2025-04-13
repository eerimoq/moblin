import SwiftUI

struct PositionEditView: View {
    var value: Double
    var onSubmit: (Double) -> Void
    @Binding var numericInput: Bool

    func submit(value: String) -> String {
        if var value = Double(value) {
            value = value.clamped(to: 0 ... 100)
            onSubmit(value)
            return String(value)
        }
        return value
    }

    var body: some View {
        ValueEditCompactView(
            number: Float(value),
            value: String(value),
            minimum: 0,
            maximum: 100,
            onSubmit: submit,
            numericInput: $numericInput,
            increment: 0.125
        )
    }
}
