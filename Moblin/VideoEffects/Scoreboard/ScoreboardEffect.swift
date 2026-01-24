import SwiftUI

struct TopBottomBorder: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}

final class ScoreboardEffect: VideoEffect {
    private var scoreboardImage: CIImage?
    private var sceneWidget: SettingsSceneWidget?

    override func getName() -> String {
        return "Scoreboard"
    }

    func setSceneWidget(sceneWidget: SettingsSceneWidget) {
        processorPipelineQueue.async {
            self.sceneWidget = sceneWidget
        }
    }

    @MainActor
    func update(scoreboard: SettingsWidgetScoreboard) {
        updateModular(scoreboard: scoreboard)
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
    private func updateModular(scoreboard: SettingsWidgetScoreboard) {
        guard let config = MoblinApp.globalModel?.getCurrentConfigForEffect() else {
            return
        }
        let content = VStack(alignment: .center, spacing: 0) {
            if scoreboard.layout == .sideBySide {
                renderSideBySide(scoreboard: scoreboard, ext: config)
            } else if scoreboard.layout == .stackhistory {
                renderStackHistory(scoreboard: scoreboard, ext: config)
            } else {
                renderStacked(scoreboard: scoreboard, ext: config)
            }
        }
        .padding(0)
        .overlay(TopBottomBorder()
            .stroke(Color.white, lineWidth: 0.5))
        .padding(5)
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            setScoreboardImage(image: CIImage(image: image))
        }
    }

    private func calculateMaxHistory(ext: SBMatchConfig) -> Int {
        var maxHistory = 0
        for i in 1 ... 5 {
            let t1Has = !(getHistoryVal(team: ext.team1, i: i).isEmpty)
            let t2Has = !(getHistoryVal(team: ext.team2, i: i).isEmpty)
            if t1Has || t2Has {
                maxHistory = i
            }
        }
        return maxHistory
    }

