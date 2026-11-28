import SwiftUI

private enum SceneEditorEditMode {
    case move
    case resize
}

private struct SceneEditorEdit {
    let outline: WidgetOutline
    let mode: SceneEditorEditMode
    let anchor: SettingsAlignment
    let startSize: Double
    var rect: CGRect
    var guideX: Double?
    var guideY: Double?
}

private class SceneEditorSelection: ObservableObject {
    @Published var sceneWidgetId: UUID?
    @Published var showingSettings = false
}

private func stackLayout(vertical: Bool, spacing: CGFloat) -> AnyLayout {
    vertical ? AnyLayout(VStackLayout(spacing: spacing)) : AnyLayout(HStackLayout(spacing: spacing))
}

private var toolbarTint: Color? {
    if #available(iOS 26, *) {
        .primary
    } else {
        nil
    }
}

private func distance(_ first: CGPoint, _ second: CGPoint) -> Double {
    hypot(first.x - second.x, first.y - second.y)
}

private func widgetOutlineViewRect(_ rect: CGRect, _ canvasSize: CGSize, _ mirror: Bool,
                                   _ size: CGSize) -> CGRect
{
    let scale = canvasSize.width / size.width
    let x = mirror ? canvasSize.width - rect.maxX : rect.minX
    return CGRect(x: x / scale,
                  y: rect.minY / scale,
                  width: rect.width / scale,
                  height: rect.height / scale)
}

private struct KeepInsideLayout: Layout {
    let position: CGPoint

    func sizeThatFits(proposal: ProposedViewSize, subviews _: Subviews, cache _: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect,
                       proposal _: ProposedViewSize,
                       subviews: Subviews,
                       cache _: inout ())
    {
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let x = min(max(position.x, 0), max(bounds.width - size.width, 0))
            let y = min(max(position.y, 0), max(bounds.height - size.height, 0))
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
        }
    }
}

private struct WidgetOutlineLabelView: View {
    @ObservedObject var widget: SettingsWidget
    var selected = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: widget.image())
            Text(widget.name)
                .lineLimit(1)
        }
        .font(.footnote)
        .fontWeight(selected ? .semibold : .regular)
        .foregroundStyle(.white)
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(selected ? Color.accentColor : .black.opacity(0.6))
        .cornerRadius(3)
        .fixedSize()
    }
}

private struct SceneEditorCanvasView: View {
    let model: Model
    @ObservedObject var sceneEditor: SceneEditor
    let mirror: Bool
    let size: CGSize
    @ObservedObject var selection: SceneEditorSelection
    @State private var edit: SceneEditorEdit?
    @State private var lastTapLocation: CGPoint?

    private var selectedId: UUID? {
        selection.sceneWidgetId
    }

    private var canvasSize: CGSize {
        sceneEditor.canvasSize
    }

    private var scale: Double {
        canvasSize.width / size.width
    }

    private var snapThreshold: Double {
        4 * scale
    }

