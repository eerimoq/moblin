func controlBarScrollTargetBehavior(model: Model, containerWidth: Double, targetPosition: Double) -> Double {
    let spacing = 8.0
    let originalPagePosition = Double(model.quickButtons.page - 1) * (containerWidth + spacing)
    let distance = targetPosition - originalPagePosition
    if distance > 15 {
        model.quickButtons.page += 1
    } else if distance < -15 {
        model.quickButtons.page -= 1
    }
    let pages = model.quickButtons.pairs.filter { !$0.isEmpty }.count
    model.quickButtons.page = model.quickButtons.page.clamped(to: 1 ... pages)
    return Double(model.quickButtons.page - 1) * (containerWidth + spacing)
}
