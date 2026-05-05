import SwiftUI

private let nameCellWidth = 150.0
private let numberCellWidth = 28.0
private let totalCellWidth = 100.0
private let fontSize = 17.0
private let leftAlignPadding = 8.0

private func scoreCellColor(strokes: Int, par: Int) -> Color {
    guard strokes >= 0 else {
        return Color.clear
    }
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

private struct HeaderCellView: View {
    let text: String
    let width: Double
    var leftAlign: Bool = false

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: fontSize - 1))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(.leading, leftAlign ? leftAlignPadding : 0)
            if leftAlign {
                Spacer()
            }
        }
        .frame(width: width, height: 20)
        .overlay(Rectangle()
            .stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
    }
}

private struct CellView: View {
    let text: String
    let width: Double
    var background: Color = .clear
    var bold: Bool = false
    var leftAlign: Bool = false

    var body: some View {
        HStack {
            Text(text)
                .font(.system(size: fontSize))
                .bold(bold)
                .lineLimit(1)
                .padding(.leading, leftAlign ? leftAlignPadding : 0)
            if leftAlign {
                Spacer()
            }
        }
        .frame(width: width, height: 22)
        .background(background)
        .overlay(Rectangle()
            .stroke(Color.gray.opacity(0.4), lineWidth: 0.5))
    }
}

struct ScoreboardEffectGolfFullScorecardView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    @ObservedObject var golf: SettingsWidgetGolfScoreboard

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                HeaderCellView(text: String(localized: "Player"),
                               width: nameCellWidth,
                               leftAlign: true)
                ForEach(0 ..< golf.numberOfHoles, id: \.self) { holeIndex in
                    HeaderCellView(text: "\(holeIndex + 1)", width: numberCellWidth)
                }
                HeaderCellView(text: String(localized: "Total"), width: totalCellWidth)
            }
            .background(secondaryBackgroundColor)
            ForEach(golf.players) { player in
                HStack(spacing: 0) {
                    CellView(text: player.name.uppercased(), width: nameCellWidth, leftAlign: true)
                    ForEach(0 ..< golf.numberOfHoles, id: \.self) { holeIndex in
                        let score = holeIndex < player.scores.count ? player.scores[holeIndex] : -1
                        let par = holeIndex < golf.pars.count ? golf.pars[holeIndex] : 4
                        CellView(text: score >= 0 ? "\(score)" : "",
                                 width: numberCellWidth,
                                 background: scoreCellColor(strokes: score, par: par))
                    }
                    let strokes = player.totalStrokes(numberOfHoles: golf.numberOfHoles)
                    let relative = player.totalRelativeToPar(pars: golf.pars,
                                                             numberOfHoles: golf.numberOfHoles)
                    CellView(text: "\(strokes) (\(formatScore(relative)))",
                             width: totalCellWidth,
                             bold: true)
                }
            }
            .background(primaryBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(textColor)
    }
}
