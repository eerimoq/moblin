import SwiftUI

private let cellWidth = 28.0
private let nameWidth = 150.0
private let totalWidth = 100.0
private let rowHeight = 22.0
private let headerHeight = 20.0
private let fontSize = 17.0

private func scoreCellColor(strokes: Int, par: Int) -> Color? {
    let diff = strokes - par
    if diff <= -2 {
        return Color(red: 0x31 / 255.0, green: 0x5C / 255.0, blue: 0x95 / 255.0)
    } else if diff == -1 {
        return Color(red: 0x1D / 255.0, green: 0x79 / 255.0, blue: 0x42 / 255.0)
    } else if diff == 0 {
        return Color(red: 0x66 / 255.0, green: 0x66 / 255.0, blue: 0x66 / 255.0)
    } else if diff == 1 {
        return Color(red: 0xA2 / 255.0, green: 0x10 / 255.0, blue: 0x10 / 255.0)
    } else if diff == 2 {
        return Color(red: 0x6B / 255.0, green: 0x1C / 255.0, blue: 0xA9 / 255.0)
    } else {
        return Color(red: 0x68 / 255.0, green: 0x39 / 255.0, blue: 0x15 / 255.0)
    }
}

private struct ScorecardCell: View {
    let text: String
    let background: Color?
    let foreground: Color
    let width: Double
    let bold: Bool
    let leftAlign: Bool

    init(text: String,
         background: Color? = nil,
         foreground: Color = .white,
         width: Double = cellWidth,
         bold: Bool = false,
         leftAlign: Bool = false)
    {
        self.text = text
        self.background = background
        self.foreground = foreground
        self.width = width
        self.bold = bold
        self.leftAlign = leftAlign
    }

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: fontSize))
                .bold(bold)
                .foregroundStyle(foreground)
                .lineLimit(1)
                .padding(.leading, leftAlign ? 8 : 0)
            if leftAlign {
                Spacer()
            }
        }
        .frame(width: width, height: rowHeight)
        .background(background ?? Color.clear)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
    }
}

private struct ScorecardHeaderCell: View {
    let text: String
    let width: Double
    let primaryBackgroundColor: Color
    let leftAlign: Bool

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: fontSize - 1))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.leading, leftAlign ? 8 : 0)
            if leftAlign {
                Spacer()
            }
        }
        .frame(width: width, height: headerHeight)
        .background(primaryBackgroundColor)
        .overlay(Rectangle().stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
    }
}

struct ScoreboardEffectGolfFullScorecardView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    @ObservedObject var golf: SettingsWidgetGolfScoreboard

    private func totalStrokes(player: SettingsWidgetGolfScoreboardPlayer) -> Int {
        var total = 0
        for h in 0 ..< golf.numberOfHoles {
            let s = h < player.scores.count ? player.scores[h] : -1
            if s >= 0 {
                total += s
            }
        }
        return total
    }

    var body: some View {
        let numberOfHoles = golf.numberOfHoles
        let pars = golf.pars
        let coursePar = pars.prefix(numberOfHoles).reduce(0, +)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Text(golf.title)
                    .font(.system(size: 20))
                    .bold()
                    .foregroundStyle(textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(secondaryBackgroundColor)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ScorecardHeaderCell(text: "Player",
                                        width: nameWidth,
                                        primaryBackgroundColor: primaryBackgroundColor,
                                        leftAlign: true)
                    ForEach(0 ..< numberOfHoles, id: \.self) { h in
                        ScorecardHeaderCell(text: "\(h + 1)",
                                            width: cellWidth,
                                            primaryBackgroundColor: primaryBackgroundColor,
                                            leftAlign: false)
                    }
                    ScorecardHeaderCell(text: "Total",
                                        width: totalWidth,
                                        primaryBackgroundColor: primaryBackgroundColor,
                                        leftAlign: false)
                }
                HStack(spacing: 0) {
                    ScorecardCell(text: "Par",
                                  foreground: textColor,
                                  width: nameWidth,
                                  bold: false,
                                  leftAlign: true)
                    ForEach(0 ..< numberOfHoles, id: \.self) { h in
                        let par = h < pars.count ? pars[h] : 4
                        ScorecardCell(text: "\(par)",
                                      foreground: textColor,
                                      width: cellWidth)
                    }
                    ScorecardCell(text: "\(coursePar)",
                                  foreground: textColor,
                                  width: totalWidth,
                                  bold: true)
                }
                ForEach(golf.players) { player in
                    let total = player.totalRelativeToPar(pars: pars, numberOfHoles: numberOfHoles)
                    let strokes = totalStrokes(player: player)
                    let totalText = strokes > 0
                        ? "\(strokes) (\(formatScore(total)))"
                        : formatScore(total)
                    let totalColor: Color = total < 0 ? .green : total > 0 ? .red : textColor
                    HStack(spacing: 0) {
                        ScorecardCell(text: player.name.uppercased(),
                                      foreground: textColor,
                                      width: nameWidth,
                                      bold: false,
                                      leftAlign: true)
                        ForEach(0 ..< numberOfHoles, id: \.self) { h in
                            let s = h < player.scores.count ? player.scores[h] : -1
                            let par = h < pars.count ? pars[h] : 4
                            let bg = s >= 0 ? scoreCellColor(strokes: s, par: par) : nil
                            let fg: Color = s < 0 ? Color.gray.opacity(0.3) : bg != nil ? .white : textColor
                            ScorecardCell(text: s >= 0 ? "\(s)" : "",
                                          background: bg,
                                          foreground: fg,
                                          width: cellWidth)
                        }
                        ScorecardCell(text: totalText,
                                      foreground: totalColor,
                                      width: totalWidth,
                                      bold: true)
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
