import SwiftUI

struct PositionEditView: View {
    @Binding var number: Double
    let onSubmit: () -> Void
    let incrementImageName: String
    let decrementImageName: String
    let mirror: Bool
    let total: Double

    var body: some View {
        ValueEditCompactView(
            number: $number,
            minimum: -100,
            maximum: 100,
            total: total,
            onSubmit: onSubmit,
            incrementImageName: incrementImageName,
            decrementImageName: decrementImageName,
            mirror: mirror
        )
    }
}
