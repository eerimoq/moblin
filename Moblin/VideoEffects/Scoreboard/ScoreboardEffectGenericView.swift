import SwiftUI

struct ScoreboardEffectGenericView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    @ObservedObject var generic: SettingsWidgetGenericScoreboard
    let scale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(generic.title)
                Spacer()
                Text(generic.clock.format())
                    .monospacedDigit()
                    .font(.system(size: 25 * scale))
            }
            .font(.system(size: 25 * scale))
            .padding(5 * scale)
            .background(secondaryBackgroundColor)
            HStack(alignment: .center, spacing: 6 * scale) {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        Text(generic.home.uppercased())
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        Text(generic.away.uppercased())
                        Spacer(minLength: 0)
                    }
                }
                .font(.system(size: 25 * scale))
                Spacer()
                VStack {
                    TeamScoreView(score: generic.score.home)
                    TeamScoreView(score: generic.score.away)
                }
                .font(.system(size: scoreboardScoreFontSize * scale))
                .frame(width: scoreboardScoreFontSize * 1.33 * scale)
            }
            .padding(.horizontal, 5 * scale)
            .background(primaryBackgroundColor)
            PoweredByMoblinView(backgroundColor: secondaryBackgroundColor, scale: scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5 * scale))
        .foregroundStyle(textColor)
    }
}
