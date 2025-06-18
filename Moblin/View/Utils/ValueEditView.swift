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
                Button {
                    add(offset: -increment)
                    value = onSubmit(value.trim())
                    add(offset: 0)
                } label: {
                    Text("-")
                        .frame(width: 40)
                        .font(.system(size: 25))
                }
                Divider()
                Button {
                    add(offset: increment)
                    value = onSubmit(value.trim())
                    add(offset: 0)
                } label: {
                    Text("+")
                        .frame(width: 40)
                        .font(.system(size: 25))
                }
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

struct ValueEditCompactView: View {
    @Binding var number: Double
    @Binding var value: String
    var minimum: Double
    var maximum: Double
    var onSubmit: (String) -> String
    @Binding var numericInput: Bool
    var incrementImageName: String
    var decrementImageName: String
    var increment: Double = 1

    func add(offset: Double) {
        if let value = Double(value) {
            number = (value + offset).clamped(to: minimum ... maximum)
            self.value = String(number)
        }
    }

    var body: some View {
        HStack {
            if numericInput {
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
            } else {
                Slider(
                    value: $number,
                    in: minimum ... maximum,
                    step: 1
                )
                .onChange(of: number) { number in
                    value = onSubmit("\(number)")
                }
            }
            Button {
                add(offset: -increment)
                value = onSubmit(value.trim())
                add(offset: 0)
            } label: {
                Image(systemName: decrementImageName)
                    .font(.title)
            }
            Button {
                add(offset: increment)
                value = onSubmit(value.trim())
                add(offset: 0)
            } label: {
                Image(systemName: incrementImageName)
                    .font(.title)
            }
        }
        .buttonStyle(BorderlessButtonStyle())
    }
}
