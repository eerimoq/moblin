import SwiftUI

struct ThermalStateView: View {
    var thermalState: ProcessInfo.ThermalState

    func color(thermalState: ProcessInfo.ThermalState) -> Color {
        switch thermalState {
        case .nominal:
            return .blue
        case .fair:
            return .green
        case .serious:
            return .yellow
        case .critical:
            return .red
        default:
            return .pink
        }
    }

    var body: some View {
        Image(systemName: "flame")
            .frame(width: 3, height: 3)
            .font(.system(size: 10))
            .foregroundColor(color(thermalState: thermalState))
    }
}
