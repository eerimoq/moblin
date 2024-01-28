import SwiftUI

struct DrawOnStreamLine: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
    var color: Color
}

struct DrawOnStreamView: View {
    @EnvironmentObject var model: Model

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
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        ColorPicker("Color", selection: $model.drawOnStreamSelectedColor)
                            .font(.largeTitle)
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
