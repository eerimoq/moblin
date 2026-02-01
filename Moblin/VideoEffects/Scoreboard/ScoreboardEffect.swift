import SwiftUI

private struct PadelScoreboardScore: Identifiable {
    let id: UUID = .init()
    let home: Int
    let away: Int

    func isHomeWin() -> Bool {
        return isSetWin(first: home, second: away)
    }

    func isAwayWin() -> Bool {
        return isSetWin(first: away, second: home)
    }
}

private struct PadelScoreboardPlayer: Identifiable {
    let id: UUID = .init()
    let name: String
}

private struct PadelScoreboardTeam {
    let players: [PadelScoreboardPlayer]
}

private struct PadelScoreboard {
    let home: PadelScoreboardTeam
    let away: PadelScoreboardTeam
    let score: [PadelScoreboardScore]
}

private struct TeamScoreView: View {
    var score: Int

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            Text(String(score))
            Spacer(minLength: 0)
        }
    }
}

private struct PoweredByMoblinView: View {
    let backgroundColor: Color

    var body: some View {
        HStack {
            Text("Powered by Moblin")
                .fontDesign(.monospaced)
                .font(.system(size: 15))
                .bold()
            Spacer()
        }
        .padding([.leading, .trailing], 3)
        .padding([.bottom], 3)
        .background(backgroundColor)
    }
}

private func createPadelPlayer(players: [SettingsWidgetScoreboardPlayer], id: UUID) -> PadelScoreboardPlayer {
    return PadelScoreboardPlayer(name: findScoreboardPlayer(players: players, id: id))
}

private func findScoreboardPlayer(players: [SettingsWidgetScoreboardPlayer], id: UUID) -> String {
    return players.first(where: { $0.id == id })?.name ?? "🇸🇪 Moblin"
}

private func padelScoreboardSettingsToEffect(_ scoreboard: SettingsWidgetPadelScoreboard,
                                             _ players: [SettingsWidgetScoreboardPlayer]) -> PadelScoreboard
{
    var homePlayers = [createPadelPlayer(players: players, id: scoreboard.homePlayer1)]
    var awayPlayers = [createPadelPlayer(players: players, id: scoreboard.awayPlayer1)]
    if scoreboard.type == .doubles {
        homePlayers.append(createPadelPlayer(players: players, id: scoreboard.homePlayer2))
        awayPlayers.append(createPadelPlayer(players: players, id: scoreboard.awayPlayer2))
    }
    let home = PadelScoreboardTeam(players: homePlayers)
    let away = PadelScoreboardTeam(players: awayPlayers)
    let score = scoreboard.score.map { PadelScoreboardScore(home: $0.home, away: $0.away) }
    return PadelScoreboard(home: home, away: away, score: score)
}

private struct GenericScoreboardView: View {
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
            HStack(alignment: .center, spacing: 18) {
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
                .frame(width: 28)
                .font(.system(size: 45))
            }
            .padding([.leading, .trailing], 5)
            .background(primaryBackgroundColor)
            PoweredByMoblinView(backgroundColor: secondaryBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(textColor)
    }
}

private struct PadelScoreboardView: View {
    let textColor: Color
    let primaryBackgroundColor: Color
    let secondaryBackgroundColor: Color
    let padel: SettingsWidgetPadelScoreboard
    let players: [SettingsWidgetScoreboardPlayer]

    var body: some View {
        let scoreboard = padelScoreboardSettingsToEffect(padel, players)
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 18) {
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        ForEach(scoreboard.home.players) { player in
                            Text(player.name.uppercased())
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(alignment: .leading) {
                        Spacer(minLength: 0)
                        ForEach(scoreboard.away.players) { player in
                            Text(player.name.uppercased())
                        }
                        Spacer(minLength: 0)
                    }
                }
                .font(.system(size: 25))
                ForEach(scoreboard.score) { score in
                    VStack {
                        TeamScoreView(score: score.home)
                            .bold(score.isHomeWin())
                        TeamScoreView(score: score.away)
                            .bold(score.isAwayWin())
                    }
                    .frame(width: 28)
                    .font(.system(size: 45))
                }
                Spacer()
            }
            .padding([.leading, .trailing], 3)
            .padding([.top], 3)
            .background(primaryBackgroundColor)
            PoweredByMoblinView(backgroundColor: secondaryBackgroundColor)
        }
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .foregroundStyle(textColor)
    }
}

