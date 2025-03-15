import SwiftUI

struct ValueEditView: View {
    var title: String
    @State var number: Float
    @State var value: String
    var minimum: Float
    var maximum: Float
    var onSubmit: (String) -> String
    var increment: Float = 1
    var unit: String?

    func add(offset: Float) {
        if let value = Float(value) {
            number = (value + offset).clamped(to: minimum ... maximum)
            self.value = String(number)
        }
    }

    var body: some View {
        VStack {
            HStack {
                HStack {
                    Text(title)
                    Spacer()
                }
                .frame(width: 70)
                TextField("", text: $value, onEditingChanged: { isEditing in
                    if !isEditing {
                        value = onSubmit(value.trim())
                        add(offset: 0)
                    }
                })
                .keyboardType(.numbersAndPunctuation)
                .onSubmit {
                    value = onSubmit(value.trim())
                    add(offset: 0)
                }
                if let unit {
                    Text(unit)
                }
                Divider()
                Button(action: {
                    add(offset: -increment)
                    value = onSubmit(value.trim())
                    add(offset: 0)
                }, label: {
                    Text("-")
                        .frame(width: 40)
                        .font(.system(size: 25))
                })
                Divider()
                Button(action: {
                    add(offset: increment)
                    value = onSubmit(value.trim())
                    add(offset: 0)
                }, label: {
                    Text("+")
                        .frame(width: 40)
                        .font(.system(size: 25))
                })
                Divider()
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        Slider(
            value: $number,
            in: minimum ... maximum,
            step: increment
        )
        .onChange(of: number) { number in
            value = onSubmit("\(number)")
        }
    }
}
