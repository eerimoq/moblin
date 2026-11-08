import SwiftUI

@MainActor
func controlBarScrollTargetBehavior(model: Model, containerWidth: Double, targetPosition: Double) -> Double {
    let spacing = 8.0
    let originalPagePosition = Double(model.quickButtonsPages.page - 1) * (containerWidth + spacing)
    let distance = targetPosition - originalPagePosition
    if distance > 15 {
        model.quickButtonsPages.page += 1
    } else if distance < -15 {
        model.quickButtonsPages.page -= 1
    }
    let pages = model.quickButtons.pairs.count(where: { !$0.isEmpty })
    model.quickButtonsPages.page = model.quickButtonsPages.page.clamped(to: 1 ... pages)
    return Double(model.quickButtonsPages.page - 1) * (containerWidth + spacing)
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

struct ControlBarGlassContainer<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                content()
            }
        } else {
            content()
        }
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
            background(shape.fill(color))
                .glassEffect(.regular.tint(color), in: shape)
        } else {
            background(shape.fill(color))
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
