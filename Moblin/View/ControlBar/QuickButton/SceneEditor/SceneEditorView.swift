import SwiftUI

private enum SceneEditorEditMode {
    case move
    case resize
}

private struct SceneEditorEdit {
    let outline: WidgetOutline
    let mode: SceneEditorEditMode
    let startSize: Double
    var rect: CGRect
    var snapX: SceneEditorSnap?
    var snapY: SceneEditorSnap?
}

private struct SceneEditorSelectedWidget {
    let sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget
}

private class SceneEditorSelection: ObservableObject {
    @Published var sceneWidgetId: UUID? {
        didSet {
            if sceneWidgetId == nil {
                showingSettings = false
            }
        }
    }

    @Published var showingSettings = false
}

private struct SceneEditorSnap {
    var position: Double
    var centered = false
    var guide: Double?
}

private func snapAxis(_ position: Double,
                      _ length: Double,
                      _ total: Double,
                      _ threshold: Double,
                      _ canCenter: Bool,
                      _ targets: [Double]) -> SceneEditorSnap
{
    let maximum = max(total - length, 0)
    let position = position.clamped(to: 0 ... maximum)
    var candidates = [SceneEditorSnap(position: 0), SceneEditorSnap(position: maximum)]
    if canCenter {
        candidates.append(SceneEditorSnap(position: maximum / 2, centered: true, guide: total / 2))
    }
    for target in targets {
        for anchor in [0, length / 2, length] where (0 ... maximum).contains(target - anchor) {
            candidates.append(SceneEditorSnap(position: target - anchor, guide: target))
        }
    }
    let closest = candidates.min { abs($0.position - position) < abs($1.position - position) }
    if let closest, abs(closest.position - position) < threshold {
        return closest
    }
    return SceneEditorSnap(position: position)
}

private struct SceneEditorResizeSnap {
    let factor: Double
    let distance: Double
    let guide: Double
}

