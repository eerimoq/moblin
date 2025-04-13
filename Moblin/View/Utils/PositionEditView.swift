import SwiftUI

struct PositionEditView: View {
    @Binding var number: Double
    @Binding var value: String
    var onSubmit: (Double) -> Void
    @Binding var numericInput: Bool

    func submit(value: String) -> String {
        if var value = Float(value) {
            value = value.clamped(to: 0 ... 100)
            onSubmit(Double(value))
            return String(value)
        }
        return value
    }

    var body: some View {
        ValueEditCompactView(
            number: $number,
            value: $value,
            minimum: 0,
            maximum: 100,
            onSubmit: submit,
            numericInput: $numericInput,
            increment: 0.125
        )
    }
}
