import SwiftUI

struct ValueEditView: View {
    let title: String
    @State var number: Float
    @State var value: String
    let minimum: Float
    let maximum: Float
    let onSubmit: (String) -> String
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
            .buttonStyle(.borderless)
        }
        Slider(
            value: $number,
            in: minimum ... maximum,
            step: increment,
            label: {
                EmptyView()
            }
        )
        .onChange(of: number) { number in
            value = onSubmit("\(number)")
        }
    }
}

private struct RepeatButtonView: View {
    let image: String
    let disabled: Bool
    let action: () -> Void
    @State private var repeater: Task<Void, Never>?

    private func pressingChanged(_ pressing: Bool) {
        repeater?.cancel()
        repeater = nil
        guard pressing, !disabled else {
            return
        }
        action()
        repeater = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            while !Task.isCancelled {
                action()
                try? await Task.sleep(nanoseconds: 15_000_000)
            }
        }
    }

    var body: some View {
        Image(systemName: image)
            .font(.title)
            .foregroundStyle(disabled ? AnyShapeStyle(.tertiary) : AnyShapeStyle(.tint))
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: .infinity, maximumDistance: 50) {} onPressingChanged: {
                pressingChanged($0)
            }
            .onDisappear {
                repeater?.cancel()
            }
    }
}

struct ValueEditCompactView: View {
    @Binding var number: Double
    let minimum: Double
    let maximum: Double
    var zero: Double = 0
    let total: Double
    let onSubmit: () -> Void
    let incrementImageName: String
    let decrementImageName: String
    let mirror: Bool
    @State private var value = ""

    private func pixels(_ number: Double) -> Double {
        zero + toPixels(number, total - zero)
    }

    private func format(_ number: Double) -> String {
        String(format: "%.2f", pixels(number))
    }

    private func set(pixels: Double) {
        number = ((pixels - zero) * 100 / (total - zero)).clamped(to: minimum ... maximum)
        value = format(number)
        onSubmit()
    }

    private func submit() {
        if let pixels = Double(value.trim()) {
            set(pixels: pixels)
        } else {
            value = format(number)
        }
    }

    private func add(offset: Double) {
        set(pixels: pixels(number) + offset)
    }

    var body: some View {
        HStack {
            TextField("", text: $value, onEditingChanged: { isEditing in
                if !isEditing {
                    submit()
                }
            })
            .keyboardType(.numbersAndPunctuation)
            .onSubmit {
                submit()
            }
            RepeatButtonView(image: decrementImageName, disabled: number == (mirror ? maximum : minimum)) {
                add(offset: mirror ? 1 : -1)
            }
            RepeatButtonView(image: incrementImageName, disabled: number == (mirror ? minimum : maximum)) {
                add(offset: mirror ? -1 : 1)
            }
        }
        .onAppear {
            value = format(number)
        }
        .onChange(of: number) {
            value = format($0)
        }
        .onChange(of: total) { _ in
            value = format(number)
        }
    }
}
