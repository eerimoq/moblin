import SwiftUI

extension View {
    func stroke(color: Color, width: CGFloat = 1) -> some View {
        StrokedView(color: color, width: width) { _ in
            self
        }
    }
}

struct StrokedView<Content: View>: View {
    let color: Color
    let width: CGFloat
    @ViewBuilder let content: (_ mask: Bool) -> Content
    private let id = UUID()

    var body: some View {
        if width > 0 {
            content(false)
                .background(
                    Rectangle()
                        .foregroundStyle(color)
                        .mask(alignment: .center) {
                            maskView()
                        }
                )
        } else {
            content(false)
        }
    }

    private func maskView() -> some View {
        Canvas { context, size in
            context.addFilter(.alphaThreshold(min: 0.01))
            if let resolvedView = context.resolveSymbol(id: id) {
                context.draw(resolvedView, at: .init(x: size.width / 2, y: size.height / 2))
            }
        } symbols: {
            content(true)
                .tag(id)
                .blur(radius: width)
        }
    }
}
