import SwiftUI

private struct PlayerNameView: View {
    let player: SettingsWidgetGolfScoreboardPlayer
    let playerColor: Bool
    let scale: Double

    var body: some View {
        HStack(spacing: 6 * scale) {
            if playerColor {
                RoundedRectangle(cornerRadius: 3 * scale)
                    .fill(player.color.color())
                    .frame(width: 18 * scale, height: 18 * scale)
            }
            Text(player.name.uppercased())
                .font(.system(size: 25 * scale))
        }
        .frame(height: 35 * scale)
        .padding(.leading, 8 * scale)
    }
}

private struct ThruView: View {
    let player: SettingsWidgetGolfScoreboardPlayer
    let numberOfHoles: Int
    let textColor: Color
    let scale: Double

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
            .font(.system(size: 15 * scale))
            .foregroundStyle(textColor.opacity(0.6))
            .padding(.trailing, 6 * scale)
            .frame(width: 70 * scale, height: 35 * scale)
    }
}

private struct ScoreView: View {
    let player: SettingsWidgetGolfScoreboardPlayer
    let pars: [Int]
    let numberOfHoles: Int
    let textColor: Color
    let scale: Double

    var body: some View {
        let total = player.totalRelativeToPar(pars: pars, numberOfHoles: numberOfHoles)
        Text(formatScore(total))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .font(.system(size: scoreboardScoreFontSize * scale))
            .bold()
            .foregroundStyle(total < 0 ? .green : total > 0 ? .red : textColor)
            .padding(.trailing, 8 * scale)
            .frame(height: 35 * scale)
    }
}

struct ScoreboardEffectGolfView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    @ObservedObject var golf: SettingsWidgetGolfScoreboard
    let scale: Double

    var body: some View {
        let holeIndex = min(golf.currentHole, golf.numberOfHoles - 1)
        let par = golf.pars.indices.contains(holeIndex) ? golf.pars[holeIndex] : 4
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8 * scale) {
                Text(golf.title)
                    .font(.system(size: 20 * scale))
                Spacer()
                Text("HOLE \(holeIndex + 1)  PAR \(par)")
                    .monospacedDigit()
                    .font(.system(size: 18 * scale))
            }
            .bold()
            .padding(.horizontal, 8 * scale)
            .padding(.vertical, 4 * scale)
            .background(secondaryBackgroundColor)
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(golf.players) {
                        PlayerNameView(player: $0, playerColor: golf.playerColors, scale: scale)
                    }
                }
                Spacer()
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(golf.players) {
                        ThruView(player: $0, numberOfHoles: golf.numberOfHoles, textColor: textColor,
                                 scale: scale)
                    }
                }
                VStack(alignment: .trailing, spacing: 0) {
                    ForEach(golf.players) {
                        ScoreView(
                            player: $0,
                            pars: golf.pars,
                            numberOfHoles: golf.numberOfHoles,
                            textColor: textColor,
                            scale: scale
                        )
                    }
                }
            }
            .background(primaryBackgroundColor)
            PoweredByMoblinView(backgroundColor: secondaryBackgroundColor, scale: scale)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5 * scale))
        .foregroundStyle(textColor)
    }
}
