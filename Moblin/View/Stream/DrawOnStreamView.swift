import SwiftUI

struct DrawOnStreamLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
    var color: Color
}

private var drawing = false

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
            HStack {
                Spacer(minLength: 0)
                VStack {
                    Spacer(minLength: 0)
                    Canvas { context, size in
                        for line in model.drawOnStreamLines {
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
                                        model.drawOnStreamLines.append(DrawOnStreamLine(
                                            points: [position],
                                            width: model.drawOnStreamSelectedWidth,
                                            color: model.drawOnStreamSelectedColor
                                        ))
                                    }
                                    drawing = true
                                } else {
                                    guard let lastIndex = model.drawOnStreamLines.indices.last else {
                                        return
                                    }
                                    model.drawOnStreamLines[lastIndex].points.append(position)
                                }
                            }
                            .onEnded { _ in
                                model.drawOnStreamLineComplete()
                                drawing = false
                            }
                    )
                    .aspectRatio(16 / 9, contentMode: .fit)
                    Spacer(minLength: 0)
                }
            }
            .ignoresSafeArea()
            .edgesIgnoringSafeArea(.all)
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
                            .labelsHidden()
                        Slider(value: $model.drawOnStreamSelectedWidth, in: 1 ... 20)
                            .frame(width: 150)
                            .accentColor(model.drawOnStreamSelectedColor)
                    }
                    .padding(8)
                    .background(Color(white: 0, opacity: 0.6))
                    .cornerRadius(5)
                }
                .padding([.trailing], 15)
            }
        }
    }
}
