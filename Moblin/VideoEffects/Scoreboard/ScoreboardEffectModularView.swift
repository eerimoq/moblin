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

struct ScoreboardEffectModularView: View {
    let modular: SettingsWidgetModularScoreboard
    let config: RemoteControlScoreboardMatchConfig

    private func calculateMaxHistory() -> Int {
        var maxHistory = 0
        for indexPlusOne in 1 ... 5 {
            let homeHas = getHistoricScore(team: config.team1, indexPlusOne: indexPlusOne) ?? ""
            let awayHas = getHistoricScore(team: config.team2, indexPlusOne: indexPlusOne) ?? ""
            if !homeHas.isEmpty || !awayHas.isEmpty {
                maxHistory = indexPlusOne
            }
        }
        return maxHistory
    }

    private func fontSize() -> Double {
        return modular.fontSize()
    }

    @ViewBuilder
    private func stackedHistory() -> some View {
        title()
        HStack(alignment: .top, spacing: 0) {
            let maxHistory = calculateMaxHistory()
            let histWidth = modular.fontSize() * 1.5
            VStack(spacing: 0) {
                stackedHistoryTeam(
                    team: config.team1,
                    otherTeam: config.team2,
                    modularTeam: modular.home,
                    histCount: maxHistory,
                    histWidth: histWidth
                )
                stackedHistoryTeam(
                    team: config.team2,
                    otherTeam: config.team1,
                    modularTeam: modular.away,
                    histCount: maxHistory,
                    histWidth: histWidth
                )
            }
            .frame(width: CGFloat(modular.width) + CGFloat(maxHistory - 1) * histWidth)
            infoBox()
        }
    }

