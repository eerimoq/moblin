import SwiftUI

private func getHistoricScore(team: RemoteControlScoreboardTeam, indexPlusOne: Int) -> String? {
    switch indexPlusOne {
    case 1:
        return team.secondaryScore1
    case 2:
        return team.secondaryScore2
    case 3:
        return team.secondaryScore3
    case 4:
        return team.secondaryScore4
    case 5:
        return team.secondaryScore5
    default:
        return nil
    }
}

private func calculateMaxHistory(config: RemoteControlScoreboardMatchConfig) -> Int {
    var maxHistory = 0
    for indexPlusOne in 1 ... 5 {
        let homeHas = getHistoricScore(team: config.team1, indexPlusOne: indexPlusOne) != nil
        let awayHas = getHistoricScore(team: config.team2, indexPlusOne: indexPlusOne) != nil
        if homeHas || awayHas {
            maxHistory = indexPlusOne
        }
    }
    return maxHistory
}

struct ScoreboardEffectModularView: View {
    let modular: SettingsWidgetModularScoreboard
    let config: RemoteControlScoreboardMatchConfig

    @ViewBuilder
    private func renderStackHistory(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) -> some View {
        renderTitle(title: config.global.title, modular: modular)
        HStack(alignment: .top, spacing: 0) {
            let histWidth = modular.fontSize() * 1.5
            let maxHistory = calculateMaxHistory(config: config)
            VStack(spacing: 0) {
                renderStackHistoryRow(
                    team: config.team1,
                    otherTeam: config.team2,
                    modular: modular,
                    textColor: modular.home.textColorColor,
                    backgroundColor: modular.home.backgroundColorColor,
                    histCount: maxHistory,
                    histW: histWidth,
                    currentPeriod: Int(config.global.period) ?? 1
                )
                renderStackHistoryRow(
                    team: config.team2,
                    otherTeam: config.team1,
                    modular: modular,
                    textColor: modular.away.textColorColor,
                    backgroundColor: modular.away.backgroundColorColor,
                    histCount: maxHistory,
                    histW: histWidth,
                    currentPeriod: Int(config.global.period) ?? 1
                )
            }
            .frame(width: CGFloat(modular.width) + CGFloat(maxHistory) * histWidth)
            renderInfoBox(stats: config.global.infoBoxStats(), modular: modular)
        }
    }

    private func renderStackHistoryRow(
        team: RemoteControlScoreboardTeam,
        otherTeam: RemoteControlScoreboardTeam,
        modular: SettingsWidgetModularScoreboard,
        textColor: Color,
        backgroundColor: Color,
        histCount: Int,
        histW: CGFloat,
        currentPeriod: Int
    ) -> some View {
        VStack(spacing: 0) {
            let fontSize = modular.fontSize()
            let height = CGFloat(modular.rowHeight)
            HStack(spacing: 0) {
                Text(team.name)
                    .font(.system(size: fontSize))
                    .bold(modular.isBold)
                    .lineLimit(1)
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                renderPossession(show: team.possession, size: fontSize)
                if histCount > 0 {
                    ForEach(1 ... histCount, id: \.self) { indexPlusOne in
                        let val = getHistoricScore(team: team, indexPlusOne: indexPlusOne) ?? ""
                        let oppVal = getHistoricScore(team: otherTeam, indexPlusOne: indexPlusOne) ?? ""
                        let valInt = Int(val) ?? -1
                        let oppInt = Int(oppVal) ?? -1
                        let weight: Font
                            .Weight = (indexPlusOne < currentPeriod && valInt > oppInt && valInt >= 0)
                            ? .black
                            : .medium
                        if !val.isEmpty {
                            renderStat(
                                val,
                                label: nil,
                                size: fontSize * 0.9,
                                width: histW,
                                gray: true,
                                weight: weight
                            )
                        } else if !oppVal.isEmpty {
                            renderStat(
                                "0",
                                label: nil,
                                size: fontSize * 0.9,
                                width: histW,
                                gray: true,
                                weight: .medium
                            )
                        } else {
                            Color.clear.frame(width: histW)
                        }
                    }
                }
                renderStat(
                    team.primaryScore,
                    label: nil,
                    size: fontSize,
                    width: fontSize * 1.55,
                    gray: false
                )
            }
            .frame(height: height)
            .background(backgroundColor)
            if modular.showMoreStats {
                renderMoreStats(team: team,
                                fontSize: fontSize,
                                height: height * 0.6,
                                backgroundColor: backgroundColor)
            }
        }
        .foregroundStyle(textColor)
    }

