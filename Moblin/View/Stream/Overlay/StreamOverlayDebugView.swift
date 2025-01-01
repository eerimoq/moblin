import SwiftUI

struct StreamOverlayDebugView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        if !model.debugLines.isEmpty {
            VStack(alignment: .leading, spacing: 1) {
                Text("CPU: \(Int(model.cpuUsage))")
                ForEach(model.debugLines, id: \.self) { line in
                    Text(line)
                }
            }
            .font(smallFont)
            .foregroundColor(.white)
            .padding([.leading, .trailing], 2)
            .background(Color(white: 0, opacity: 0.75))
            .cornerRadius(5)
            .onAppear {
                model.cpuUsageNeeded = true
            }
            .onDisappear {
                model.cpuUsageNeeded = false
            }
        }
    }
}