private func snapResizeAxis(_ edges: [Double],
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

private func distance(_ first: CGPoint, _ second: CGPoint) -> Double {
    hypot(first.x - second.x, first.y - second.y)
}

private func movesDiagonally(_ layout: SettingsWidgetLayout) -> Bool {
    layout.positioningLock && !layout.alignment.isHorizontalOrVerticalCenter()
}

private func diagonalDirection(_ alignment: SettingsAlignment) -> CGSize {
    CGSize(width: alignment.isLeft() ? 1 : -1, height: alignment.isTop() ? 1 : -1)
}

private struct SceneEditorCanvasView: View {
    let model: Model
    @ObservedObject var widgetOutlines: WidgetOutlines
    let mirror: Bool
    let size: CGSize
    @ObservedObject var selection: SceneEditorSelection
    @State private var edit: SceneEditorEdit?

    private var selectedId: UUID? {
        selection.sceneWidgetId
    }

    private var canvasSize: CGSize {
        widgetOutlines.canvasSize
    }

    private var scale: Double {
        canvasSize.width / size.width
    }

    private var snapThreshold: Double {
        8 * scale
    }

    private var editableOutlines: [WidgetOutline] {
        widgetOutlines.outlines.filter(\.inScene)
    }

    private var selectedOutline: WidgetOutline? {
        editableOutlines.first(where: { $0.id == selectedId })
    }

    private func viewRect(_ rect: CGRect) -> CGRect {
        widgetOutlineViewRect(rect, canvasSize, mirror, size)
    }

    private func viewPoint(_ point: CGPoint) -> CGPoint {
        viewRect(CGRect(origin: point, size: .zero)).origin
    }

    private func canvasDelta(_ translation: CGSize) -> CGSize {
        CGSize(width: translation.width * scale * (mirror ? -1 : 1), height: translation.height * scale)
    }

    private func currentRect(_ outline: WidgetOutline) -> CGRect {
        if let edit, edit.outline.id == outline.id {
            return edit.rect
        }
        return outline.rect
    }

    private func hitRect(_ outline: WidgetOutline) -> CGRect {
        let rect = viewRect(outline.rect)
        if outline.sized {
            return rect.insetBy(dx: min(0, (rect.width - 44) / 2), dy: min(0, (rect.height - 44) / 2))
        }
        let alignment = outline.sceneWidget.layout.alignment
        let width = 120.0
        let height = 60.0
        let x = if alignment.isHorizontalCenter() {
            rect.minX - width / 2
        } else if alignment.isLeft() != mirror {
            rect.minX - 22
        } else {
            rect.minX - width + 22
        }
        let y = if alignment.isVerticalCenter() {
            rect.minY - height / 2
        } else if alignment.isTop() {
            rect.minY - 22
        } else {
            rect.minY - height + 22
        }
        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func outlines(at location: CGPoint) -> [WidgetOutline] {
        editableOutlines
            .reversed()
            .map { ($0, hitRect($0)) }
            .filter { $0.1.contains(location) }
            .sorted { $0.1.width * $0.1.height < $1.1.width * $1.1.height }
            .map(\.0)
    }

    private func outlineForTap(at location: CGPoint) -> WidgetOutline? {
        let hits = outlines(at: location)
        guard let index = hits.firstIndex(where: { $0.id == selectedId }) else {
            return hits.first
        }
        guard index + 1 < hits.count else {
            return nil
        }
        return hits[index + 1]
    }

    private func isResizable(_ outline: WidgetOutline) -> Bool {
        outline.sized && outline.widget.hasSize()
    }

    private func fixedPoint(_ outline: WidgetOutline) -> CGPoint {
        let rect = outline.rect
        let alignment = outline.sceneWidget.layout.alignment
        let x = alignment.isHorizontalCenter() ? rect.midX : alignment.isLeft() ? rect.minX : rect.maxX
        let y = alignment.isVerticalCenter() ? rect.midY : alignment.isTop() ? rect.minY : rect.maxY
        return CGPoint(x: x, y: y)
    }

    private func handlePoint(_ outline: WidgetOutline, _ rect: CGRect) -> CGPoint {
        let alignment = outline.sceneWidget.layout.alignment
        let x = alignment.mirrorPositionHorizontally() ? rect.minX : rect.maxX
        let y = alignment.mirrorPositionVertically() ? rect.minY : rect.maxY
        return CGPoint(x: x, y: y)
    }

    private func startEdit(_ outline: WidgetOutline, _ mode: SceneEditorEditMode) {
        edit = SceneEditorEdit(outline: outline,
                               mode: mode,
                               startSize: outline.sceneWidget.layout.size,
                               rect: outline.rect)
    }

    private func diagonalPosition(_ alignment: SettingsAlignment,
                                  _ size: CGSize,
                                  _ position: CGPoint,
                                  _ threshold: Double) -> CGPoint
    {
        let direction = diagonalDirection(alignment)
        let start = CGPoint(x: alignment.isLeft() ? 0 : canvasSize.width - size.width,
                            y: alignment.isTop() ? 0 : canvasSize.height - size.height)
        let maximum = max(min(canvasSize.width - size.width, canvasSize.height - size.height), 0)
        var offset = ((position.x - start.x) * direction.width + (position.y - start.y) * direction.height) /
            2
        offset = offset.clamped(to: 0 ... maximum)
        if offset < threshold {
            offset = 0
        }
        return CGPoint(x: start.x + direction.width * offset, y: start.y + direction.height * offset)
    }

    private func snapTargetsX(_ outline: WidgetOutline) -> [Double] {
        outline.sized ? [outline.rect.minX, outline.rect.midX, outline.rect.maxX] : [outline.rect.minX]
    }

    private func snapTargetsY(_ outline: WidgetOutline) -> [Double] {
        outline.sized ? [outline.rect.minY, outline.rect.midY, outline.rect.maxY] : [outline.rect.minY]
    }

    private func moveChanged(_ value: DragGesture.Value) {
        if edit == nil {
            guard let outline = selectedOutline else {
                return
            }
            startEdit(outline, .move)
        }
        guard var edit, edit.mode == .move else {
            return
        }
        let delta = canvasDelta(value.translation)
        let rect = edit.outline.rect
        let position = CGPoint(x: rect.minX + delta.width, y: rect.minY + delta.height)
        let layout = edit.outline.sceneWidget.layout
        if movesDiagonally(layout) {
            edit.rect.origin = diagonalPosition(layout.alignment, rect.size, position, snapThreshold)
        } else {
            let others = editableOutlines.filter { $0.id != edit.outline.id }
            let x = snapAxis(position.x,
                             rect.width,
                             canvasSize.width,
                             snapThreshold,
                             edit.outline.sized,
                             others.flatMap(snapTargetsX))
            let y = snapAxis(position.y,
                             rect.height,
                             canvasSize.height,
                             snapThreshold,
                             edit.outline.sized,
                             others.flatMap(snapTargetsY))
            edit.rect.origin = CGPoint(x: x.position, y: y.position)
            edit.snapX = x
            edit.snapY = y
        }
        self.edit = edit
        model.sceneEditorMoveWidget(sceneWidget: edit.outline.sceneWidget,
                                    position: edit.rect.origin,
                                    size: rect.size,
                                    centered: (edit.snapX?.centered ?? false, edit.snapY?.centered ?? false))
    }

    private func resize(factor: Double) {
        guard var edit, edit.mode == .resize else {
            return
        }
        let factors = 1 / edit.startSize ... 100 / edit.startSize
        var factor = factor.clamped(to: factors)
        let rect = edit.outline.rect
        let fixed = fixedPoint(edit.outline)
        let others = editableOutlines.filter { $0.id != edit.outline.id }
        let threshold = snapThreshold / distance(handlePoint(edit.outline, rect), fixed)
        let x = snapResizeAxis([rect.minX, rect.maxX, rect.midX],
                               fixed.x,
                               factor,
                               factors,
                               threshold,
                               [0, canvasSize.width / 2, canvasSize.width] + others.flatMap(snapTargetsX))
        let y = snapResizeAxis([rect.minY, rect.maxY, rect.midY],
                               fixed.y,
                               factor,
                               factors,
                               threshold,
                               [0, canvasSize.height / 2, canvasSize.height] + others.flatMap(snapTargetsY))
        edit.snapX = nil
        edit.snapY = nil
        if let x, x.distance < y?.distance ?? .infinity {
            factor = x.factor
            edit.snapX = SceneEditorSnap(position: x.guide, guide: x.guide)
        } else if let y {
            factor = y.factor
            edit.snapY = SceneEditorSnap(position: y.guide, guide: y.guide)
        }
        edit.rect = CGRect(x: fixed.x + (rect.minX - fixed.x) * factor,
                           y: fixed.y + (rect.minY - fixed.y) * factor,
                           width: rect.width * factor,
                           height: rect.height * factor)
        self.edit = edit
        model.sceneEditorResizeWidget(sceneWidget: edit.outline.sceneWidget, size: edit.startSize * factor)
    }

    private func handleChanged(_ outline: WidgetOutline, _ value: DragGesture.Value) {
        if edit == nil {
            startEdit(outline, .resize)
        }
        guard let outline = edit?.outline else {
            return
        }
        let fixed = fixedPoint(outline)
        let start = handlePoint(outline, outline.rect)
        let delta = canvasDelta(value.translation)
        let current = CGPoint(x: start.x + delta.width, y: start.y + delta.height)
        let startDistance = distance(start, fixed)
        guard startDistance > 0 else {
            return
        }
        resize(factor: distance(current, fixed) / startDistance)
    }

    private func outlineView(_ outline: WidgetOutline) -> some View {
        let selected = outline.id == selectedId
        let rect = viewRect(currentRect(outline))
        let color: Color = selected ? .accentColor : .white
        let selectedFill = Color.accentColor.opacity(0.25)
        let dash: [CGFloat] = outline.inScene && outline.enabled ? [] : [4, 4]
        let dotSize = selected ? 12.0 : 8.0
        return ZStack(alignment: .topLeading) {
            if outline.sized {
                Rectangle()
                    .fill(selected ? selectedFill : .clear)
                    .overlay {
                        Rectangle()
                            .stroke(color, style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: dash))
                    }
                    .frame(width: rect.width, height: rect.height)
                    .offset(x: rect.minX, y: rect.minY)
            } else {
                Circle()
                    .fill(selected ? selectedFill : .clear)
                    .overlay {
                        Circle()
                            .stroke(color, style: StrokeStyle(lineWidth: selected ? 2 : 1,
                                                              dash: selected ? dash : [4, 4]))
                    }
                    .frame(width: 32, height: 32)
                    .offset(x: rect.minX - 16, y: rect.minY - 16)
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: rect.minX - dotSize / 2, y: rect.minY - dotSize / 2)
            }
            WidgetOutlineLabelView(widget: outline.widget)
                .offset(x: rect.minX + 4,
                        y: rect.minY > 24 && !outline.sized ? rect.minY - 24 : rect.minY + 4)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func diagonalGuidePath(_ alignment: SettingsAlignment) -> Path {
        let direction = diagonalDirection(alignment)
        let length = min(canvasSize.width, canvasSize.height)
        let corner = CGPoint(x: alignment.isLeft() ? 0 : canvasSize.width,
                             y: alignment.isTop() ? 0 : canvasSize.height)
        let end = CGPoint(x: corner.x + direction.width * length, y: corner.y + direction.height * length)
        return Path { path in
            path.move(to: viewPoint(corner))
            path.addLine(to: viewPoint(end))
        }
    }

    private func guidesView() -> some View {
        ZStack {
            if let edit {
                if let guideX = edit.snapX?.guide {
                    Path { path in
                        path.move(to: viewPoint(CGPoint(x: guideX, y: 0)))
                        path.addLine(to: viewPoint(CGPoint(x: guideX, y: canvasSize.height)))
                    }
                    .stroke(.yellow, lineWidth: 1)
                }
                if let guideY = edit.snapY?.guide {
                    Path { path in
                        path.move(to: viewPoint(CGPoint(x: 0, y: guideY)))
                        path.addLine(to: viewPoint(CGPoint(x: canvasSize.width, y: guideY)))
                    }
                    .stroke(.yellow, lineWidth: 1)
                }
                let layout = edit.outline.sceneWidget.layout
                if edit.mode == .move, movesDiagonally(layout) {
                    diagonalGuidePath(layout.alignment)
                        .stroke(.yellow, lineWidth: 1)
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func resizeHandleView(_ outline: WidgetOutline) -> some View {
        let point = viewPoint(handlePoint(outline, currentRect(outline)))
        return Circle()
            .fill(Color.accentColor)
            .overlay(Circle().stroke(.white, lineWidth: 2))
            .frame(width: 20, height: 20)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .position(x: point.x, y: point.y)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        handleChanged(outline, value)
                    }
                    .onEnded { _ in
                        edit = nil
                    }
            )
    }

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(coordinateSpace: .local) { location in
                    selection.sceneWidgetId = outlineForTap(at: location)?.id
                }
            ForEach(widgetOutlines.outlines) { outline in
                outlineView(outline)
            }
            guidesView()
            if let selectedOutline, isResizable(selectedOutline), edit?.mode != .move {
                resizeHandleView(selectedOutline)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .gesture(
            DragGesture(minimumDistance: 5)
                .onChanged { value in
                    moveChanged(value)
                }
                .onEnded { _ in
                    edit = nil
                }
        )
    }
}

private struct SceneEditorButtonView: View {
    let image: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role) {
            action()
        } label: {
            Image(systemName: image)
                .font(.title3)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
    }
}

private struct SceneEditorEnableButtonView: View {
    let model: Model
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        SceneEditorButtonView(image: widget.enabled ? "eye" : "eye.slash") {
            model.sceneEditorToggleWidgetEnabled(widget: widget)
        }
    }
}

private struct SceneEditorPopoverRowView: View {
    let image: String
    let text: String
    var checked = false
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            HStack {
                IconAndTextView(image: image, text: text)
                Spacer()
                if checked {
                    Image(systemName: "checkmark")
                }
            }
        }
        .padding(11)
    }
}

