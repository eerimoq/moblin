import SwiftUI

struct ZoomView: View {
    var onChange: (_ level: CGFloat) -> Void
    @State var level: CGFloat = 1.0

    var body: some View {
        Slider(
            value: Binding(get: {
                level
            }, set: { (level) in
                if level != self.level {
                    onChange(level)
                    self.level = level
                }
            }),
            in: 1...5,
            step: 0.1
        )
    }
}
