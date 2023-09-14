import SwiftUI

struct ThermalStateView: View {
    var thermalState: ProcessInfo.ThermalState

    func color(thermalState: ProcessInfo.ThermalState) -> Color {
        switch thermalState {
        case .nominal:
            return .white
        case .fair:
            return .yellow
        case .serious:
            return .orange
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
