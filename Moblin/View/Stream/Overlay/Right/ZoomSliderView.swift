import SwiftUI

private let knobSize = 26.0

struct StreamOverlayRightZoomSliderView: View {
    let model: Model
    @State private var offset = 0.0

    var body: some View {
        HStack {
            Image(systemName: "minus.magnifyingglass")
            GeometryReader { reader in
                let halfWidth = max((reader.size.width - knobSize) / 2, 1)
                ZStack {
                    Capsule()
                        .fill(.white.opacity(0.5))
                        .frame(height: 4)
                    Capsule()
                        .fill(.white)
                        .frame(width: 2, height: 12)
                    Circle()
                        .fill(.white)
                        .frame(width: knobSize, height: knobSize)
                        .shadow(radius: 2)
                        .offset(x: offset)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            offset = value.translation.width.clamped(to: -halfWidth ... halfWidth)
                            model.setZoomSpeed(speed: Float(offset / halfWidth))
                        }
                        .onEnded { _ in
                            withAnimation(.spring) {
                                offset = 0
                            }
                            model.stopZoomSpeed()
                        }
                )
            }
            Image(systemName: "plus.magnifyingglass")
        }
        .foregroundStyle(.white)
        .padding(.vertical, 5)
        .padding(.horizontal, 7)
        .frame(width: sliderWidth, height: sliderHeight)
        .background(backgroundColor)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
        .padding(.bottom, 5)
        .onDisappear {
            model.stopZoomSpeed()
        }
    }
}
