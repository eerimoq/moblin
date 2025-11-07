import SwiftUI

struct BatteryView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var battery: Battery

    private func percentage(level: Double) -> String {
        return String(Int(level * 100))
    }

    private func boltColor() -> Color {
        if model.isBatteryCharging() {
            return .white
        } else {
            return .black
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(boltColor())
                .font(.system(size: 10))
            HStack(spacing: 0) {
                ZStack(alignment: .center) {
                    RoundedRectangle(cornerRadius: 2)
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 12)
                    Text(percentage(level: battery.level))
                        .foregroundStyle(.black)
                        .font(.system(size: 12))
                        .fixedSize()
                        .bold()
                }
                Circle()
                    .trim(from: 0.0, to: 0.5)
                    .rotationEffect(.degrees(-90))
                    .foregroundStyle(.gray)
                    .frame(width: 4)
            }
            .frame(width: 28, height: 13)
        }
        .padding([.top], 1)
    }
}
