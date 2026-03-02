import SwiftUI

private struct SceneEditModeWidgetView: View {
    let model: Model
    @ObservedObject var sceneWidget: SettingsSceneWidget
    let widget: SettingsWidget
    let viewSize: CGSize
    let streamSize: CGSize
    @State private var dragStartX: Double = 0
    @State private var dragStartY: Double = 0
    @State private var resizeStartSize: Double = 0

    private func widgetRect() -> CGRect {
        let layout = sceneWidget.layout
        let widgetWidth = toPixels(layout.size, Double(streamSize.width)) /
            Double(streamSize.width) * viewSize.width
        let widgetHeight = toPixels(layout.size, Double(streamSize.height)) /
            Double(streamSize.height) * viewSize.height
        let displaySize = min(widgetWidth, widgetHeight)

        let x: Double
        if layout.alignment.isHorizontalCenter() {
            x = (viewSize.width - displaySize) / 2
        } else if layout.alignment.isLeft() {
            x = toPixels(layout.x, viewSize.width)
        } else {
            x = viewSize.width - toPixels(layout.x, viewSize.width) - displaySize
        }

        let y: Double
        if layout.alignment.isVerticalCenter() {
            y = (viewSize.height - displaySize) / 2
        } else if layout.alignment.isTop() {
            y = toPixels(layout.y, viewSize.height)
        } else {
            y = viewSize.height - toPixels(layout.y, viewSize.height) - displaySize
        }

        return CGRect(x: x, y: y, width: displaySize, height: displaySize)
    }

    private func clampPosition(_ value: Double) -> Double {
        return min(max(value, 0), 100)
    }

    private func clampSize(_ value: Double) -> Double {
        return min(max(value, 1), 100)
    }

    var body: some View {
        let rect = widgetRect()
        ZStack(alignment: .bottomTrailing) {
            Rectangle()
                .stroke(Color.red, lineWidth: 2)
                .frame(width: rect.width, height: rect.height)
                .contentShape(Rectangle())
            Rectangle()
                .fill(Color.red.opacity(0.6))
                .frame(width: 20, height: 20)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation == .zero {
                                resizeStartSize = sceneWidget.layout.size
                            }
                            let delta = max(value.translation.width, value.translation.height)
                            let startDisplayWidth = toPixels(
                                resizeStartSize,
                                Double(streamSize.width)
                            ) / Double(streamSize.width) * viewSize.width
                            let newSizePct = (startDisplayWidth + delta) /
                                viewSize.width * 100
                            sceneWidget.layout.size = clampSize(newSizePct)
                            sceneWidget.layout.updateSizeString()
                        }
                        .onEnded { _ in
                            model.sceneUpdated()
                        }
                )
        }
        .position(x: rect.midX, y: rect.midY)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation == .zero {
                        dragStartX = sceneWidget.layout.x
                        dragStartY = sceneWidget.layout.y
                    }
                    let layout = sceneWidget.layout

                    if !layout.alignment.isHorizontalCenter() {
                        let deltaPct = value.translation.width / viewSize.width * 100
                        let newX: Double
                        if layout.alignment.isLeft() {
                            newX = dragStartX + deltaPct
                        } else {
                            newX = dragStartX - deltaPct
                        }
                        sceneWidget.layout.x = clampPosition(newX)
                        sceneWidget.layout.updateXString()
                    }

                    if !layout.alignment.isVerticalCenter() {
                        let deltaPct = value.translation.height / viewSize.height * 100
                        let newY: Double
                        if layout.alignment.isTop() {
                            newY = dragStartY + deltaPct
                        } else {
                            newY = dragStartY - deltaPct
                        }
                        sceneWidget.layout.y = clampPosition(newY)
                        sceneWidget.layout.updateYString()
                    }
                }
                .onEnded { _ in
                    model.sceneUpdated()
                }
        )
    }
}

private struct SceneEditModeCanvasView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            VStack {
                if !stream.portrait {
                    Spacer(minLength: 0)
                }
                GeometryReader { metrics in
                    let streamDimensions = stream.dimensions()
                    let streamSize = CGSize(
                        width: Double(streamDimensions.width),
                        height: Double(streamDimensions.height)
                    )
                    let widgets = model.widgetsInCurrentScene(onlyEnabled: false)
                    ZStack {
                        Color.clear
                        ForEach(widgets) { widgetInScene in
                            if widgetInScene.widget.hasPosition() ||
                                widgetInScene.widget.hasSize()
                            {
                                SceneEditModeWidgetView(
                                    model: model,
                                    sceneWidget: widgetInScene.sceneWidget,
                                    widget: widgetInScene.widget,
                                    viewSize: metrics.size,
                                    streamSize: streamSize
                                )
                            }
                        }
                    }
                }
                .aspectRatio(stream.dimensions().aspectRatio(), contentMode: .fit)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .ignoresSafeArea()
        .edgesIgnoringSafeArea(.all)
    }
}

struct SceneEditModeView: View {
    let model: Model

    var body: some View {
        SceneEditModeCanvasView(model: model, stream: model.stream)
    }
}
