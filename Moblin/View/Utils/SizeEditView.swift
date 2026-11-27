import SwiftUI

struct SizeEditView: View {
    @Binding var number: Double
    var zero: Double = 0
    let total: Double
    let onSubmit: () -> Void

    var body: some View {
        ValueEditCompactView(
            number: $number,
            minimum: 1,
            maximum: 100,
            zero: zero,
            total: total,
            onSubmit: onSubmit,
            incrementImageName: "square.resize.up",
            decrementImageName: "square.resize.down",
            mirror: false
        )
    }
}