    private func stackedHistoryTeam(
        team: RemoteControlScoreboardTeam,
        otherTeam: RemoteControlScoreboardTeam,
        modularTeam: SettingsWidgetModularScoreboardTeam,
        histCount: Int,
        histWidth: CGFloat
    ) -> some View {
        VStack(spacing: 0) {
            let currentPeriod = Int(config.global.period) ?? 1
            let height = CGFloat(modular.rowHeight)
            HStack(spacing: 0) {
                teamName(team: modularTeam)
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                possession(show: team.possession)
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
                                fontSize: fontSize() * 0.9,
                                width: histWidth,
                                gray: true,
                                weight: weight
                            )
                        } else if !otherValue.isEmpty {
                            stat(
                                value: "0",
                                fontSize: fontSize() * 0.9,
                                width: histWidth,
                                gray: true,
                                weight: .medium
                            )
                        } else {
                            Color.clear.frame(width: histWidth)
                        }
                    }
                }
                primaryScore(team: team)
            }
            .frame(height: height)
            .background(modularTeam.backgroundColorColor)
            moreStats(team: team,
                      height: height * 0.6,
                      backgroundColor: modularTeam.backgroundColorColor)
        }
        .foregroundStyle(modularTeam.textColorColor)
    }

    @ViewBuilder
    private func stacked() -> some View {
        title()
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                stackedTeam(team: config.team1, modularTeam: modular.home)
                stackedTeam(team: config.team2, modularTeam: modular.away)
            }
            .frame(width: CGFloat(modular.width))
            infoBox()
        }
    }

    @ViewBuilder
    private func sideBySide() -> some View {
        title()
        HStack(spacing: 0) {
            sideBySideTeam(
                team: config.team1,
                modularTeam: modular.home,
                mirrored: false
            )
            .frame(width: CGFloat(modular.width))
            Group {
                let height = CGFloat(modular.rowHeight)
                let teamRowFullHeight = height + (modular.showMoreStats ? height * 0.6 : 0)
                if modular.showGlobalStatsBlock {
                    VStack(spacing: 0) {
                        let periodFull = config.periodFull()
                        if !periodFull.isEmpty {
                            Text(periodFull)
                                .font(.system(size: fontSize() * 0.6, weight: .bold))
                                .minimumScaleFactor(0.1)
                        }
                        Text(config.global.timer)
                            .font(.system(size: fontSize() * 0.9, weight: .bold))
                            .monospacedDigit()
                            .minimumScaleFactor(0.1)
                    }
                    .frame(width: fontSize() * 3.5, height: teamRowFullHeight)
                } else {
                    Text("-")
                        .font(.system(size: fontSize(), weight: .bold))
                        .frame(height: teamRowFullHeight)
                }
            }
            .background(.black)
            .foregroundStyle(.white)
            sideBySideTeam(
                team: config.team2,
                modularTeam: modular.away,
                mirrored: true
            )
            .frame(width: CGFloat(modular.width))
        }
    }

    private func stackedTeam(team: RemoteControlScoreboardTeam,
                             modularTeam: SettingsWidgetModularScoreboardTeam) -> some View
    {
        VStack(spacing: 0) {
            let height = CGFloat(modular.rowHeight)
            let width = fontSize() * 1.55
            HStack(spacing: 0) {
                if modular.layout == .stacked {
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize(),
                        width: width,
                        gray: true
                    )
                }
                teamName(team: modularTeam)
                    .padding(.leading, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                possession(show: team.possession)
                if modular.layout == .stackedInline {
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize(),
                        width: width,
                        gray: true
                    )
                }
                primaryScore(team: team)
            }
            .frame(height: height)
            .background(modularTeam.backgroundColorColor)
            moreStats(team: team,
                      height: height * 0.6,
                      backgroundColor: modularTeam.backgroundColorColor)
        }
        .foregroundStyle(modularTeam.textColorColor)
    }

    @ViewBuilder
    private func sideBySideTeam(
        team: RemoteControlScoreboardTeam,
        modularTeam: SettingsWidgetModularScoreboardTeam,
        mirrored: Bool
    ) -> some View {
        let height = CGFloat(modular.rowHeight)
        let width = fontSize() * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !mirrored {
                    possession(show: team.possession)
                    teamName(team: modularTeam)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize(),
                        width: width,
                        gray: true
                    )
                    primaryScore(team: team)
                } else {
                    primaryScore(team: team)
                    stat(
                        value: team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        fontSize: fontSize(),
                        width: width,
                        gray: true
                    )
                    teamName(team: modularTeam)
                        .padding(.horizontal, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    possession(show: team.possession)
                }
            }
            .frame(height: height)
            .background(modularTeam.backgroundColorColor)
            moreStats(team: team,
                      height: height * 0.6,
                      backgroundColor: modularTeam.backgroundColorColor,
                      alignRight: !mirrored)
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
        weight: Font.Weight = .heavy
    ) -> some View {
        if !value.isEmpty {
            ZStack {
                if gray {
                    Color.black.opacity(0.25)
                }
                if let label, !label.isEmpty {
                    VStack(spacing: -2) {
                        Text(label)
                            .font(.system(size: fontSize * 0.25, weight: .bold))
                            .offset(x: 0, y: fontSize * 0.04)
                        Text(value)
                            .font(.system(size: fontSize * 0.75, weight: weight))
                    }
                } else {
                    Text(value)
                        .font(.system(size: fontSize, weight: weight))
                }
            }
            .frame(width: width)
        }
    }

    private func primaryScore(team: RemoteControlScoreboardTeam) -> some View {
        stat(
            value: team.primaryScore,
            fontSize: modular.fontSize(),
            width: modular.fontSize() * 1.55,
            gray: false
        )
    }

    private func teamName(team: SettingsWidgetModularScoreboardTeam) -> some View {
        Text(team.name)
            .font(.system(size: fontSize(), weight: .bold))
            .bold(modular.isBold)
            .lineLimit(1)
            .minimumScaleFactor(0.1)
    }

    @ViewBuilder
    private func possession(show: Bool) -> some View {
        if show {
            Image("VolleyballIndicator")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .padding(fontSize() * 0.1)
        }
    }

    @ViewBuilder
    private func moreStats(
        team: RemoteControlScoreboardTeam,
        height: CGFloat,
        backgroundColor: Color,
        alignRight: Bool = false
    ) -> some View {
        if modular.showMoreStats {
            let stats = [
                (0, team.stat1Label, team.stat1),
                (1, team.stat2Label, team.stat2),
                (2, team.stat3Label, team.stat3),
                (3, team.stat4Label, team.stat4),
            ]
            .filter { _, _, value in !value.isEmpty && !value.hasPrefix("NO ") }
            ZStack {
                Color.black.opacity(0.25)
                HStack(spacing: 8) {
                    if alignRight {
                        Spacer()
                    }
                    ForEach(stats, id: \.0) { _, label, value in
                        HStack(spacing: 2) {
                            if !label.isEmpty {
                                Text(label + ":")
                                    .opacity(0.8)
                            }
                            Text(value)
                                .monospacedDigit()
                        }
                        .font(.system(size: fontSize(), weight: .bold))
                        .minimumScaleFactor(0.3)
                    }
                    if !alignRight {
                        Spacer()
                    }
                }
                .padding(.horizontal, 6)
            }
            .frame(height: height)
            .background(backgroundColor)
        }
    }

    @ViewBuilder
    private func infoBox() -> some View {
        let stats = config.infoBoxStats()
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
    private func title() -> some View {
        if modular.showTitle {
            HCenter {
                Text(config.global.title)
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
                sideBySide()
            case .stackHistory:
                stackedHistory()
            default:
                stacked()
            }
        }
    }
}
