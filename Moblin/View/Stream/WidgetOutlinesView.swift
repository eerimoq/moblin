import SwiftUI

private struct WidgetOutlineLabelView: View {
    @ObservedObject var widget: SettingsWidget

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: widget.image())
            Text(widget.name)
                .lineLimit(1)
        }
        .font(.caption2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.black.opacity(0.6))
        .cornerRadius(3)
        .fixedSize()
    }
}

private struct WidgetOutlineView: View {
    let outline: WidgetOutline
    let canvasSize: CGSize
    let mirror: Bool
    let size: CGSize

    private func labelOutside(_ rect: CGRect, _ leading: Bool) -> some View {
        let above = rect.minY > 20
        let alignment: Alignment = switch (above, leading) {
        case (true, true):
            .topLeading
        case (true, false):
            .topTrailing
        case (false, true):
            .bottomLeading
        case (false, false):
            .bottomTrailing
        }
        return WidgetOutlineLabelView(widget: outline.widget)
            .alignmentGuide(above ? .top : .bottom) { dimensions in
                above ? dimensions[.bottom] + 4 : dimensions[.top] - 4
            }
            .frame(width: rect.width, height: rect.height, alignment: alignment)
    }

    private func sizedView(_ rect: CGRect) -> some View {
        Rectangle()
            .stroke(.white, style: StrokeStyle(lineWidth: 1, dash: outline.inScene ? [] : [4, 4]))
            .frame(width: rect.width, height: rect.height)
            .overlay {
                if rect.width >= 120, rect.height >= 40 {
                    WidgetOutlineLabelView(widget: outline.widget)
                        .padding(4)
                        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
                } else {
                    labelOutside(rect, true)
                }
            }
            .position(x: rect.midX, y: rect.midY)
    }

    private func anchorView(_ rect: CGRect) -> some View {
        let leading = outline.sceneWidget.layout.alignment.isLeft() != mirror
        return Circle()
            .fill(.white)
            .frame(width: 8, height: 8)
            .overlay {
                labelOutside(rect, leading)
            }
            .position(x: rect.minX, y: rect.minY)
    }

    var body: some View {
        let scale = canvasSize.width / size.width
        let x = mirror ? canvasSize.width - outline.rect.maxX : outline.rect.minX
        let rect = CGRect(x: x / scale,
                          y: outline.rect.minY / scale,
                          width: outline.rect.width / scale,
                          height: outline.rect.height / scale)
        Group {
            if outline.sized {
                sizedView(rect)
            } else {
                anchorView(rect)
            }
        }
        .foregroundStyle(.white)
    }
}

private struct WidgetOutlinesModifier: ViewModifier {
    let model: Model
    let show: Bool

    func body(content: Content) -> some View {
        content.onAppear {
            if show {
                model.showWidgetOutlines()
            } else {
                model.hideWidgetOutlines()
            }
        }
    }
}

extension View {
    func showWidgetOutlines(model: Model) -> some View {
        modifier(WidgetOutlinesModifier(model: model, show: true))
    }

    func hideWidgetOutlines(model: Model) -> some View {
        modifier(WidgetOutlinesModifier(model: model, show: false))
    }
}

struct WidgetOutlinesView: View {
    @ObservedObject var widgetOutlines: WidgetOutlines
    @ObservedObject var database: Database
    @ObservedObject var streamOverlay: StreamOverlay
    let size: CGSize

    var body: some View {
        if widgetOutlines.enabled {
            let mirror = streamOverlay.isFrontCameraSelected && !database.mirrorFrontCameraOnStream
            ZStack {
                ForEach(widgetOutlines.outlines) { outline in
                    WidgetOutlineView(outline: outline,
                                      canvasSize: widgetOutlines.canvasSize,
                                      mirror: mirror,
                                      size: size)
                }
            }
            .frame(width: size.width, height: size.height)
            .allowsHitTesting(false)
        }
    }
}
