import SwiftUI

let zoomSegmentWidth = 50.0
let segmentHeight = 40.0
let sceneSegmentWidth = 70.0
let sliderHeight = 40.0
let cameraButtonWidth = 70.0
let pickerBorderColor = Color.gray
var pickerBackgroundColor = Color.black.opacity(0.4)

struct SegmentedPicker<T: Equatable, Content: View>: View {
    @Namespace private var selectionAnimation
    @Binding var selectedItem: T?
    private let items: [T]
    private let content: (T) -> Content
    private let onLongPress: ((Int) -> Void)?

    init(
        _ items: [T],
        selectedItem: Binding<T?>,
        @ViewBuilder content: @escaping (T) -> Content,
        onLongPress: ((Int) -> Void)? = nil
    ) {
        _selectedItem = selectedItem
        self.items = items
        self.content = content
        self.onLongPress = onLongPress
    }

    @ViewBuilder func overlay(for item: T) -> some View {
        if item == selectedItem {
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.6))
                .padding(2)
                .matchedGeometryEffect(id: "selectedSegmentHighlight", in: selectionAnimation)
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(self.items.indices, id: \.self) { index in
                ZStack {
                    Rectangle()
                        .overlay(self.overlay(for: self.items[index]))
                        .foregroundColor(.black.opacity(0.1))
                    self.content(self.items[index])
                        .contentShape(Rectangle())
                }
                .onTapGesture {
                    self.selectedItem = self.items[index]
                }
                .onLongPressGesture {
                    onLongPress?(index)
                }
                Divider()
                    .background(pickerBorderColor)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