private struct ModularScoreboardView: View {
    let modular: SettingsWidgetModularScoreboard
    let config: RemoteControlScoreboardMatchConfig

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

    @ViewBuilder
    private func renderStackHistory(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) -> some View {
        let fontSize = modular.fontSize()
        let rowH = CGFloat(modular.rowHeight)
        let teamRowFullH = rowH + (modular.showMoreStats ? rowH * 0.6 : 0)
        let totalH = teamRowFullH * 2
        let periodFull = "\(config.global.periodLabel) \(config.global.period)"
        let activeStats = [config.global.timer, periodFull, config.global.subPeriod].filter {
            !$0.isEmpty
        }
        let subH = activeStats.isEmpty ? 0 : totalH / CGFloat(activeStats.count)
        let histW = fontSize * 1.5
        let maxHistory = calculateMaxHistory(config: config)
        let finalWidth = CGFloat(modular.width) + CGFloat(maxHistory) * histW
        if modular.showTitle {
            renderTitleBlock(title: config.global.title, modular: modular)
        }
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) {
                renderStackHistoryRow(
                    team: config.team1,
                    otherTeam: config.team2,
                    modular: modular,
                    textColor: modular.home.textColorColor,
                    backgroundColor: modular.home.backgroundColorColor,
                    histCount: maxHistory,
                    histW: histW,
                    currentPeriod: Int(config.global.period) ?? 1
                )
                renderStackHistoryRow(
                    team: config.team2,
                    otherTeam: config.team1,
                    modular: modular,
                    textColor: modular.away.textColorColor,
                    backgroundColor: modular.away.backgroundColorColor,
                    histCount: maxHistory,
                    histW: histW,
                    currentPeriod: Int(config.global.period) ?? 1
                )
            }
            .frame(width: finalWidth)
            if modular.showGlobalStatsBlock && !activeStats.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0 ..< activeStats.count, id: \.self) { i in
                        self.renderGlobalStatBox(val: activeStats[i], h: subH, modular: modular)
                    }
                }
                .frame(width: modular.fontSize() * 3.5, height: totalH)
                .background(.black)
            }
        }
    }

    @ViewBuilder
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
        let fontSize = modular.fontSize()
        let height = CGFloat(modular.rowHeight)
        let width = fontSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(team.name)
                    .font(.system(size: fontSize))
                    .bold(modular.isBold)
                    .lineLimit(1)
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: height)
                renderPossession(show: team.possession, size: fontSize)
                    .frame(height: height)
                if histCount > 0 {
                    ForEach(1 ... histCount, id: \.self) { i in
                        let val = self.getHistoricScore(team: team, indexPlusOne: i) ?? ""
                        let oppVal = self.getHistoricScore(team: otherTeam, indexPlusOne: i) ?? ""
                        let valInt = Int(val) ?? -1
                        let oppInt = Int(oppVal) ?? -1
                        let weight: Font.Weight = (i < currentPeriod && valInt > oppInt && valInt >= 0)
                            ? .black
                            : .medium
                        if !val.isEmpty {
                            self.renderStat(
                                val,
                                label: nil,
                                size: fontSize * 0.9,
                                width: histW,
                                height: height,
                                gray: true,
                                weight: weight
                            )
                        } else if !oppVal.isEmpty {
                            self.renderStat(
                                "0",
                                label: nil,
                                size: fontSize * 0.9,
                                width: histW,
                                height: height,
                                gray: true,
                                weight: .medium
                            )
                        } else {
                            Color.clear.frame(width: histW, height: height)
                        }
                    }
                }
                renderStat(
                    team.primaryScore,
                    label: nil,
                    size: fontSize,
                    width: width,
                    height: height,
                    gray: false
                )
            }
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

    @ViewBuilder
    private func renderStacked(modular: SettingsWidgetModularScoreboard,
                               config: RemoteControlScoreboardMatchConfig) -> some View
    {
        let rowH = CGFloat(modular.rowHeight)
        let teamRowFullH = rowH + (modular.showMoreStats ? rowH * 0.6 : 0)
        let totalH = teamRowFullH * 2
        let periodFull = "\(config.global.periodLabel) \(config.global.period)"
        let activeStats = [config.global.timer, periodFull, config.global.subPeriod].filter {
            !$0.isEmpty
        }
        let subH = activeStats.isEmpty ? 0 : totalH / CGFloat(activeStats.count)
        if modular.showTitle {
            renderTitleBlock(title: config.global.title, modular: modular)
        }
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
            if modular.showGlobalStatsBlock && !activeStats.isEmpty {
                VStack(spacing: 0) {
                    ForEach(0 ..< activeStats.count, id: \.self) { i in
                        self.renderGlobalStatBox(val: activeStats[i], h: subH, modular: modular)
                    }
                }
                .frame(width: modular.fontSize() * 3.5, height: totalH)
                .background(.black)
            }
        }
    }

    @ViewBuilder
    private func renderSideBySide(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) -> some View {
        let fontSize = modular.fontSize()
        let h = CGFloat(modular.rowHeight)
        let teamRowFullH = h + (modular.showMoreStats ? h * 0.6 : 0)
        let periodFull = "\(config.global.periodLabel) \(config.global.period)"
        if modular.showTitle {
            renderTitleBlock(title: config.global.title, modular: modular)
        }
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
                        if !periodFull.isEmpty {
                            Text(periodFull)
                                .font(.system(size: fontSize * 0.6, weight: .bold))
                        }
                        Text(config.global.timer)
                            .font(.system(size: fontSize * 0.9, weight: .black))
                            .monospacedDigit()
                    }
                    .frame(width: fontSize * 3.5, height: teamRowFullH)
                } else {
                    Text("-")
                        .font(.system(size: fontSize, weight: .black))
                        .frame(width: fontSize * 0.8, height: teamRowFullH)
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

    @ViewBuilder
    private func renderStackedRow(team: RemoteControlScoreboardTeam,
                                  modular: SettingsWidgetModularScoreboard,
                                  textColor: Color,
                                  backgroundColor: Color) -> some View
    {
        let fontSize = modular.fontSize()
        let height = CGFloat(modular.rowHeight)
        let width = fontSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if modular.layout == .stacked {
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        height: height,
                        gray: true
                    )
                }
                Text(team.name)
                    .font(.system(size: fontSize))
                    .bold(modular.isBold)
                    .lineLimit(1)
                    .padding(.leading, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: height)
                renderPossession(show: team.possession, size: fontSize)
                    .frame(height: height)
                if modular.layout == .stackedInline {
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        height: height,
                        gray: true
                    )
                }
                renderStat(
                    team.primaryScore,
                    label: nil,
                    size: fontSize,
                    width: width,
                    height: height,
                    gray: false
                )
            }
            .background(backgroundColor)
            if modular.showMoreStats {
                renderMoreStats(
                    team: team,
                    fontSize: fontSize,
                    height: height * 0.6,
                    backgroundColor: backgroundColor
                )
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
                        .frame(height: height)
                    Text(team.name)
                        .font(.system(size: fontSize))
                        .bold(modular.isBold)
                        .lineLimit(1)
                        .padding(.trailing, 4)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: height)
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        height: height,
                        gray: true
                    )
                    renderStat(
                        team.primaryScore,
                        label: nil,
                        size: fontSize,
                        width: width,
                        height: height,
                        gray: false
                    )
                } else {
                    renderStat(
                        team.primaryScore,
                        label: nil,
                        size: fontSize,
                        width: width,
                        height: height,
                        gray: false
                    )
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fontSize,
                        width: width,
                        height: height,
                        gray: true
                    )
                    Text(team.name)
                        .font(.system(size: fontSize))
                        .bold(modular.isBold)
                        .lineLimit(1)
                        .padding(.leading, 4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(height: height)
                    renderPossession(show: team.possession, size: fontSize)
                        .frame(height: height)
                }
            }
            .background(backgroundColor)
            if modular.showMoreStats {
                renderMoreStats(
                    team: team,
                    fontSize: fontSize,
                    height: height * 0.6,
                    backgroundColor: backgroundColor,
                    alignRight: !mirrored
                )
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
        height: CGFloat,
        gray: Bool,
        weight: Font.Weight = .black
    ) -> some View {
        if !val.isEmpty {
            ZStack {
                if gray {
                    Color.black
                        .opacity(0.25)
                        .frame(width: width, height: height)
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
            .frame(width: width, height: height)
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

    private func renderGlobalStatBox(val: String,
                                     h: CGFloat,
                                     modular: SettingsWidgetModularScoreboard) -> some View
    {
        ZStack {
            Text(val)
                .font(.system(size: modular.fontSize() * 0.9))
                .bold(modular.isBold)
                .monospacedDigit()
                .minimumScaleFactor(0.1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .foregroundStyle(.white)
    }

    private func renderTitleBlock(title: String, modular: SettingsWidgetModularScoreboard) -> some View {
        HCenter {
            Text(title)
                .font(.system(size: modular.fontSize() * 0.7))
                .bold(modular.isBold)
                .foregroundStyle(.white)
                .padding(.vertical, 1)
        }
        .background(.black)
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

final class ScoreboardEffect: VideoEffect {
    private var scoreboardImage: CIImage?
    private var sceneWidget: SettingsSceneWidget?

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    @MainActor
    func update(scoreboard: SettingsWidgetScoreboard,
                config: RemoteControlScoreboardMatchConfig,
                players: [SettingsWidgetScoreboardPlayer])
    {
        switch scoreboard.sport {
        case .generic:
            updateGeneric(textColor: scoreboard.textColorColor,
                          primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                          secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                          generic: scoreboard.generic)
        case .padel:
            updatePadel(textColor: scoreboard.textColorColor,
                        primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                        secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                        padel: scoreboard.padel,
                        players: players)
        default:
            updateModular(modular: scoreboard.modular, config: config)
        }
    }

    override func execute(_ image: CIImage, _: VideoEffectInfo) -> CIImage {
        guard let scoreboardImage, let sceneWidget else {
            return image
        }
        let scale = image.extent.size.maximum() / 1920
        return scoreboardImage
            .scaled(x: scale, y: scale)
            .move(sceneWidget.layout, image.extent.size)
            .cropped(to: image.extent)
            .composited(over: image)
    }

    private func setScoreboardImage(image: CIImage?) {
        processorPipelineQueue.async {
            self.scoreboardImage = image
        }
    }

    @MainActor
    private func updateGeneric(textColor: Color,
                               primaryBackgroundColor: Color,
                               secondaryBackgroundColor: Color,
                               generic: SettingsWidgetGenericScoreboard)
    {
        let scoreboard = GenericScoreboardView(textColor: textColor,
                                               primaryBackgroundColor: primaryBackgroundColor,
                                               secondaryBackgroundColor: secondaryBackgroundColor,
                                               generic: generic)
        setScoreboardImage(image: ImageRenderer(content: scoreboard).ciImage())
    }

    @MainActor
    private func updatePadel(textColor: Color,
                             primaryBackgroundColor: Color,
                             secondaryBackgroundColor: Color,
                             padel: SettingsWidgetPadelScoreboard,
                             players: [SettingsWidgetScoreboardPlayer])
    {
        let scoreboard = PadelScoreboardView(textColor: textColor,
                                             primaryBackgroundColor: primaryBackgroundColor,
                                             secondaryBackgroundColor: secondaryBackgroundColor,
                                             padel: padel,
                                             players: players)
        setScoreboardImage(image: ImageRenderer(content: scoreboard).ciImage())
    }

    @MainActor
    private func updateModular(
        modular: SettingsWidgetModularScoreboard,
        config: RemoteControlScoreboardMatchConfig
    ) {
        let scoreboard = ModularScoreboardView(modular: modular, config: config)
        setScoreboardImage(image: ImageRenderer(content: scoreboard).ciImage())
    }
}