    private var editableOutlines: [WidgetOutline] {
        sceneEditor.outlines.filter(\.inScene)
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
        let alignment = outline.alignment
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

    private func selectOutline(at location: CGPoint) {
        let sameLocation = lastTapLocation.map { distance($0, location) < 10 } ?? false
        lastTapLocation = location
        selection.sceneWidgetId = sceneEditorTapSelection(outlines(at: location).map(\.id),
                                                          selectedId,
                                                          sameLocation)
    }

    private func isResizable(_ outline: WidgetOutline) -> Bool {
        outline.sized && outline.widget.hasSize()
    }

    private func startEdit(
        _ outline: WidgetOutline,
        _ mode: SceneEditorEditMode,
        _ anchor: SettingsAlignment
    ) {
        edit = SceneEditorEdit(outline: outline,
                               mode: mode,
                               anchor: anchor,
                               startSize: outline.sceneWidget.layout.size,
                               rect: outline.rect)
    }

    private func snapTargetsX(_ outline: WidgetOutline) -> [Double] {
        outline.sized ? [outline.rect.minX, outline.rect.midX, outline.rect.maxX] : [outline.rect.minX]
    }

    private func snapTargetsY(_ outline: WidgetOutline) -> [Double] {
        outline.sized ? [outline.rect.minY, outline.rect.midY, outline.rect.maxY] : [outline.rect.minY]
    }

    private func moveChanged(_ value: DragGesture.Value) {
        if edit == nil {
            guard let outline = selectedOutline, outline.widget.hasPosition() else {
                return
            }
            startEdit(outline, .move, outline.alignment)
        }
        guard var edit, edit.mode == .move else {
            return
        }
        let delta = canvasDelta(value.translation)
        let rect = edit.outline.rect
        let position = CGPoint(x: rect.minX + delta.width, y: rect.minY + delta.height)
        let others = sceneEditor.outlines.filter { $0.id != edit.outline.id }
        let x = sceneEditorSnapAxis(position.x,
                                    rect.width,
                                    canvasSize.width,
                                    snapThreshold,
                                    others.flatMap(snapTargetsX))
        let y = sceneEditorSnapAxis(position.y,
                                    rect.height,
                                    canvasSize.height,
                                    snapThreshold,
                                    others.flatMap(snapTargetsY))
        edit.rect.origin = CGPoint(x: x.position, y: y.position)
        edit.guideX = x.guide
        edit.guideY = y.guide
        self.edit = edit
        model.sceneEditorMoveWidget(sceneWidget: edit.outline.sceneWidget, rect: edit.rect)
    }

    private func resize(factor: Double) {
        guard var edit, edit.mode == .resize else {
            return
        }
        let rect = edit.outline.rect
        let fixed = sceneEditorFixedPoint(rect, edit.outline.alignment, edit.anchor)
        let factors = 1 / edit.startSize ... 100 / edit.startSize
        var factor = factor.clamped(to: factors)
        let others = sceneEditor.outlines.filter { $0.id != edit.outline.id }
        let threshold = snapThreshold / distance(sceneEditorHandlePoint(rect, edit.anchor), fixed)
        let x = sceneEditorSnapResizeAxis([rect.minX, rect.maxX, rect.midX],
                                          fixed.x,
                                          factor,
                                          factors,
                                          threshold,
                                          [0, canvasSize.width / 2, canvasSize.width] + others
                                              .flatMap(snapTargetsX))
        let y = sceneEditorSnapResizeAxis([rect.minY, rect.maxY, rect.midY],
                                          fixed.y,
                                          factor,
                                          factors,
                                          threshold,
                                          [0, canvasSize.height / 2, canvasSize.height] + others
                                              .flatMap(snapTargetsY))
        edit.guideX = nil
        edit.guideY = nil
        if let x, x.distance < y?.distance ?? .infinity {
            factor = x.factor
            edit.guideX = x.guide
        } else if let y {
            factor = y.factor
            edit.guideY = y.guide
        }
        edit.rect = sceneEditorResizedRect(rect, fixed, factor)
        self.edit = edit
        model.sceneEditorResizeWidget(sceneWidget: edit.outline.sceneWidget,
                                      size: edit.startSize * factor,
                                      rect: edit.rect)
    }

    private func handleChanged(_ outline: WidgetOutline,
                               _ anchor: SettingsAlignment,
                               _ value: DragGesture.Value)
    {
        if edit == nil {
            startEdit(outline, .resize, anchor)
        }
        guard let edit else {
            return
        }
        let outline = edit.outline
        let fixed = sceneEditorFixedPoint(outline.rect, outline.alignment, edit.anchor)
        let start = sceneEditorHandlePoint(outline.rect, edit.anchor)
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
        let color: Color = selected ? .accentColor : outline.inScene ? .white : .gray
        let selectedFill = Color.accentColor.opacity(0.25)
        let dash: [CGFloat] = outline.inScene && outline.enabled ? [] : [4, 4]
        let dotSize = selected ? 12.0 : 8.0
        return ZStack(alignment: .topLeading) {
            if outline.sized {
                Rectangle()
                    .fill(selected ? selectedFill : outline.widget.type == .scene ? .white
                        .opacity(0.1) : .clear)
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
                            .stroke(color, style: StrokeStyle(lineWidth: selected ? 2 : 1, dash: dash))
                    }
                    .frame(width: 32, height: 32)
                    .offset(x: rect.minX - 16, y: rect.minY - 16)
                Circle()
                    .fill(color)
                    .frame(width: dotSize, height: dotSize)
                    .offset(x: rect.minX - dotSize / 2, y: rect.minY - dotSize / 2)
            }
            KeepInsideLayout(position: CGPoint(
                x: rect.minX + 4,
                y: rect.minY > 24 && !outline.sized ? rect.minY - 24 : rect.minY + 4
            )) {
                WidgetOutlineLabelView(widget: outline.widget, selected: selected)
            }
            .frame(width: size.width, height: size.height)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
    }

    private func guideLine(_ start: CGPoint, _ end: CGPoint) -> some View {
        Path { path in
            path.move(to: viewPoint(start))
            path.addLine(to: viewPoint(end))
        }
        .stroke(.yellow, lineWidth: 1)
    }

    private func guidesView() -> some View {
        ZStack {
            if let edit {
                if let guideX = edit.guideX {
                    guideLine(CGPoint(x: guideX, y: 0), CGPoint(x: guideX, y: canvasSize.height))
                }
                if let guideY = edit.guideY {
                    guideLine(CGPoint(x: 0, y: guideY), CGPoint(x: canvasSize.width, y: guideY))
                }
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }

    private func resizeHandleView(_ outline: WidgetOutline, _ anchor: SettingsAlignment) -> some View {
        let point = viewPoint(sceneEditorHandlePoint(currentRect(outline), anchor))
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
                        handleChanged(outline, anchor, value)
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
                    selectOutline(at: location)
                }
            ForEach(sceneEditor.outlines.filter { $0.id != selectedId }) { outline in
                outlineView(outline)
            }
            if let outline = sceneEditor.outlines.first(where: { $0.id == selectedId }) {
                outlineView(outline)
            }
            guidesView()
            if let selectedOutline, isResizable(selectedOutline), edit?.mode != .move {
                ForEach([SettingsAlignment.topLeft, .topRight, .bottomLeft, .bottomRight],
                        id: \.self)
                { anchor in
                    resizeHandleView(selectedOutline, anchor)
                }
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
    var disabled = false
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
        .disabled(disabled)
        .tint(toolbarTint)
    }
}

private struct SceneEditorButtonGroupView<Content: View>: View {
    let vertical: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        if #available(iOS 26, *) {
            let layout = stackLayout(vertical: vertical, spacing: 0)
            layout {
                content()
            }
            .glassEffect()
        } else {
            let layout = stackLayout(vertical: vertical, spacing: 2)
            layout {
                content()
            }
        }
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

private struct SceneEditorDrawOrderButtonsView: View {
    let model: Model
    @ObservedObject var scene: SettingsScene
    let sceneWidget: SettingsSceneWidget

    var body: some View {
        SceneEditorButtonView(image: "square.2.layers.3d.top.filled",
                              disabled: !model.sceneEditorCanMoveWidgetInDrawOrder(scene: scene,
                                                                                   sceneWidget: sceneWidget,
                                                                                   up: true))
        {
            model.sceneEditorMoveWidgetInDrawOrder(scene: scene, sceneWidget: sceneWidget, up: true)
        }
        SceneEditorButtonView(image: "square.2.layers.3d.bottom.filled",
                              disabled: !model.sceneEditorCanMoveWidgetInDrawOrder(scene: scene,
                                                                                   sceneWidget: sceneWidget,
                                                                                   up: false))
        {
            model.sceneEditorMoveWidgetInDrawOrder(scene: scene, sceneWidget: sceneWidget, up: false)
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

private struct SceneEditorPopoverTitleView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 4)
    }
}

private struct SceneEditorPopoverCreateRowView: View {
    let text: String
    let action: () -> Void

    var body: some View {
        SceneEditorPopoverRowView(image: "plus", text: text, action: action)
            .padding(.horizontal, 5)
    }
}

private struct SceneEditorPopoverListView<Content: View, Footer: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    var body: some View {
        VStack(spacing: 0) {
            SceneEditorPopoverTitleView(text: title)
            ScrollView {
                VStack(spacing: 0) {
                    content()
                }
                .padding(.horizontal, 5)
            }
            footer()
        }
        .padding(.bottom, 5)
        .frame(minWidth: 220)
        .presentationCompactAdaptation(.none)
    }
}

extension SceneEditorPopoverListView where Footer == EmptyView {
    init(title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
        footer = { EmptyView() }
    }
}

private struct SceneEditorScenesButtonView: View {
    let model: Model
    @ObservedObject var database: Database
    let scene: SettingsScene?
    let selection: SceneEditorSelection
    @State private var presentingScenes = false
    @State private var presentingCreateWizard = false

    var body: some View {
        SceneEditorButtonView(image: "photo.on.rectangle") {
            presentingScenes = true
        }
        .popover(isPresented: $presentingScenes) {
            SceneEditorPopoverListView(title: String(localized: "Switch to scene")) {
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
            } footer: {
                SceneEditorPopoverCreateRowView(text: String(localized: "Create scene")) {
                    presentingScenes = false
                    model.createSceneWizard.reset()
                    presentingCreateWizard = true
                }
            }
        }
        .sheet(isPresented: $presentingCreateWizard) {
            SceneWizardSheetView(model: model,
                                 database: database,
                                 presentingCreateWizard: $presentingCreateWizard)
            { scene in
                selection.sceneWidgetId = nil
                model.sceneEditorSelectScene(id: scene.id)
            }
        }
    }
}

private struct SceneEditorEnableSceneButtonView: View {
    let model: Model
    @ObservedObject var scene: SettingsScene

    var body: some View {
        SceneEditorButtonView(image: scene.enabled ? "eye" : "eye.slash") {
            model.sceneEditorToggleSceneEnabled(scene: scene)
        }
    }
}

private struct SceneEditorDeleteSceneButtonView: View {
    let model: Model
    let scene: SettingsScene
    let selection: SceneEditorSelection
    @State private var presentingDeleteSceneConfirmation = false

    var body: some View {
        SceneEditorButtonView(image: "trash", role: .destructive) {
            presentingDeleteSceneConfirmation = true
        }
        .foregroundStyle(.red)
        .confirmationDialog(
            String(localized: "Delete scene \(scene.name)?"),
            isPresented: $presentingDeleteSceneConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                selection.sceneWidgetId = nil
                model.deleteScene(scene: scene)
            }
        }
    }
}

private struct SceneEditorSelectWidgetButtonView: View {
    @ObservedObject var sceneEditor: SceneEditor
    let selection: SceneEditorSelection
    @State private var presentingWidgets = false

