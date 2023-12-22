import SwiftUI

struct ThermalStateView: View {
    var thermalState: ProcessInfo.ThermalState

    var body: some View {
        Image(systemName: "flame")
            .frame(width: 3, height: 3)
            .font(.system(size: 10))
            .foregroundColor(thermalState.color())
    }
}
