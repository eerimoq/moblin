import SwiftUI

struct Line: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
    var color: Color
}

struct DrawOnStreamView: View {
    @EnvironmentObject var model: Model

    private func createPath(for line: [CGPoint]) -> Path {
        var path = Path()
        if let firstPoint = line.first {
            path.move(to: firstPoint)
        }
        if line.count > 2 {
            for index in 1 ..< line.count {
                let mid = calculateMidPoint(line[index - 1], line[index])
                path.addQuadCurve(to: mid, control: line[index - 1])
            }
        }
        if let last = line.last {
            path.addLine(to: last)
        }
        return path
    }

    private func calculateMidPoint(_ point1: CGPoint, _ point2: CGPoint) -> CGPoint {
        return CGPoint(x: (point1.x + point2.x) / 2, y: (point1.y + point2.y) / 2)
    }

    var body: some View {
        ZStack {
            Canvas { context, _ in
                for line in model.drawOnStreamLines {
                    let path = createPath(for: line.points)
                    context.stroke(path, with: .color(line.color), lineWidth: line.width)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let position = value.location
                        if value.translation == .zero {
                            model.drawOnStreamLines.append(Line(
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
            )
            VStack {
                Spacer()
                HStack {
                    HStack {
                        Button {
                            model.drawOnStreamLines = []
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