    var body: some View {
        let outlines = sceneEditor.outlines.filter(\.inScene)
        SceneEditorButtonView(image: "list.bullet", disabled: outlines.isEmpty) {
            presentingWidgets = true
        }
        .popover(isPresented: $presentingWidgets) {
            SceneEditorPopoverListView(title: String(localized: "Select widget")) {
                ForEach(outlines) { outline in
                    SceneEditorPopoverRowView(image: outline.widget.image(), text: outline.widget.name) {
                        selection.sceneWidgetId = outline.id
                        presentingWidgets = false
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
            SceneEditorPopoverListView(title: String(localized: "Add widget to scene")) {
                let widgets = model.addableWidgets(scene: scene)
                if widgets.isEmpty {
                    Text("All widgets are already in this scene.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(11)
                }
                ForEach(widgets) { widget in
                    SceneEditorPopoverRowView(image: widget.image(), text: widget.name) {
                        model.appendWidgetToScene(scene: scene, widget: widget)
                        model.sceneSettingsPanelSceneId += 1
                        selection.sceneWidgetId = scene.widgets.last?.id
                        presentingAddWidget = false
                    }
                    .foregroundStyle(.primary)
                }
            } footer: {
                SceneEditorPopoverCreateRowView(text: String(localized: "Create widget")) {
                    presentingAddWidget = false
                    model.createWidgetWizard.reset(scene: scene)
                    presentingCreateWizard = true
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
    let selected: WidgetOutline?
    let selection: SceneEditorSelection
    let vertical: Bool
    @State private var presentingRemoveWidgetConfirmation = false

    private func group(@ViewBuilder content: @escaping () -> some View) -> some View {
        SceneEditorButtonGroupView(vertical: vertical, content: content)
    }

    @ViewBuilder
    private func widgetButtons(_ scene: SettingsScene, _ selected: WidgetOutline) -> some View {
        let sceneWidget = selected.sceneWidget
        let widget = selected.widget
        SceneEditorEnableButtonView(model: model, widget: widget)
        SceneEditorDrawOrderButtonsView(model: model, scene: scene, sceneWidget: sceneWidget)
        SceneEditorButtonView(image: "slider.horizontal.3") {
            selection.showingSettings.toggle()
        }
        SceneEditorButtonView(image: "trash", role: .destructive) {
            presentingRemoveWidgetConfirmation = true
        }
        .foregroundStyle(.red)
        .confirmationDialog(
            widget.name,
            isPresented: $presentingRemoveWidgetConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove widget from scene", role: .destructive) {
                model.sceneEditorRemoveWidget(scene: scene, sceneWidget: sceneWidget)
                selection.sceneWidgetId = nil
            }
            Button("Delete widget", role: .destructive) {
                selection.sceneWidgetId = nil
                model.deleteWidget(widget: widget)
            }
        }
    }

    @ViewBuilder
    private func separator() -> some View {
        if #unavailable(iOS 26) {
            Divider()
                .background(.gray)
                .frame(width: vertical ? 32 : nil, height: vertical ? nil : 32)
        }
    }

    @ViewBuilder
    private func buttons() -> some View {
        group {
            SceneEditorButtonView(image: "xmark") {
                model.presentingSceneEditor = false
            }
        }
        separator()
        group {
            SceneEditorScenesButtonView(model: model, database: database, scene: scene, selection: selection)
        }
        if let scene {
            if let selected {
                separator()
                group {
                    widgetButtons(scene, selected)
                }
            } else {
                group {
                    SceneEditorEnableSceneButtonView(model: model, scene: scene)
                    SceneEditorAddWidgetButtonView(model: model,
                                                   database: database,
                                                   scene: scene,
                                                   selection: selection)
                    SceneEditorSelectWidgetButtonView(sceneEditor: model.sceneEditor, selection: selection)
                    SceneEditorButtonView(image: "slider.horizontal.3") {
                        selection.showingSettings.toggle()
                    }
                    SceneEditorDeleteSceneButtonView(model: model, scene: scene, selection: selection)
                }
            }
        }
    }

    var body: some View {
        ScrollView(vertical ? .vertical : .horizontal) {
            if #available(iOS 26, *) {
                let layout = stackLayout(vertical: vertical, spacing: 8)
                GlassEffectContainer(spacing: 8) {
                    layout {
                        buttons()
                    }
                }
                .padding(4)
            } else {
                let layout = stackLayout(vertical: vertical, spacing: 2)
                layout {
                    buttons()
                }
                .padding(4)
            }
        }
        .scrollBounceBehavior(.basedOnSize, axes: vertical ? .vertical : .horizontal)
        .frame(width: vertical ? 52 : nil, height: vertical ? nil : 52)
    }
}

struct SceneEditorView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var sceneSelector: SceneSelector
    @ObservedObject var streamOverlay: StreamOverlay
    @ObservedObject var sceneEditor: SceneEditor
    @ObservedObject var orientation: Orientation
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
        let canvasSize = sceneEditor.canvasSize
        guard available.width > 0, available.height > 0, canvasSize.width > 0, canvasSize.height > 0 else {
            return .zero
        }
        let scale = min(available.width / canvasSize.width, available.height / canvasSize.height)
        return CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
    }

    private func selectedOutline() -> WidgetOutline? {
        sceneEditor.outlines.first(where: { $0.id == selection.sceneWidgetId && $0.inScene })
    }

    private func videoArea(_ scene: SettingsScene?) -> some View {
        GeometryReader { metrics in
            let size = fitSize(CGSize(width: metrics.size.width - 16, height: metrics.size.height - 16))
            ZStack {
                StreamPreviewView(model: model, sceneEditor: true)
                if let scene, !scene.enabled {
                    Color.black
                    Text("Disabled scene")
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(4)
                        .frame(width: size.width, height: size.height, alignment: .bottomTrailing)
                }
                SceneEditorCanvasView(model: model,
                                      sceneEditor: sceneEditor,
                                      mirror: mirror(scene),
                                      size: size,
                                      selection: selection)
            }
            .frame(width: size.width, height: size.height)
            .border(.gray.opacity(0.5))
            .position(x: metrics.size.width / 2, y: metrics.size.height / 2)
        }
    }

    private func settingsPanel(_ scene: SettingsScene?, _ selected: WidgetOutline?) -> some View {
        ZStack(alignment: .topTrailing) {
            NavigationStack {
                Group {
                    if let selected {
                        SceneWidgetSettingsView(model: model,
                                                database: database,
                                                sceneWidget: selected.sceneWidget,
                                                widget: selected.widget,
                                                size: selected.rect.size)
                    } else if let scene {
                        SceneSettingsView(database: database, scene: scene)
                    } else {
                        Text("No scene selected")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
            }
            .id(selected?.sceneWidget.id ?? scene?.id)
            CloseButtonView {
                selection.showingSettings = false
            }
        }
    }

    var body: some View {
        let scene = model.sceneEditorScene()
        let selected = selectedOutline()
        let portrait = orientation.isPortrait
        let layout = stackLayout(vertical: portrait, spacing: 0)
        layout {
            videoArea(scene)
            if selection.showingSettings {
                settingsPanel(scene, selected)
                    .frame(width: portrait ? nil : settingsHalfWidth)
            }
            SceneEditorToolbarView(model: model,
                                   database: database,
                                   scene: scene,
                                   selected: selected,
                                   selection: selection,
                                   vertical: !portrait)
        }
        .onAppear {
            model.sceneEditorPresentationChanged()
        }
    }
}
