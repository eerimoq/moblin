import SwiftUI

struct BingCardWidgetOptionsView: View {
    @Binding var value: String
    @FocusState private var editingText: Bool

    var body: some View {
        Section {
            MultiLineTextFieldView(value: $value)
                .focused($editingText)
        } header: {
            Text("Options")
        } footer: {
            if isPhone() {
                HStack {
                    Spacer()
                    Button("Done") {
                        editingText = false
                    }
                }
                .disabled(!editingText)
            }
        }
    }
}

struct BingoCardMarksView: View {
    @ObservedObject var bingoCard: SettingsWidgetBingoCard
    let updateEffect: () -> Void

    var body: some View {
        ForEach($bingoCard.cells) { $cell in
            HStack {
                Text(cell.text)
                Spacer()
                Button {
                    cell.checked.toggle()
                    updateEffect()
                } label: {
                    Image(systemName: cell.checked ? "square.split.diagonal.2x2" : "square")
                        .font(.title)
                }
                .buttonStyle(.borderless)
            }
        }
    }
}

struct BingoCardCompactMarksView: View {
    @ObservedObject var bingoCard: SettingsWidgetBingoCard
    let updateEffect: () -> Void

    var body: some View {
        let cellsCountSide = bingoCard.size()
        VStack(spacing: 9) {
            ForEach(0 ..< cellsCountSide, id: \.self) { row in
                HStack {
                    Spacer()
                    ForEach(0 ..< cellsCountSide, id: \.self) { column in
                        let index = row * cellsCountSide + column
                        if index < bingoCard.cells.count {
                            Button {
                                bingoCard.cells[index].checked.toggle()
                                updateEffect()
                            } label: {
                                Image(systemName: bingoCard.cells[index].checked
                                    ? "square.split.diagonal.2x2"
                                    : "square")
                                    .font(.title)
                            }
                            .buttonStyle(.borderless)
                        } else {
                            Image(systemName: "square")
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
        BingCardWidgetOptionsView(value: $bingoCard.cellsText)
            .onChange(of: bingoCard.cellsText) { _ in
                bingoCard.cellsTextChanged()
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
