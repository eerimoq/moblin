import SwiftUI

struct Line: Identifiable {
    let id = UUID()
    var points: [CGPoint]
    var width: CGFloat
    var color: Color
}

struct DrawOnStreamView: View {
    @State var lines: [Line] = []
    @State var selectedColor: Color = .pink
    @State var selectedWidth: CGFloat = 4

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
                for line in lines {
                    let path = createPath(for: line.points)
                    context.stroke(path, with: .color(line.color), lineWidth: line.width)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let position = value.location
                        if value.translation == .zero {
                            lines.append(Line(points: [position], width: selectedWidth, color: selectedColor))
                        } else {
                            guard let lastIdx = lines.indices.last else {
                                return
                            }
                            lines[lastIdx].points.append(position)
                        }
                    }
            )
            VStack {
                Spacer()
                HStack {
                    HStack {
                        Button {
                            lines = []
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        }
                        ColorPicker("Color", selection: $selectedColor)
                            .font(.largeTitle)
                            .labelsHidden()
                        Slider(value: $selectedWidth, in: 1 ... 20)
                            .frame(width: 150)
                            .accentColor(selectedColor)
                    }
                    Spacer()
                }
            }
        }
    }
}
