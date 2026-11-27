import SwiftUI

struct SizeEditView: View {
    @Binding var number: Double
    @Binding var value: String
    let onSubmit: () -> Void

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
            incrementImageName: "square.resize.up",
            decrementImageName: "square.resize.down",
            mirror: false,
            increment: 1 / 15
        )
    }
}
