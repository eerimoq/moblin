import SwiftUI

struct ScoreboardEffectGenericView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    @ObservedObject var generic: SettingsWidgetGenericScoreboard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(generic.title)
                Spacer()
                Text(generic.clock.format())
                    .monospacedDigit()
                    .font(.system(size: 25))
            }
            .padding(5)
            .background(secondaryBackgroundColor)
            HStack(alignment: .center, spacing: 6) {
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
                .font(.system(size: 25))
                Spacer()
                VStack {
                    TeamScoreView(score: generic.score.home)
                    TeamScoreView(score: generic.score.away)
                }
                .font(.system(size: scoreboardScoreFontSize))
                .frame(width: scoreboardScoreFontSize * 1.33)
            }
            .padding([.horizontal], 5)
            .background(primaryBackgroundColor)
            PoweredByMoblinView(backgroundColor: secondaryBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(textColor)
    }
}