    @ViewBuilder
    private func renderStacked(modular: SettingsWidgetModularScoreboard,
                               config: RemoteControlScoreboardMatchConfig) -> some View
    {
        renderTitle(title: config.global.title, modular: modular)
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                renderStackedRow(
                    team: config.team1,
                    modular: modular,
                    textColor: modular.home.textColorColor,
                    backgroundColor: modular.home.backgroundColorColor
                )
                renderStackedRow(
                    team: config.team2,
                    modular: modular,
                    textColor: modular.away.textColorColor,
                    backgroundColor: modular.away.backgroundColorColor
                )
            }
            .frame(width: CGFloat(modular.width))
            renderInfoBox(stats: config.global.infoBoxStats(), modular: modular)
        }
    }

    @ViewBuilder
    private func renderSideBySide(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) -> some View {
        let fontSize = modular.fontSize()
        let height = CGFloat(modular.rowHeight)
        let teamRowFullHeight = height + (modular.showMoreStats ? height * 0.6 : 0)
        renderTitle(title: config.global.title, modular: modular)
        HStack(spacing: 0) {
            renderSideBySideHalf(
                team: config.team1,
                modular: modular,
                textColor: modular.home.textColorColor,
                backgroundColor: modular.home.backgroundColorColor,
                mirrored: false
            )
            .frame(width: CGFloat(modular.width))
            Group {
                if modular.showGlobalStatsBlock {
                    VStack(spacing: 0) {
                        let periodFull = config.global.periodFull()
                        if !periodFull.isEmpty {
                            Text(periodFull)
                                .font(.system(size: fontSize * 0.6, weight: .bold))
                        }
                        Text(config.global.timer)
                            .font(.system(size: fontSize * 0.9, weight: .black))
                            .monospacedDigit()
                    }
                    .frame(width: fontSize * 3.5, height: teamRowFullHeight)
                } else {
                    Text("-")
                        .font(.system(size: fontSize, weight: .black))
                        .frame(width: fontSize * 0.8, height: teamRowFullHeight)
                }
            }
            .background(.black)
            .foregroundStyle(.white)
            renderSideBySideHalf(
                team: config.team2,
                modular: modular,
                textColor: modular.away.textColorColor,
                backgroundColor: modular.away.backgroundColorColor,
                mirrored: true
            )
            .frame(width: CGFloat(modular.width))
        }
    }

    private func renderStackedRow(team: RemoteControlScoreboardTeam,
                                  modular: SettingsWidgetModularScoreboard,
                                  textColor: Color,
                                  backgroundColor: Color) -> some View
    {
        VStack(spacing: 0) {
            let fontSize = modular.fontSize()
            let height = CGFloat(modular.rowHeight)
            let width = fontSize * 1.55
            HStack(spacing: 0) {
                if modular.layout == .stacked {
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        gray: true
                    )
                }
                Text(team.name)
                    .font(.system(size: fontSize))
                    .bold(modular.isBold)
                    .lineLimit(1)
                    .padding(.leading, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                renderPossession(show: team.possession, size: fontSize)
                if modular.layout == .stackedInline {
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        gray: true
                    )
                }
                renderStat(
                    team.primaryScore,
                    label: nil,
                    size: fontSize,
                    width: width,
                    gray: false
                )
            }
            .frame(height: height)
            .background(backgroundColor)
            if modular.showMoreStats {
                renderMoreStats(team: team,
                                fontSize: fontSize,
                                height: height * 0.6,
                                backgroundColor: backgroundColor)
            }
        }
        .foregroundStyle(textColor)
    }

    @ViewBuilder
    private func renderSideBySideHalf(
        team: RemoteControlScoreboardTeam,
        modular: SettingsWidgetModularScoreboard,
        textColor: Color,
        backgroundColor: Color,
        mirrored: Bool
    ) -> some View {
        let fontSize = modular.fontSize()
        let height = CGFloat(modular.rowHeight)
        let width = fontSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !mirrored {
                    renderPossession(show: team.possession, size: fontSize)
                    Text(team.name)
                        .font(.system(size: fontSize))
                        .bold(modular.isBold)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        gray: true
                    )
                    renderStat(
                        team.primaryScore,
                        label: nil,
                        size: fontSize,
                        width: width,
                        gray: false
                    )
                } else {
                    renderStat(
                        team.primaryScore,
                        label: nil,
                        size: fontSize,
                        width: width,
                        gray: false
                    )
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        gray: true
                    )
                    Text(team.name)
                        .font(.system(size: fontSize))
                        .bold(modular.isBold)
                        .lineLimit(1)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    renderPossession(show: team.possession, size: fontSize)
                }
            }
            .frame(height: height)
            .background(backgroundColor)
            if modular.showMoreStats {
                renderMoreStats(team: team,
                                fontSize: fontSize,
                                height: height * 0.6,
                                backgroundColor: backgroundColor,
                                alignRight: !mirrored)
            }
        }
        .foregroundStyle(textColor)
    }

    @ViewBuilder
    private func renderStat(
        _ val: String,
        label: String?,
        size: CGFloat,
        width: CGFloat,
        gray: Bool,
        weight: Font.Weight = .black
    ) -> some View {
        if !val.isEmpty {
            ZStack {
                if gray {
                    Color.black.opacity(0.25)
                }
                if let label, !label.isEmpty {
                    VStack(spacing: -2) {
                        Text(label)
                            .font(.system(size: size * 0.35, weight: .bold))
                            .padding(.top, 2)
                        Text(val)
                            .font(.system(size: size * 0.8, weight: weight))
                    }
                } else {
                    Text(val)
                        .font(.system(size: size, weight: weight))
                }
            }
            .frame(width: width)
        }
    }

    @ViewBuilder
    private func renderMoreStats(
        team: RemoteControlScoreboardTeam,
        fontSize: CGFloat,
        height: CGFloat,
        backgroundColor: Color,
        alignRight: Bool = false
    ) -> some View {
        let stats = [
            (0, team.stat1Label, team.stat1),
            (1, team.stat2Label, team.stat2),
            (2, team.stat3Label, team.stat3),
            (3, team.stat4Label, team.stat4),
        ]
        .filter { !$0.2.isEmpty && !$0.2.hasPrefix("NO ") }
        HStack(spacing: 8) {
            if alignRight {
                Spacer()
            }
            ForEach(stats, id: \.0) { stat in
                HStack(spacing: 2) {
                    if !stat.1.isEmpty {
                        Text(stat.1 + ":")
                            .opacity(0.8)
                    }
                    Text(stat.2)
                        .monospacedDigit()
                }
                .font(.system(size: fontSize * 0.65, weight: .bold))
                .minimumScaleFactor(0.5)
            }
            if !alignRight {
                Spacer()
            }
        }
        .padding(.horizontal, 6)
        .frame(height: height)
        .background(
            ZStack {
                backgroundColor
                Color.black.opacity(0.25)
            }
        )
    }

    @ViewBuilder
    private func renderPossession(show: Bool, size: CGFloat) -> some View {
        if show {
            Image("VolleyballIndicator")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: size * 1.1)
                .foregroundStyle(.white)
                .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private func renderInfoBox(stats: [String], modular: SettingsWidgetModularScoreboard) -> some View {
        let rowHeight = CGFloat(modular.rowHeight)
        let fullHeight = rowHeight + (modular.showMoreStats ? rowHeight * 0.6 : 0)
        let height = fullHeight * 2
        if modular.showGlobalStatsBlock && !stats.isEmpty {
            VStack(spacing: 0) {
                ForEach(0 ..< stats.count, id: \.self) { i in
                    Text(stats[i])
                        .font(.system(size: modular.fontSize() * 0.9))
                        .bold(modular.isBold)
                        .monospacedDigit()
                        .minimumScaleFactor(0.1)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: stats.isEmpty ? 0 : height / CGFloat(stats.count))
                }
            }
            .frame(width: modular.fontSize() * 3.5, height: height)
            .background(.black)
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func renderTitle(title: String, modular: SettingsWidgetModularScoreboard) -> some View {
        if modular.showTitle {
            HCenter {
                Text(title)
                    .font(.system(size: modular.fontSize() * 0.7))
                    .bold(modular.isBold)
                    .padding(.vertical, 1)
            }
            .background(.black)
            .foregroundStyle(.white)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            switch modular.layout {
            case .sideBySide:
                renderSideBySide(modular: modular, config: config)
            case .stackHistory:
                renderStackHistory(modular: modular, config: config)
            default:
                renderStacked(modular: modular, config: config)
            }
        }
    }
}
