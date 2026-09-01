import SwiftUI

private let shadowRadius = 0.5

extension View {
    @ViewBuilder
    func stroke(color: Color, width: CGFloat = 1) -> some View {
        if width > 0 {
            compositingGroup()
                .shadow(color: color, radius: shadowRadius, x: width, y: 0)
                .shadow(color: color, radius: shadowRadius, x: -width, y: 0)
                .shadow(color: color, radius: shadowRadius, x: 0, y: width)
                .shadow(color: color, radius: shadowRadius, x: 0, y: -width)
        } else {
            self
        }
    }
}