    @ViewBuilder
    private func renderStackHistory(scoreboard: SettingsWidgetScoreboard, ext: SBMatchConfig) -> some View {
        let fSize = CGFloat(scoreboard.stackedFontSize)
        let rowH = CGFloat(scoreboard.stackedRowHeight)
        let teamRowFullH = rowH + (scoreboard.showSecondaryRows ? rowH * 0.6 : 0)
        let totalH = teamRowFullH * 2
        let periodFull = "\(ext.global.periodLabel) \(ext.global.period)".trimmingCharacters(in: .whitespaces)
        let activeStats = [ext.global.timer, periodFull, ext.global.subPeriod].filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let subH = activeStats.isEmpty ? 0 : totalH / CGFloat(activeStats.count)
        let histW = fSize * 1.5
        let maxHistory = calculateMaxHistory(ext: ext)
        let extraWidth = CGFloat(maxHistory) * histW
        let finalWidth = CGFloat(scoreboard.stackedWidth) + extraWidth
        VStack(spacing: 0) {
            if scoreboard.showStackedHeader && scoreboard.titleAbove {
                renderTitleBlock(title: ext.global.title, scorebaord: scoreboard, isStacked: true)
            }
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    renderStackHistoryRow(
                        team: ext.team1,
                        opp: ext.team2,
                        scoreboard: scoreboard,
                        backgroundColor: scoreboard.team1BgColorColor,
                        textColor: scoreboard.team1TextColorColor,
                        histCount: maxHistory,
                        histW: histW,
                        currentPeriod: Int(ext.global.period) ?? 1
                    )
                    renderStackHistoryRow(
                        team: ext.team2,
                        opp: ext.team1,
                        scoreboard: scoreboard,
                        backgroundColor: scoreboard.team2BgColorColor,
                        textColor: scoreboard.team2TextColorColor,
                        histCount: maxHistory,
                        histW: histW,
                        currentPeriod: Int(ext.global.period) ?? 1
                    )
                }
                .frame(width: finalWidth)
                if scoreboard.showGlobalStatsBlock && !activeStats.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(0 ..< activeStats.count, id: \.self) { i in
                            self.renderGlobalStatBox(val: activeStats[i], h: subH, scoreboard: scoreboard)
                        }
                    }
                    .frame(width: CGFloat(scoreboard.stackedFontSize * 3.5))
                    .frame(height: totalH)
                    .background(Color.black)
                }
            }
            if scoreboard.showStackedHeader && !scoreboard.titleAbove {
                renderTitleBlock(title: ext.global.title, scorebaord: scoreboard, isStacked: true)
            }
            if scoreboard.showStackedFooter {
                renderFooterBlock(scoreboard: scoreboard)
            }
        }
    }

    @ViewBuilder
    private func renderStackHistoryRow(
        team: SBTeam,
        opp: SBTeam,
        scoreboard: SettingsWidgetScoreboard,
        backgroundColor: Color,
        textColor: Color,
        histCount: Int,
        histW: CGFloat,
        currentPeriod: Int
    ) -> some View {
        let fSize = CGFloat(scoreboard.stackedFontSize), h = CGFloat(scoreboard.stackedRowHeight),
            boxW = fSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                Text(team.name)
                    .font(.system(size: fSize, weight: scoreboard.stackedIsBold ? .bold : .regular))
                    .italic(scoreboard.stackedIsItalic)
                    .lineLimit(1)
                    .padding(.leading, 6)
                    .padding(.trailing, 2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: h)
                renderPossession(show: team.possession, size: fSize)
                    .padding(.horizontal, 2).frame(height: h)
                if histCount > 0 {
                    ForEach(1 ... histCount, id: \.self) { i in
                        let val = self.getHistoryVal(team: team, i: i)
                        let oppVal = self.getHistoryVal(team: opp, i: i)
                        let vInt = Int(val) ?? -1
                        let oInt = Int(oppVal) ?? -1
                        let weight: Font
                            .Weight = (i < currentPeriod && vInt > oInt && vInt >= 0) ? .black : .medium
                        if !val.isEmpty {
                            self.renderStat(
                                val,
                                label: nil,
                                size: fSize * 0.9,
                                w: histW,
                                h: h,
                                gray: true,
                                it: false,
                                weight: weight
                            )
                        } else if !oppVal.isEmpty {
                            self.renderStat(
                                "0",
                                label: nil,
                                size: fSize * 0.9,
                                w: histW,
                                h: h,
                                gray: true,
                                it: false,
                                weight: .medium
                            )
                        } else {
                            Color.clear.frame(width: histW, height: h)
                        }
                    }
                }
                renderStat(
                    team.primaryScore,
                    label: nil,
                    size: fSize,
                    w: boxW,
                    h: h,
                    gray: false,
                    it: scoreboard.stackedIsItalic
                )
            }
            .background(backgroundColor)
            .foregroundStyle(textColor)
            if scoreboard.showSecondaryRows {
                renderSecondaryRow(team: team, fSize: fSize, h: h * 0.6)
            }
        }
    }

    private func getHistoryVal(team: SBTeam, i: Int) -> String {
        switch i {
        case 1:
            return team.secondaryScore1 ?? ""
        case 2:
            return team.secondaryScore2 ?? ""
        case 3:
            return team.secondaryScore3 ?? ""
        case 4:
            return team.secondaryScore4 ?? ""
        case 5:
            return team.secondaryScore5 ?? ""
        default:
            return ""
        }
    }

    @ViewBuilder
    private func renderStacked(scoreboard: SettingsWidgetScoreboard, ext: SBMatchConfig) -> some View {
        let _ = CGFloat(scoreboard.stackedFontSize), rowH = CGFloat(scoreboard.stackedRowHeight)
        let teamRowFullH = rowH + (scoreboard.showSecondaryRows ? rowH * 0.6 : 0)
        let totalH = teamRowFullH * 2
        let periodFull = "\(ext.global.periodLabel) \(ext.global.period)".trimmingCharacters(in: .whitespaces)
        let activeStats = [ext.global.timer, periodFull, ext.global.subPeriod].filter {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        let subH = activeStats.isEmpty ? 0 : totalH / CGFloat(activeStats.count)
        VStack(spacing: 0) {
            if scoreboard.showStackedHeader && scoreboard.titleAbove {
                renderTitleBlock(title: ext.global.title, scorebaord: scoreboard, isStacked: true)
            }
            HStack(alignment: .top, spacing: 0) {
                VStack(spacing: 0) {
                    renderStackedRow(
                        team: ext.team1,
                        scoreboard: scoreboard,
                        backgroundColor: scoreboard.team1BgColorColor,
                        textColor: scoreboard.team1TextColorColor
                    )
                    renderStackedRow(
                        team: ext.team2,
                        scoreboard: scoreboard,
                        backgroundColor: scoreboard.team2BgColorColor,
                        textColor: scoreboard.team2TextColorColor
                    )
                }
                .frame(width: CGFloat(scoreboard.stackedWidth))
                if scoreboard.showGlobalStatsBlock && !activeStats.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(0 ..< activeStats.count, id: \.self) { i in
                            self.renderGlobalStatBox(val: activeStats[i], h: subH, scoreboard: scoreboard)
                        }
                    }
                    .frame(width: CGFloat(scoreboard.stackedFontSize * 3.5))
                    .frame(height: totalH)
                    .background(Color.black)
                }
            }
            if scoreboard.showStackedHeader && !scoreboard.titleAbove {
                renderTitleBlock(title: ext.global.title, scorebaord: scoreboard, isStacked: true)
            }
            if scoreboard.showStackedFooter {
                renderFooterBlock(scoreboard: scoreboard)
            }
        }
    }

    @ViewBuilder
    private func renderSideBySide(scoreboard: SettingsWidgetScoreboard, ext: SBMatchConfig) -> some View {
        let fSize = CGFloat(scoreboard.sbsFontSize), h = CGFloat(scoreboard.sbsRowHeight)
        let teamRowFullH = h + (scoreboard.showSecondaryRows ? h * 0.6 : 0)
        let periodFull = "\(ext.global.periodLabel) \(ext.global.period)".trimmingCharacters(in: .whitespaces)
        VStack(spacing: 2) {
            if scoreboard.showSbsTitle && scoreboard.titleAbove && !ext.global.title.isEmpty {
                renderTitleBlock(title: ext.global.title, scorebaord: scoreboard, isStacked: false)
            }
            HStack(spacing: 0) {
                renderSbsHalf(
                    team: ext.team1,
                    scoreboard: scoreboard,
                    backgroundColor: scoreboard.team1BgColorColor,
                    textColor: scoreboard.team1TextColorColor,
                    mirrored: false
                )
                Group {
                    if scoreboard.showGlobalStatsBlock {
                        VStack(spacing: 0) {
                            if !periodFull.isEmpty {
                                Text(periodFull)
                                    .font(.system(size: fSize * 0.6, weight: .bold))
                            }
                            Text(ext.global.timer)
                                .font(.system(size: fSize * 0.9, weight: .black))
                                .monospacedDigit()
                        }
                        .frame(width: fSize * 3.5)
                        .frame(height: teamRowFullH)
                    } else {
                        Text("-")
                            .font(.system(size: fSize, weight: .black))
                            .frame(width: fSize * 0.8)
                            .frame(height: teamRowFullH)
                    }
                }
                .background(Color.black)
                .foregroundStyle(.white)
                renderSbsHalf(
                    team: ext.team2,
                    scoreboard: scoreboard,
                    backgroundColor: scoreboard.team2BgColorColor,
                    textColor: scoreboard.team2TextColorColor,
                    mirrored: true
                )
            }
            .frame(width: CGFloat(scoreboard.sbsWidth))
            .overlay(TopBottomBorder()
                .stroke(Color.white, lineWidth: 0.5))
            if scoreboard.showSbsTitle && !scoreboard.titleAbove && !ext.global.title.isEmpty {
                renderTitleBlock(title: ext.global.title, scorebaord: scoreboard, isStacked: false)
            }
        }
    }

    @ViewBuilder
    private func renderStackedRow(team: SBTeam,
                                  scoreboard: SettingsWidgetScoreboard,
                                  backgroundColor: Color,
                                  textColor: Color) -> some View
    {
        let fSize = CGFloat(scoreboard.stackedFontSize), h = CGFloat(scoreboard.stackedRowHeight),
            boxW = fSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if scoreboard.layout == .stacked {
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fSize,
                        w: boxW,
                        h: h,
                        gray: true,
                        it: scoreboard.stackedIsItalic
                    )
                }
                Text(team.name).font(.system(
                    size: fSize,
                    weight: scoreboard.stackedIsBold ? .bold : .regular
                ))
                .italic(scoreboard.stackedIsItalic).lineLimit(1).padding(
                    .leading,
                    3
                ).frame(maxWidth: .infinity, alignment: .leading).frame(height: h)
                renderPossession(show: team.possession, size: fSize).padding(.horizontal, 2).frame(height: h)
                if scoreboard.layout == .stackedInline {
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fSize,
                        w: boxW,
                        h: h,
                        gray: true,
                        it: scoreboard.stackedIsItalic
                    )
                }
                renderStat(
                    team.primaryScore,
                    label: nil,
                    size: fSize,
                    w: boxW,
                    h: h,
                    gray: false,
                    it: scoreboard.stackedIsItalic
                )
            }.background(backgroundColor).foregroundStyle(textColor)
            if scoreboard.showSecondaryRows {
                renderSecondaryRow(
                    team: team,
                    fSize: fSize,
                    h: h * 0.6,
                    backgroundColor: backgroundColor,
                    textColor: textColor
                )
            }
        }
    }

    @ViewBuilder
    private func renderSbsHalf(
        team: SBTeam,
        scoreboard: SettingsWidgetScoreboard,
        backgroundColor: Color,
        textColor: Color,
        mirrored: Bool
    ) -> some View {
        let fSize = CGFloat(scoreboard.sbsFontSize)
        let h = CGFloat(scoreboard.sbsRowHeight)
        let boxW = fSize * 1.55
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !mirrored {
                    renderPossession(show: team.possession, size: fSize).padding(.horizontal, 2)
                        .frame(height: h)
                    Text(team.name).font(.system(
                        size: fSize,
                        weight: scoreboard.sbsIsBold ? .bold : .regular
                    ))
                    .italic(scoreboard.sbsIsItalic).lineLimit(1).padding(
                        .trailing,
                        4
                    ).frame(maxWidth: .infinity, alignment: .trailing).frame(height: h)
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fSize,
                        w: boxW,
                        h: h,
                        gray: true,
                        it: scoreboard.sbsIsItalic
                    )
                    renderStat(
                        team.primaryScore,
                        label: nil,
                        size: fSize,
                        w: boxW,
                        h: h,
                        gray: false,
                        it: scoreboard.sbsIsItalic
                    )
                } else {
                    renderStat(
                        team.primaryScore,
                        label: nil,
                        size: fSize,
                        w: boxW,
                        h: h,
                        gray: false,
                        it: scoreboard.sbsIsItalic
                    )
                    renderStat(
                        team.secondaryScore,
                        label: team.secondaryScoreLabel,
                        size: fSize,
                        w: boxW,
                        h: h,
                        gray: true,
                        it: scoreboard.sbsIsItalic
                    )
                    Text(team.name).font(.system(
                        size: fSize,
                        weight: scoreboard.sbsIsBold ? .bold : .regular
                    ))
                    .italic(scoreboard.sbsIsItalic).lineLimit(1).padding(
                        .leading,
                        4
                    ).frame(maxWidth: .infinity, alignment: .leading).frame(height: h)
                    renderPossession(show: team.possession, size: fSize).padding(.horizontal, 2)
                        .frame(height: h)
                }
            }.background(backgroundColor).foregroundStyle(textColor)
            // PASS COLORS HERE:
            if scoreboard.showSecondaryRows { renderSecondaryRow(
                team: team,
                fSize: fSize,
                h: h * 0.6,
                alignRight: !mirrored,
                backgroundColor: backgroundColor,
                textColor: textColor
            ) }
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func renderStat(
        _ val: String,
        label: String?,
        size: CGFloat,
        w: CGFloat,
        h: CGFloat,
        gray: Bool,
        it: Bool,
        weight: Font.Weight = .black
    ) -> some View {
        if !val.trimmingCharacters(in: .whitespaces).isEmpty {
            ZStack {
                if gray { Color.black.opacity(0.25).frame(width: w, height: h) }
                if let label = label, !label.isEmpty {
                    VStack(spacing: -2) {
                        Text(label).font(.system(size: size * 0.35, weight: .bold))
                            .foregroundStyle(.white.opacity(0.8)).padding(
                                .top,
                                2
                            )
                        Text(val).font(.system(size: size * 0.8, weight: weight)).italic(it)
                    }
                } else {
                    Text(val).font(.system(size: size, weight: weight)).italic(it)
                }
            }.frame(width: w, height: h)
        }
    }

    @ViewBuilder
    private func renderSecondaryRow(
        team: SBTeam,
        fSize: CGFloat,
        h: CGFloat,
        alignRight: Bool = false,
        backgroundColor: Color = .black,
        textColor: Color = .white
    ) -> some View {
        let stats = [
            (team.stat1Label, team.stat1),
            (team.stat2Label, team.stat2),
            (team.stat3Label, team.stat3),
            (team.stat4Label, team.stat4),
        ]
        .filter { !$0.1.isEmpty && !$0.1.hasPrefix("NO ") }
        HStack(spacing: 8) {
            if alignRight {
                Spacer()
            }
            ForEach(0 ..< stats.count, id: \.self) { i in
                HStack(spacing: 2) {
                    if !stats[i].0.isEmpty { Text(stats[i].0 + ":").opacity(0.8) }
                    Text(stats[i].1).monospacedDigit()
                }
                .font(.system(size: fSize * 0.65, weight: .bold))
                .minimumScaleFactor(0.5)
            }
            if !alignRight {
                Spacer()
            }
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .background(
            ZStack {
                backgroundColor
                Color.black.opacity(0.25)
            }
        )
        .foregroundStyle(textColor)
    }

    @ViewBuilder
    private func renderPossession(show: Bool, size: CGFloat) -> some View {
        ZStack {
            if show {
                Image("VolleyballIndicator")
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .frame(width: size * 1.1)
                    .foregroundStyle(.white)
            }
        }
    }

    @ViewBuilder
    private func renderGlobalStatBox(val: String, h: CGFloat,
                                     scoreboard: SettingsWidgetScoreboard) -> some View
    {
        let fSize = scoreboard.layout == .stacked
            || scoreboard.layout == .stackhistory
            || scoreboard
            .layout == .stackedInline ? CGFloat(scoreboard.stackedFontSize) :
            CGFloat(scoreboard.sbsFontSize)
        let weight: Font.Weight = (scoreboard.layout == .stacked
            || scoreboard.layout == .stackhistory
            || scoreboard.layout == .stackedInline ? scoreboard.stackedIsBold : scoreboard.sbsIsBold) ?
            .bold :
            .regular
        let italic = scoreboard.layout == .stacked
            || scoreboard.layout == .stackhistory
            || scoreboard.layout == .stackedInline ? scoreboard.stackedIsItalic : scoreboard.sbsIsItalic
        ZStack {
            Text(val)
                .font(.system(size: fSize * 0.9, weight: weight))
                .italic(italic)
                .monospacedDigit()
                .minimumScaleFactor(0.1)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func renderTitleBlock(title: String, scorebaord: SettingsWidgetScoreboard,
                                  isStacked: Bool) -> some View
    {
        let fSize = isStacked ? CGFloat(scorebaord.stackedFontSize) : CGFloat(scorebaord.sbsFontSize)
        let weight: Font
            .Weight = (isStacked ? scorebaord.stackedIsBold : scorebaord.sbsIsBold) ? .bold : .regular
        let italic = isStacked ? scorebaord.stackedIsItalic : scorebaord.sbsIsItalic
        Text(title.uppercased())
            .font(.system(size: fSize * 0.7, weight: weight))
            .italic(italic)
            .foregroundStyle(scorebaord.team1TextColorColor)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity)
            .background(scorebaord.secondaryBackgroundColorColor)
    }

    @ViewBuilder
    private func renderFooterBlock(scoreboard: SettingsWidgetScoreboard) -> some View {
        HStack {
            Text("Powered by Moblin")
                .fontDesign(.monospaced)
                .font(.system(size: CGFloat(scoreboard.stackedFontSize * 0.5), weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(scoreboard.secondaryBackgroundColorColor)
        .foregroundStyle(scoreboard.team1TextColorColor)
    }
}
