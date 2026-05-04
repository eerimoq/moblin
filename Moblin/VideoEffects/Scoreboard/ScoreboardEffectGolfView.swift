import SwiftUI

private let playerHeight = 35.0

private struct PlayerNameView: View {
    let player: SettingsWidgetGolfScoreboardPlayer

    var body: some View {
        Text(player.name.uppercased())
            .font(.system(size: 25))
            .padding(.leading, 8)
            .frame(height: playerHeight)
    }
}

private struct ThruView: View {
    let player: SettingsWidgetGolfScoreboardPlayer
    let numberOfHoles: Int
    let textColor: Color

    private func format() -> String {
        let thru = player.holesPlayed(numHoles: numberOfHoles)
        if thru == 0 {
            return ""
        } else if thru < numberOfHoles {
            return String(localized: "THRU \(thru)")
        } else {
            return String(localized: "F")
        }
    }

    var body: some View {
        Text(format())
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .font(.system(size: 15))
            .foregroundStyle(textColor.opacity(0.6))
            .padding(.trailing, 6)
            .frame(width: 70, height: playerHeight)
    }
}

private struct ScoreView: View {
    let player: SettingsWidgetGolfScoreboardPlayer
    let pars: [Int]
    let numberOfHoles: Int
    let textColor: Color

    var body: some View {
        let total = player.totalRelativeToPar(pars: pars, numberOfHoles: numberOfHoles)
        Text(formatScore(total))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .font(.system(size: scoreboardScoreFontSize))
            .bold()
            .foregroundStyle(total < 0 ? .green : total > 0 ? .red : textColor)
            .padding(.trailing, 8)
            .frame(height: playerHeight)
    }
}

struct ScoreboardEffectGolfView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    @ObservedObject var golf: SettingsWidgetGolfScoreboard

    var body: some View {
        let holeIndex = min(golf.currentHole, golf.numberOfHoles - 1)
        let par = golf.pars.indices.contains(holeIndex) ? golf.pars[holeIndex] : 4
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(golf.title)
                    .font(.system(size: 20))
                Spacer()
                Text("HOLE \(holeIndex + 1)  PAR \(par)")
                    .monospacedDigit()
                    .font(.system(size: 18))
            }
            .bold()
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(secondaryBackgroundColor)
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(golf.players) {
                        PlayerNameView(player: $0)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(golf.players) {
                        ThruView(player: $0, numberOfHoles: golf.numberOfHoles, textColor: textColor)
                    }
                }
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(golf.players) {
                        ScoreView(
                            player: $0,
                            pars: golf.pars,
                            numberOfHoles: golf.numberOfHoles,
                            textColor: textColor
                        )
                    }
                }
            }
            .background(primaryBackgroundColor)
            PoweredByMoblinView(backgroundColor: secondaryBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(textColor)
    }
}