private struct SceneEditorPopoverListView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                content()
            }
        }
        .frame(minWidth: 220)
        .padding(5)
        .presentationCompactAdaptation(.none)
    }
}

private struct SceneEditorScenesButtonView: View {
    let model: Model
    @ObservedObject var database: Database
    let scene: SettingsScene?
    let selection: SceneEditorSelection
    @State private var presentingScenes = false

    var body: some View {
        SceneEditorButtonView(image: "photo.on.rectangle") {
            presentingScenes = true
        }
        .popover(isPresented: $presentingScenes) {
            SceneEditorPopoverListView {
                ForEach(database.scenes) { scene in
                    SceneEditorPopoverRowView(image: scene.enabled ? "photo.on.rectangle" : "eye.slash",
                                              text: scene.name,
                                              checked: scene === self.scene)
                    {
                        let widgetId = self.scene?.widgets
                            .first(where: { $0.id == selection.sceneWidgetId })?.widgetId
                        selection.sceneWidgetId = scene.widgets.first(where: { $0.widgetId == widgetId })?.id
                        model.sceneEditorSelectScene(id: scene.id)
                        presentingScenes = false
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
    }
}

private struct SceneEditorAddWidgetButtonView: View {
    let model: Model
    @ObservedObject var database: Database
    let scene: SettingsScene
    let selection: SceneEditorSelection
    @State private var presentingAddWidget = false
    @State private var presentingCreateWizard = false

    var body: some View {
        SceneEditorButtonView(image: "plus") {
            presentingAddWidget = true
        }
        .popover(isPresented: $presentingAddWidget) {
            SceneEditorPopoverListView {
                SceneEditorPopoverRowView(
                    image: "plus.square.dashed",
                    text: String(localized: "Create widget")
                ) {
                    presentingAddWidget = false
                    model.createWidgetWizard.reset(scene: scene)
                    presentingCreateWizard = true
                }
                Divider()
                ForEach(database.widgets) { widget in
                    SceneEditorPopoverRowView(image: widget.image(), text: widget.name) {
                        model.appendWidgetToScene(scene: scene, widget: widget)
                        model.sceneSettingsPanelSceneId += 1
                        selection.sceneWidgetId = scene.widgets.last?.id
                        presentingAddWidget = false
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .sheet(isPresented: $presentingCreateWizard) {
            WidgetWizardSheetView(model: model,
                                  database: database,
                                  presentingCreateWizard: $presentingCreateWizard)
        }
    }
}

private struct SceneEditorToolbarView: View {
    let model: Model
    let database: Database
    let scene: SettingsScene?
    let selected: SceneEditorSelectedWidget?
    let selection: SceneEditorSelection
    let vertical: Bool
    @State private var presentingRemoveWidgetConfirmation = false

    @ViewBuilder
    private func widgetButtons(_ scene: SettingsScene, _ selected: SceneEditorSelectedWidget) -> some View {
        let sceneWidget = selected.sceneWidget
        let widget = selected.widget
        SceneEditorEnableButtonView(model: model, widget: widget)
        SceneEditorButtonView(image: "square.2.layers.3d.top.filled") {
            model.sceneEditorMoveWidgetInDrawOrder(scene: scene, sceneWidget: sceneWidget, up: true)
        }
        SceneEditorButtonView(image: "square.2.layers.3d.bottom.filled") {
            model.sceneEditorMoveWidgetInDrawOrder(scene: scene, sceneWidget: sceneWidget, up: false)
        }
        SceneEditorButtonView(image: "slider.horizontal.3") {
            selection.showingSettings.toggle()
        }
        SceneEditorButtonView(image: "trash", role: .destructive) {
            presentingRemoveWidgetConfirmation = true
        }
        .foregroundStyle(.red)
        .confirmationDialog(
            String(localized: "Remove widget \(widget.name) from scene \(scene.name)?"),
            isPresented: $presentingRemoveWidgetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove", role: .destructive) {
                model.sceneEditorRemoveWidget(scene: scene, sceneWidget: sceneWidget)
                selection.sceneWidgetId = nil
            }
        }
    }

    private func divider() -> some View {
        Divider()
            .background(.gray)
            .frame(width: vertical ? 32 : nil, height: vertical ? nil : 32)
    }

    @ViewBuilder
    private func buttons() -> some View {
        SceneEditorButtonView(image: "xmark") {
            model.presentingSceneEditor = false
        }
        divider()
        SceneEditorScenesButtonView(model: model, database: database, scene: scene, selection: selection)
        if let scene {
            if let selected {
                divider()
                widgetButtons(scene, selected)
            } else {
                SceneEditorAddWidgetButtonView(model: model,
                                               database: database,
                                               scene: scene,
                                               selection: selection)
            }
        }
    }

    var body: some View {
        let layout = vertical ? AnyLayout(VStackLayout(spacing: 2)) : AnyLayout(HStackLayout(spacing: 2))
        ScrollView(vertical ? .vertical : .horizontal, showsIndicators: false) {
            layout {
                buttons()
            }
        }
        .frame(width: vertical ? 52 : nil, height: vertical ? nil : 52)
    }
}

struct SceneEditorView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneSelector: SceneSelector
    @ObservedObject var widgetOutlines: WidgetOutlines
    @ObservedObject var streamOverlay: StreamOverlay
    @ObservedObject var sceneEditor: SceneEditor
    @StateObject private var selection = SceneEditorSelection()

    private func mirror(_ scene: SettingsScene?) -> Bool {
        guard !database.mirrorFrontCameraOnStream else {
            return false
        }
        if let scene, !scene.enabled {
            return scene.videoSource.cameraPosition == .front
        }
        return streamOverlay.isFrontCameraSelected
    }

    private func fitSize(_ available: CGSize) -> CGSize {
        let canvasSize = widgetOutlines.canvasSize
        guard available.width > 0, available.height > 0, canvasSize.width > 0, canvasSize.height > 0 else {
            return .zero
        }
        let scale = min(available.width / canvasSize.width, available.height / canvasSize.height)
        return CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    private func selectedWidget(_ scene: SettingsScene?) -> SceneEditorSelectedWidget? {
        guard let sceneWidget = scene?.widgets.first(where: { $0.id == selection.sceneWidgetId }),
              let widget = model.findWidget(id: sceneWidget.widgetId)
        else {
            return nil
        }
        return SceneEditorSelectedWidget(sceneWidget: sceneWidget, widget: widget)
    }

    private func videoArea(_ scene: SettingsScene?) -> some View {
        GeometryReader { metrics in
            let size = fitSize(CGSize(width: metrics.size.width - 16, height: metrics.size.height - 16))
            ZStack {
                StreamPreviewView(model: model, sceneEditor: true)
                if let scene, !scene.enabled {
                    Color.black
                    Text("Disabled scene")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(4)
                        .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
                }
                SceneEditorCanvasView(model: model,
                                      widgetOutlines: widgetOutlines,
                                      mirror: mirror(scene),
                                      size: size,
                                      selection: selection)
            }
            .frame(width: size.width, height: size.height)
            .border(.gray.opacity(0.5))
            .position(x: metrics.size.width / 2, y: metrics.size.height / 2)
        }
    }

    private func settingsPanel(_ selected: SceneEditorSelectedWidget) -> some View {
        NavigationStack {
            SceneWidgetSettingsView(model: model,
                                    database: database,
                                    sceneWidget: selected.sceneWidget,
                                    widget: selected.widget)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            selection.showingSettings = false
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
        }
        .id(selected.sceneWidget.id)
    }

    var body: some View {
        GeometryReader { metrics in
            let scene = model.sceneEditorScene()
            let selected = selectedWidget(scene)
            let landscape = metrics.size.width > metrics.size.height
            let layout = landscape ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0))
            layout {
                videoArea(scene)
                if selection.showingSettings, let selected {
                    settingsPanel(selected)
                        .frame(width: landscape ? settingsHalfWidth : nil,
                               height: landscape ? nil : metrics.size.height * 0.45)
                }
                SceneEditorToolbarView(model: model,
                                       database: database,
                                       scene: scene,
                                       selected: selected,
                                       selection: selection,
                                       vertical: landscape)
            }
        }
        .background(.black)
        .onAppear {
            model.sceneEditorPresentationChanged()
        }
    }
}
