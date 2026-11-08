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
