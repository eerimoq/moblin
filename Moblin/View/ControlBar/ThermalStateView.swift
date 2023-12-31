import SwiftUI

struct ThermalStateView: View {
    var thermalState: ProcessInfo.ThermalState

    var body: some View {
        Image(systemName: "flame")
            .font(.system(size: 11))
            .foregroundColor(thermalState.color())
    }
}
