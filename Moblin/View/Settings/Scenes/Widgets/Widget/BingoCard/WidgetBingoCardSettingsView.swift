import SwiftUI

struct BingCardWidgetSquaresView: View {
    @Binding var value: String
    @FocusState private var editingText: Bool

    var body: some View {
        Section {
            MultiLineTextFieldView(value: $value)
                .focused($editingText)
        } header: {
            Text("Squares")
        } footer: {
            MultiLineTextFieldDoneButtonView(editingText: $editingText)
        }
    }
}

struct BingoCardMarksView: View {
    @ObservedObject var bingoCard: SettingsWidgetBingoCard
    let updateEffect: () -> Void

    var body: some View {
        ForEach($bingoCard.squares) { $square in
            HStack {
                Text(square.text)
                Spacer()
                Button {
                    square.checked.toggle()
                    updateEffect()
                } label: {
                    Image(systemName: square.checked ? "square.split.diagonal.2x2" : "square")
                        .font(.title)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct WidgetBingoCardQuickButtonControlsView: View {
    @ObservedObject var bingoCard: SettingsWidgetBingoCard
    let updateEffect: () -> Void

    var body: some View {
        let squaresCountSide = bingoCard.size()
        VStack(spacing: 13) {
            ForEach(0 ..< squaresCountSide, id: \.self) { row in
                HStack(spacing: 13) {
                    Spacer()
                    ForEach(0 ..< squaresCountSide, id: \.self) { column in
                        let index = row * squaresCountSide + column
                        if index < bingoCard.squares.count {
                            Button {
                                bingoCard.squares[index].checked.toggle()
                                updateEffect()
                            } label: {
                                Image(systemName: bingoCard.squares[index].checked
                                    ? "square.split.diagonal.2x2"
                                    : "square")
                                    .font(.title)
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Image(systemName: "square")
                                .foregroundColor(.gray)
                                .font(.title)
                        }
                    }
                }
            }
        }
    }
}

struct WidgetBingoCardSettingsView: View {
    let model: Model
    let widget: SettingsWidget
    @ObservedObject var bingoCard: SettingsWidgetBingoCard

    private func updateEffect() {
        model.getBingoCardEffect(id: widget.id)?.setSettings(settings: bingoCard)
    }

    var body: some View {
        BingCardWidgetSquaresView(value: $bingoCard.squaresText)
            .onChange(of: bingoCard.squaresText) { _ in
                bingoCard.squaresTextChanged()
                updateEffect()
            }
        Section {
            BingoCardMarksView(bingoCard: bingoCard, updateEffect: updateEffect)
            TextButtonView("Reset") {
                bingoCard.uncheckAll()
                updateEffect()
            }
        } header: {
            Text("Marks")
        }
        Section {
            ColorPicker("Background", selection: $bingoCard.backgroundColorColor, supportsOpacity: true)
                .onChange(of: bingoCard.backgroundColorColor) { _ in
                    guard let color = bingoCard.backgroundColorColor.toRgb() else {
                        return
                    }
                    bingoCard.backgroundColor = color
                    updateEffect()
                }
            ColorPicker("Foreground", selection: $bingoCard.foregroundColorColor, supportsOpacity: false)
                .onChange(of: bingoCard.foregroundColorColor) { _ in
                    guard let color = bingoCard.foregroundColorColor.toRgb() else {
                        return
                    }
                    bingoCard.foregroundColor = color
                    updateEffect()
                }
        } header: {
            Text("Colors")
        }
    }
}
