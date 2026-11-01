import CoreGraphics
import Foundation

struct SceneEditorSnap {
    var position: Double
    var guide: Double?
}

func sceneEditorSnapAxis(_ position: Double,
                         _ length: Double,
                         _ total: Double,
                         _ threshold: Double,
                         _ canCenter: Bool,
                         _ near: Bool,
                         _ targets: [Double]) -> SceneEditorSnap
{
    let positions = near ? 0 ... total : -length ... total - length
    let position = position.clamped(to: positions)
    var candidates = [SceneEditorSnap(position: 0), SceneEditorSnap(position: positions.upperBound)]
    if canCenter {
        candidates.append(SceneEditorSnap(position: positions.upperBound / 2, guide: total / 2))
    }
    for target in targets {
        for anchor in [0, length / 2, length] {
            candidates.append(SceneEditorSnap(position: target - anchor, guide: target))
        }
    }
    let closest = candidates
        .filter { positions.contains($0.position) }
        .min { abs($0.position - position) < abs($1.position - position) }
    if let closest, abs(closest.position - position) < threshold {
        return closest
    }
    return SceneEditorSnap(position: position)
}

struct SceneEditorResizeSnap {
    let factor: Double
    let distance: Double
    let guide: Double
}

func sceneEditorSnapResizeAxis(_ edges: [Double],
                               _ fixed: Double,
                               _ factor: Double,
                               _ factors: ClosedRange<Double>,
                               _ threshold: Double,
                               _ targets: [Double]) -> SceneEditorResizeSnap?
{
    var closest: SceneEditorResizeSnap?
    for edge in edges where abs(edge - fixed) > 1 {
        for target in targets {
            let snapFactor = (target - fixed) / (edge - fixed)
            let distance = abs(snapFactor - factor)
            if distance < threshold,
               factors.contains(snapFactor),
               distance < (closest?.distance ?? .infinity) - 1e-9
            {
                closest = SceneEditorResizeSnap(factor: snapFactor, distance: distance, guide: target)
            }
        }
    }
    return closest
}

func sceneEditorHandlePoint(_ rect: CGRect, _ alignment: SettingsAlignment) -> CGPoint {
    CGPoint(x: alignment.mirrorPositionHorizontally() ? rect.minX : rect.maxX,
            y: alignment.mirrorPositionVertically() ? rect.minY : rect.maxY)
}

func sceneEditorFixedPoint(_ rect: CGRect, _ alignment: SettingsAlignment) -> CGPoint {
    CGPoint(x: alignment.isHorizontalCenter() ? rect.midX : alignment.isLeft() ? rect.minX : rect.maxX,
            y: alignment.isVerticalCenter() ? rect.midY : alignment.isTop() ? rect.minY : rect.maxY)
}

func sceneEditorResizedRect(_ rect: CGRect, _ fixed: CGPoint, _ factor: Double) -> CGRect {
    CGRect(x: fixed.x + (rect.minX - fixed.x) * factor,
           y: fixed.y + (rect.minY - fixed.y) * factor,
           width: rect.width * factor,
           height: rect.height * factor)
}

private func layoutOffsetFromPosition(_ position: Double,
                                      _ size: Double,
                                      _ streamSize: Double,
                                      _ isNear: Bool) -> Double
{
    if isNear {
        position * 100 / streamSize
    } else {
        (streamSize - position - size) * 100 / streamSize
    }
}

func sceneEditorLayout(_ layout: SettingsWidgetLayout,
                       _ rect: CGRect,
                       _ canvasSize: CGSize) -> SettingsWidgetLayout
{
    var layout = layout
    let alignment = layout.alignment
    if !alignment.isHorizontalCenter() {
        layout.x = layoutOffsetFromPosition(rect.minX, rect.width, canvasSize.width, alignment.isLeft())
        layout.updateXString()
    }
    if !alignment.isVerticalCenter() {
        layout.y = layoutOffsetFromPosition(rect.minY, rect.height, canvasSize.height, alignment.isTop())
        layout.updateYString()
    }
    return layout
}

func sceneEditorAlignedLayout(_ layout: SettingsWidgetLayout,
                              _ alignment: SettingsAlignment,
                              _ size: CGSize,
                              _ canvasSize: CGSize) -> SettingsWidgetLayout
{
    let rect = CGRect(origin: layoutPosition(layout, size, canvasSize), size: size)
    var layout = layout
    layout.alignment = alignment
    if alignment.isHorizontalOrVerticalCenter() {
        layout.positioningLock = false
    }
    return sceneEditorLayout(layout, rect, canvasSize)
}

func sceneEditorTapSelection(_ hitIds: [UUID], _ selectedId: UUID?, _ sameLocation: Bool) -> UUID? {
    guard let index = hitIds.firstIndex(where: { $0 == selectedId }) else {
        return hitIds.first
    }
    if sameLocation {
        return index + 1 < hitIds.count ? hitIds[index + 1] : nil
    } else {
        return index == 0 ? nil : hitIds.first
    }
}
