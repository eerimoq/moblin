import SwiftUI

struct PositionEditView: View {
    var title: String
    var value: Double
    var onSubmit: (Double) -> Void

    func submit(value: String) -> String {
        if var value = Double(value) {
            value = value.clamped(to: 0 ... 99)
            onSubmit(value)
            return String(value)
        }
        return value
    }
    
    var body: some View {
        ValueEditView(
            title: title,
            value: String(value),
            minimum: 0,
            maximum: 99,
            onSubmit: submit
        )
    }
}
