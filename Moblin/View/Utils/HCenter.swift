import SwiftUI

struct HCenter<Content: View>: View {
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        HStack {
            Spacer()
            self.content()
            Spacer()
        }
    }
}

extension View {
    func hCenter(_ center: Bool) -> some View {
        modifier(HCenterModifier(center: center))
    }
}

private struct HCenterModifier: ViewModifier {
    let center: Bool

    func body(content: Content) -> some View {
        if center {
            HCenter {
                content
            }
        } else {
            content
        }
    }
}
