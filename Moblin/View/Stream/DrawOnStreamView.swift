import SwiftUI

struct DrawOnStreamLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
    var color: Color
}

struct DrawOnStreamView: View {
    @EnvironmentObject var model: Model

    private func buttonColor() -> Color {
        if model.drawOnStreamLines.isEmpty {
            return .gray
        } else {
            return .white
        }
    }

    var body: some View {
        ZStack {
            Canvas { context, size in
                for line in model.drawOnStreamLines {
                    context.stroke(
                        drawOnStreamCreatePath(points: line.points),
                        with: .color(line.color),
                        lineWidth: line.width
                    )
                }
                model.drawOnStreamSize = size
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let position = value.location
                        if value.translation == .zero {
                            model.drawOnStreamLines.append(DrawOnStreamLine(
                                points: [position],
                                width: model.drawOnStreamSelectedWidth,
                                color: model.drawOnStreamSelectedColor
                            ))
                        } else {
                            guard let lastIdx = model.drawOnStreamLines.indices.last else {
                                return
                            }
                            model.drawOnStreamLines[lastIdx].points.append(position)
                        }
                    }
                    .onEnded { _ in
                        model.drawOnStreamLineComplete()
                    }
            )
            .ignoresSafeArea()
            VStack {
                Spacer()
                HStack {
                    HStack {
                        Button {
                            model.drawOnStreamWipe()
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.title)
                                .foregroundColor(buttonColor())
                        }
                        .disabled(model.drawOnStreamLines.isEmpty)
                        Button {
                            model.drawOnStreamUndo()
                        } label: {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.title)
                                .foregroundColor(buttonColor())
                        }
                        .disabled(model.drawOnStreamLines.isEmpty)
                        ColorPicker("Color", selection: $model.drawOnStreamSelectedColor)
                            .font(.title)
                            .labelsHidden()
                        Slider(value: $model.drawOnStreamSelectedWidth, in: 1 ... 20)
                            .frame(width: 150)
                            .accentColor(model.drawOnStreamSelectedColor)
                    }
                    Spacer()
                }
            }
        }
    }
}
