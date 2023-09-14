import SwiftUI

struct BatteryView: View {
    var level: Float

    var body: some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .frame(width: 22, height: 12)
            Rectangle()
                .fill(Color(red: 88 / 255, green: 191 / 255, blue: 108 / 255))
                .frame(width: 22 * CGFloat(level >= 0 ? level : 0), height: 12)
        }
        .cornerRadius(3)
    }
}
