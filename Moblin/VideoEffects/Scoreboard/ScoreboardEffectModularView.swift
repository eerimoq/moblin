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
    private func stackedHistory(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) -> some View {
        title(title: config.global.title, modular: modular)
        HStack(alignment: .top, spacing: 0) {
            let histWidth = modular.fontSize() * 1.5
            let maxHistory = calculateMaxHistory(config: config)
            VStack(spacing: 0) {
                stackedHistoryTeam(
                    team: config.team1,
                    otherTeam: config.team2,
                    modular: modular,
                    modularTeam: modular.home,
                    histCount: maxHistory,
                    histWidth: histWidth,
                    currentPeriod: Int(config.global.period) ?? 1
                )
                stackedHistoryTeam(
                    team: config.team2,
                    otherTeam: config.team1,
                    modular: modular,
                    modularTeam: modular.away,
                    histCount: maxHistory,
                    histWidth: histWidth,
                    currentPeriod: Int(config.global.period) ?? 1
                )
            }
            .frame(width: CGFloat(modular.width) + CGFloat(maxHistory) * histWidth)
            infoBox(stats: config.infoBoxStats(), modular: modular)
        }
    }

    private func stackedHistoryTeam(
        team: RemoteControlScoreboardTeam,
        otherTeam: RemoteControlScoreboardTeam,
        modular: SettingsWidgetModularScoreboard,
        modularTeam: SettingsWidgetModularScoreboardTeam,
        histCount: Int,
        histWidth: CGFloat,
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
                    .minimumScaleFactor(0.1)
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                possession(show: team.possession, size: fontSize)
                if histCount > 0 {
                    ForEach(1 ... histCount, id: \.self) { indexPlusOne in
                        let value = getHistoricScore(team: team, indexPlusOne: indexPlusOne) ?? ""
                        let otherValue = getHistoricScore(team: otherTeam, indexPlusOne: indexPlusOne) ?? ""
                        let valueInt = Int(value) ?? -1
                        let otherValueInt = Int(otherValue) ?? -1
                        let weight: Font.Weight =
                            (indexPlusOne < currentPeriod && valueInt > otherValueInt && valueInt >= 0)
                                ? .bold
                                : .medium
                        if !value.isEmpty {
                            stat(
                                value: value,
                                fontSize: fontSize * 0.9,
                                width: histWidth,
                                gray: true,
                                weight: weight
                            )
                        } else if !otherValue.isEmpty {
                            stat(
                                value: "0",
                                fontSize: fontSize * 0.9,
                                width: histWidth,
                                gray: true,
                                weight: .medium
                            )
                        } else {
                            Color.clear.frame(width: histWidth)
                        }
                    }
                }
                stat(
                    value: team.primaryScore,
                    fontSize: fontSize,
                    width: fontSize * 1.55,
                    gray: false
                )
            }
            .frame(height: height)
            .background(modularTeam.backgroundColorColor)
            if modular.showMoreStats {
                moreStats(team: team,
                          fontSize: fontSize,
                          height: height * 0.6,
                          backgroundColor: modularTeam.backgroundColorColor)
            }
        }
        .foregroundStyle(modularTeam.textColorColor)
    }

    @ViewBuilder
    private func stacked(modular: SettingsWidgetModularScoreboard,
                         config: RemoteControlScoreboardMatchConfig) -> some View
    {
        title(title: config.global.title, modular: modular)
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                stackedTeam(team: config.team1, modular: modular, modularTeam: modular.home)
                stackedTeam(team: config.team2, modular: modular, modularTeam: modular.away)
            }
            .frame(width: CGFloat(modular.width))
            infoBox(stats: config.infoBoxStats(), modular: modular)
        }
    }

    @ViewBuilder
    private func sideBySide(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) -> some View {
        let fontSize = modular.fontSize()
        let height = CGFloat(modular.rowHeight)
        let teamRowFullHeight = height + (modular.showMoreStats ? height * 0.6 : 0)
        title(title: config.global.title, modular: modular)
        HStack(spacing: 0) {
            sideBySideTeam(
                team: config.team1,
                modular: modular,
                modularTeam: modular.home,
                mirrored: false
            )
            .frame(width: CGFloat(modular.width))
            Group {
                if modular.showGlobalStatsBlock {
                    VStack(spacing: 0) {
                        let periodFull = config.periodFull()
                        if !periodFull.isEmpty {
                            Text(periodFull)
                                .font(.system(size: fontSize * 0.6, weight: .bold))
                                .minimumScaleFactor(0.1)
                        }
                        Text(config.global.timer)
                            .font(.system(size: fontSize * 0.9, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.1)
                    }
                    .frame(width: fontSize * 3.5, height: teamRowFullHeight)
                } else {
                    Text("-")
                        .font(.system(size: fontSize, weight: .bold))
                        .frame(width: fontSize * 0.8, height: teamRowFullHeight)
                }
            }
            .background(.black)
            .foregroundStyle(.white)
            sideBySideTeam(
                team: config.team2,
                modular: modular,
                modularTeam: modular.away,
                mirrored: true
            )
            .frame(width: CGFloat(modular.width))
        }
    }

    private func stackedTeam(team: RemoteControlScoreboardTeam,
                             modular: SettingsWidgetModularScoreboard,
                             modularTeam: SettingsWidgetModularScoreboardTeam) -> some View
    {
        VStack(spacing: 0) {
            let fontSize = modular.fontSize()
            let height = CGFloat(modular.rowHeight)
            let width = fontSize * 1.55
            HStack(spacing: 0) {
                if modular.layout == .stacked {
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize,
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
                possession(show: team.possession, size: fontSize)
                if modular.layout == .stackedInline {
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize,
                        width: width,
                        gray: true
                    )
                }
                stat(
                    value: team.primaryScore,
                    fontSize: fontSize,
                    width: width,
                    gray: false
                )
            }
            .frame(height: height)
            .background(modularTeam.backgroundColorColor)
            if modular.showMoreStats {
                moreStats(team: team,
                          fontSize: fontSize,
                          height: height * 0.6,
                          backgroundColor: modularTeam.backgroundColorColor)
            }
        }
        .foregroundStyle(modularTeam.textColorColor)
    }

    @ViewBuilder
    private func sideBySideTeam(
        team: RemoteControlScoreboardTeam,
        modular: SettingsWidgetModularScoreboard,
        modularTeam: SettingsWidgetModularScoreboardTeam,
        mirrored: Bool
    ) -> some View {
        let fontSize = modular.fontSize()
        let height = CGFloat(modular.rowHeight)
        let width = fontSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !mirrored {
                    possession(show: team.possession, size: fontSize)
                    Text(team.name)
                        .font(.system(size: fontSize))
                        .bold(modular.isBold)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize,
                        width: width,
                        gray: true
                    )
                    stat(
                        value: team.primaryScore,
                        fontSize: fontSize,
                        width: width,
                        gray: false
                    )
                } else {
                    stat(
                        value: team.primaryScore,
                        fontSize: fontSize,
                        width: width,
                        gray: false
                    )
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize,
                        width: width,
                        gray: true
                    )
                    Text(team.name)
                        .font(.system(size: fontSize))
                        .bold(modular.isBold)
                        .lineLimit(1)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    possession(show: team.possession, size: fontSize)
                }
            }
            .frame(height: height)
            .background(modularTeam.backgroundColorColor)
            if modular.showMoreStats {
                moreStats(team: team,
                          fontSize: fontSize,
                          height: height * 0.6,
                          backgroundColor: modularTeam.backgroundColorColor,
                          alignRight: !mirrored)
            }
        }
        .foregroundStyle(modularTeam.textColorColor)
    }

    @ViewBuilder
    private func stat(
        value: String,
        label: String? = nil,
        fontSize: CGFloat,
        width: CGFloat,
        gray: Bool,
        weight: Font.Weight = .bold
    ) -> some View {
        if !value.isEmpty {
            ZStack {
                if gray {
                    Color.black.opacity(0.25)
                }
                if let label, !label.isEmpty {
                    VStack(spacing: -2) {
                        Text(label)
                            .font(.system(size: fontSize * 0.35, weight: .bold))
                            .padding(.top, 2)
                        Text(value)
                            .font(.system(size: fontSize * 0.8, weight: weight))
                    }
                } else {
                    Text(value)
                        .font(.system(size: fontSize, weight: weight))
                }
            }
            .frame(width: width)
        }
    }

    @ViewBuilder
    private func moreStats(
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
    private func possession(show: Bool, size: CGFloat) -> some View {
        if show {
            Image("VolleyballIndicator")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(size * 0.1)
        }
    }

    @ViewBuilder
    private func infoBox(stats: [String], modular: SettingsWidgetModularScoreboard) -> some View {
        if modular.showGlobalStatsBlock && !stats.isEmpty {
            let rowHeight = CGFloat(modular.rowHeight)
            let fullHeight = rowHeight + (modular.showMoreStats ? rowHeight * 0.6 : 0)
            let height = fullHeight * 2
            VStack(spacing: 0) {
                ForEach(0 ..< stats.count, id: \.self) { index in
                    HCenter {
                        Text(stats[index])
                            .font(.system(size: modular.fontSize()))
                            .bold(modular.isBold)
                            .monospacedDigit()
                            .minimumScaleFactor(0.1)
                            .lineLimit(1)
                    }
                }
            }
            .frame(height: height)
            .background(.black)
            .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func title(title: String, modular: SettingsWidgetModularScoreboard) -> some View {
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
                sideBySide(modular: modular, config: config)
            case .stackHistory:
                stackedHistory(modular: modular, config: config)
            default:
                stacked(modular: modular, config: config)
            }
        }
    }
}
