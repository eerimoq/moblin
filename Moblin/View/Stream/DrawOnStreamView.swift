import SwiftUI

struct DrawOnStreamLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    let width: CGFloat
    let color: Color
}

private var drawing = false

private struct DrawOnStreamCanvasView: View {
    let model: Model
    @ObservedObject var stream: SettingsStream
    @ObservedObject var drawOnStream: DrawOnStream

    var body: some View {
        HStack {
            Spacer(minLength: 0)
            VStack {
                if !stream.portrait {
                    Spacer(minLength: 0)
                }
                Canvas { context, size in
                    for line in drawOnStream.lines {
                        let width = line.width
                        if line.points.count > 1 {
                            context.stroke(
                                drawOnStreamCreatePath(points: line.points),
                                with: .color(line.color),
                                lineWidth: width
                            )
                        } else {
                            let point = line.points[0]
                            var path = Path()
                            path.addEllipse(in: CGRect(x: point.x, y: point.y, width: 1, height: 1))
                            context.stroke(path, with: .color(line.color), lineWidth: width)
                        }
                    }
                    model.drawOnStreamSize = size
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let position = value.location
                            if value.translation == .zero {
                                if !drawing {
                                    drawOnStream.lines.append(DrawOnStreamLine(
                                        points: [position],
                                        width: drawOnStream.selectedWidth,
                                        color: drawOnStream.selectedColor
                                    ))
                                }
                                drawing = true
                            } else {
                                guard let lastIndex = drawOnStream.lines.indices.last else {
                                    return
                                }
                                drawOnStream.lines[lastIndex].points.append(position)
                            }
                        }
                        .onEnded { _ in
                            model.drawOnStreamLineComplete()
                            drawing = false
                        }
                )
                .aspectRatio(stream.dimensions().aspectRatio(), contentMode: .fit)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
        }
        .ignoresSafeArea()
        .edgesIgnoringSafeArea(.all)
    }
}

private struct DrawOnStreamControlsView: View {
    let model: Model
    @ObservedObject var drawOnStream: DrawOnStream

    private func buttonColor() -> Color {
        if drawOnStream.lines.isEmpty {
            return .gray
        } else {
            return .white
        }
    }

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                HStack {
                    Button {
                        model.drawOnStreamWipe()
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.title)
                            .foregroundStyle(buttonColor())
                    }
                    .disabled(drawOnStream.lines.isEmpty)
                    Button {
                        model.drawOnStreamUndo()
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title)
                            .foregroundStyle(buttonColor())
                    }
                    .disabled(drawOnStream.lines.isEmpty)
                    ColorPicker("Color", selection: $drawOnStream.selectedColor)
                        .labelsHidden()
                    Slider(value: $drawOnStream.selectedWidth, in: 1 ... 20)
                        .frame(width: 150)
                        .accentColor(drawOnStream.selectedColor)
                }
                .padding(8)
                .background(backgroundColor)
                .cornerRadius(5)
            }
            .padding([.trailing], 15)
        }
    }
}

struct DrawOnStreamView: View {
    let model: Model

    var body: some View {
        ZStack {
            DrawOnStreamCanvasView(model: model,
                                   stream: model.stream,
                                   drawOnStream: model.drawOnStream)
            DrawOnStreamControlsView(model: model, drawOnStream: model.drawOnStream)
        }
    }
}
