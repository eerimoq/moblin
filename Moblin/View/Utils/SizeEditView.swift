import SwiftUI

struct SizeEditView: View {
    var value: Double
    var onSubmit: (Double) -> Void

    func submit(value: String) -> String {
        if var value = Double(value) {
            value = value.clamped(to: 1 ... 100)
            onSubmit(value)
            return String(value)
        }
        return value
    }

    var body: some View {
        ValueEditCompactView(
            number: Float(value),
            value: String(value),
            minimum: 1,
            maximum: 100,
            onSubmit: submit,
            increment: 0.125
        )
    }
}
