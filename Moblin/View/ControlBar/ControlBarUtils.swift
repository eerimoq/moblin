func controlBarScrollTargetBehavior(model: Model, containerWidth: Double, targetPosition: Double) -> Double {
    let spacing = 8.0
    let originalPagePosition = Double(model.controlBarPage - 1) * (containerWidth + spacing)
    let distance = targetPosition - originalPagePosition
    if distance > 15 {
        model.controlBarPage += 1
    } else if distance < -15 {
        model.controlBarPage -= 1
    }
    let pages = model.quickButtons.pairs.filter { !$0.isEmpty }.count
    model.controlBarPage = model.controlBarPage.clamped(to: 1 ... pages)
    return Double(model.controlBarPage - 1) * (containerWidth + spacing)
}
