import SwiftUI

let zoomSegmentWidth = 50.0
let zoomSegmentWidthBig = 60.0
let segmentHeight = 40.0
let segmentHeightBig = 60.0
let sceneSegmentWidth = 70.0
let sliderWidth = 250.0
let sliderHeight = 40.0
let cameraButtonWidth = 70.0
let pickerBorderColor = Color.gray.opacity(0.3)
let pickerBackgroundColor = Color.black.opacity(0.4)
let pickerLabelMinimumScaleFactor = 0.7

private struct SegmentedPicker<T: Equatable, Content: View, Separator: View>: View {
    @Namespace private var selectionAnimation
    @Binding var selectedItem: T?
    private let items: [T]
    private let selectedColor: Color
    private let separator: Separator
    private let content: (T) -> Content
    private let onLongPress: ((Int) -> Void)?

    init(
        _ items: [T],
        selectedItem: Binding<T?>,
        selectedColor: Color,
        separator: Separator,
        @ViewBuilder content: @escaping (T) -> Content,
        onLongPress: ((Int) -> Void)? = nil
    ) {
        _selectedItem = selectedItem
        self.items = items
        self.selectedColor = selectedColor
        self.separator = separator
        self.content = content
        self.onLongPress = onLongPress
    }

    @ViewBuilder func overlay(for item: T) -> some View {
        if item == selectedItem {
            Rectangle()
                .fill(selectedColor)
                .matchedGeometryEffect(id: "selectedSegmentHighlight", in: selectionAnimation)
        }
    }

    var body: some View {
        ForEach(items.indices, id: \.self) { index in
            ZStack {
                Rectangle()
                    .overlay(overlay(for: items[index]))
                    .foregroundStyle(.black.opacity(0.1))
                content(items[index])
                    .contentShape(Rectangle())
            }
            .overlay {
                if index < items.count - 1 {
                    separator
                }
            }
            .onTapGesture {
                selectedItem = items[index]
            }
            .onLongPressGesture {
                onLongPress?(index)
            }
        }
    }
}

struct SegmentedHPicker<T: Equatable, Content: View>: View {
    let items: [T]
    @Binding var selectedItem: T?
    var selectedColor: Color = defaultSegmentedPickerSelectedColor.color()
    var backgroundColor: Color = pickerBackgroundColor
    var onLongPress: ((Int) -> Void)?
    let content: (T) -> Content

    private func separator() -> some View {
        Rectangle()
            .fill(pickerBorderColor)
            .frame(width: 1)
            .frame(maxWidth: .infinity, alignment: .trailing)
    }

    var body: some View {
        HStack(spacing: 0) {
            SegmentedPicker(items,
                            selectedItem: $selectedItem,
                            selectedColor: selectedColor,
                            separator: separator(),
                            content: content,
                            onLongPress: onLongPress)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundColor)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
    }
}

struct SegmentedVPicker<T: Equatable, Content: View>: View {
    let items: [T]
    @Binding var selectedItem: T?
    var selectedColor: Color = defaultSegmentedPickerSelectedColor.color()
    var backgroundColor: Color = pickerBackgroundColor
    var onLongPress: ((Int) -> Void)?
    let content: (T) -> Content

    private func separator() -> some View {
        Rectangle()
            .fill(pickerBorderColor)
            .frame(height: 1)
            .frame(maxHeight: .infinity, alignment: .bottom)
    }

    var body: some View {
        VStack(spacing: 0) {
            SegmentedPicker(items,
                            selectedItem: $selectedItem,
                            selectedColor: selectedColor,
                            separator: separator(),
                            content: content,
                            onLongPress: onLongPress)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(backgroundColor)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
    }
}
