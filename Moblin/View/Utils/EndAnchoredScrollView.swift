import SwiftUI

struct EndAnchoredScrollView<Content: View>: View {
    let axis: Axis
    @ViewBuilder let content: () -> Content

    private func axes() -> Axis.Set {
        axis == .vertical ? .vertical : .horizontal
    }

    var body: some View {
        if #available(iOS 17, *) {
            ScrollView(axes()) {
                content()
            }
            .defaultScrollAnchor(axis == .vertical ? .bottom : .trailing)
        } else {
            let x: CGFloat = axis == .horizontal ? -1 : 1
            let y: CGFloat = axis == .vertical ? -1 : 1
            ScrollView(axes()) {
                content()
                    .scaleEffect(x: x, y: y)
            }
            .scaleEffect(x: x, y: y)
        }
    }
}
