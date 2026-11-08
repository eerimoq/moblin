import SwiftUI

@MainActor
func controlBarScrollTargetBehavior(model: Model, containerWidth: Double, targetPosition: Double) -> Double {
    let spacing = 8.0
    let originalPagePosition = Double(model.quickButtons.page - 1) * (containerWidth + spacing)
    let distance = targetPosition - originalPagePosition
    if distance > 15 {
        model.quickButtons.page += 1
    } else if distance < -15 {
        model.quickButtons.page -= 1
    }
    let pages = model.quickButtons.pairs.count(where: { !$0.isEmpty })
    model.quickButtons.page = model.quickButtons.page.clamped(to: 1 ... pages)
    return Double(model.quickButtons.page - 1) * (containerWidth + spacing)
}

struct SettingsButtonImage: View {
    var body: some View {
        Image(systemName: "gearshape")
            .frame(width: controlBarButtonSize, height: controlBarButtonSize)
            .overlay(
                Circle()
                    .stroke(.secondary)
            )
            .foregroundStyle(.white)
    }
}

private struct QuickButtonsScrollClipShape: Shape {
    let horizontal: Bool

    func path(in rect: CGRect) -> Path {
        Path(horizontal ? rect.insetBy(dx: 0, dy: -10) : rect.insetBy(dx: -10, dy: 0))
    }
}

extension View {
    @ViewBuilder
    func controlBarButtonBackground(color: Color, shape: some Shape) -> some View {
        if #available(iOS 26, *) {
            let glass: Glass = isMac() ? .clear.tint(color.mix(with: .white, by: 0.06)) : .regular.tint(color)
            glassEffect(glass, in: shape)
                .environment(\.colorScheme, .light)
        } else {
            background(color)
                .clipShape(shape)
        }
    }

    @ViewBuilder
    func quickButtonsScrollClip(horizontal: Bool) -> some View {
        if #available(iOS 26, *) {
            scrollClipDisabled()
                .clipShape(QuickButtonsScrollClipShape(horizontal: horizontal))
        } else {
            self
        }
    }
}
