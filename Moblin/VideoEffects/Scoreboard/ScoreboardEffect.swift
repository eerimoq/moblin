import AVFoundation
import SwiftUI
import UIKit
import Vision

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
    func update(scoreboard: SettingsWidgetScoreboard, players: [SettingsWidgetScoreboardPlayer]) {
        switch scoreboard.type {
        case .padel:
            updatePadel(textColor: scoreboard.textColorColor,
                        primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                        secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                        padel: scoreboard.padel,
                        players: players)
        case .generic:
            updateGeneric(textColor: scoreboard.textColorColor,
                          primaryBackgroundColor: scoreboard.primaryBackgroundColorColor,
                          secondaryBackgroundColor: scoreboard.secondaryBackgroundColorColor,
                          scoreboard: scoreboard)
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
    private func updatePadel(textColor: Color,
                             primaryBackgroundColor: Color,
                             secondaryBackgroundColor: Color,
                             padel: SettingsWidgetPadelScoreboard,
                             players: [SettingsWidgetScoreboardPlayer])
    {
        let scoreboard = padelScoreboardSettingsToEffect(padel, players)
        let scoreBoard = VStack(alignment: .leading, spacing: 0) {
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
        let renderer = ImageRenderer(content: scoreBoard)
        guard let image = renderer.uiImage else {
            return
        }
        setScoreboardImage(image: CIImage(image: image))
    }

    @MainActor
    private func updateGeneric(textColor: Color,
                               primaryBackgroundColor: Color,
                               secondaryBackgroundColor: Color,
                               scoreboard: SettingsWidgetScoreboard)
    {
        let generic = scoreboard.generic
        let layout = scoreboard.layout
        
        var t1Bg = primaryBackgroundColor, t2Bg = primaryBackgroundColor
        var t1Txt = textColor, t2Txt = textColor
        var t1Match = 0, t2Match = 0
        var t1Serve = false, t2Serve = false

        if let ext = MoblinApp.globalModel?.externalScoreboard {
            t1Bg = Color(hex: ext.team1.bgColor); t1Txt = Color(hex: ext.team1.textColor)
            t1Match = ext.team1.matchScore; t1Serve = ext.team1.serving
            t2Bg = Color(hex: ext.team2.bgColor); t2Txt = Color(hex: ext.team2.textColor)
            t2Match = ext.team2.matchScore; t2Serve = ext.team2.serving
        }

        let content = VStack(alignment: .center, spacing: 2) {
            if layout == .sideBySide {
                renderSideBySideTicker(sb: scoreboard, generic: generic,
                                       t1: (t1Bg, t1Txt, t1Match, t1Serve),
                                       t2: (t2Bg, t2Txt, t2Match, t2Serve))
                
                if scoreboard.showSbsTitle {
                    Text(generic.title)
                        .font(.system(size: CGFloat(scoreboard.sbsFontSize * 0.7), weight: .bold))
                        .foregroundStyle(textColor)
                }
            } else {
                // (Stacked logic remains here...)
                VStack(alignment: .leading, spacing: 0) {
                    if scoreboard.showStackedHeader {
                        HStack {
                            Text(generic.title)
                            Spacer()
                            Text(generic.clock()).monospacedDigit()
                        }
                        .font(.system(size: CGFloat(scoreboard.stackedFontSize * 0.7), weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(secondaryBackgroundColor).foregroundStyle(textColor)
                    }

                    renderTeamRow(name: generic.home, score: generic.score.home, match: t1Match, serve: t1Serve, bg: t1Bg, txt: t1Txt, sb: scoreboard)
                    renderTeamRow(name: generic.away, score: generic.score.away, match: t2Match, serve: t2Serve, bg: t2Bg, txt: t2Txt, sb: scoreboard)

                    if scoreboard.showStackedFooter {
                        HStack {
                            Text("Powered by Moblin").fontDesign(.monospaced)
                            Spacer()
                        }
                        .font(.system(size: CGFloat(scoreboard.stackedFontSize * 0.7), weight: .bold))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(secondaryBackgroundColor).foregroundStyle(textColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 5))
                .frame(width: CGFloat(scoreboard.stackedWidth))
            }
        }
        
        let renderer = ImageRenderer(content: content)
        renderer.scale = UIScreen.main.scale
        if let image = renderer.uiImage {
            setScoreboardImage(image: CIImage(image: image))
        }
    }

    @ViewBuilder
    private func renderSideBySideTicker(sb: SettingsWidgetScoreboard,
                                         generic: SettingsWidgetGenericScoreboard,
                                         t1: (bg: Color, txt: Color, m: Int, s: Bool),
                                         t2: (bg: Color, txt: Color, m: Int, s: Bool)) -> some View {
        let h = CGFloat(sb.sbsRowHeight)
        let fSize = CGFloat(sb.sbsFontSize)
        let weight: Font.Weight = sb.sbsIsBold ? .bold : .regular
        let font = Font.system(size: fSize, weight: weight)
        let scoreBoxW = fSize * 2.2
        let matchBoxW = fSize * 1.6
        let serveW = fSize * 1.2

        HStack(spacing: 0) {
            //home team
            HStack(spacing: 0) {
                //serving indicator
                ZStack { if t1.s { Image("VolleyballIndicator").resizable().renderingMode(.template).scaledToFit().frame(width: fSize * 1.3).foregroundStyle(.white) } }
                .frame(width: serveW).frame(height: h)
                //name
                Text(generic.home.uppercased()).font(font).italic(sb.sbsIsItalic).lineLimit(1).padding(.trailing, 3)
                    .frame(maxWidth: .infinity, alignment: .trailing).frame(height: h)
                //match score
                Text("\(t1.m)").font(font).italic(sb.sbsIsItalic).frame(width: matchBoxW).frame(height: h)
                    .background(Color.black.opacity(0.25))
                //set score
                Text("\(generic.score.home)").font(font).italic(sb.sbsIsItalic).frame(width: scoreBoxW).frame(height: h)
            }
            .background(t1.bg).foregroundStyle(t1.txt)
            //separator
            Text("-").font(font).bold().frame(width: fSize * 0.8).frame(height: h)
                .background(Color.black).foregroundStyle(.white)

            //away team
            HStack(spacing: 0) {
                //set score
                Text("\(generic.score.away)").font(font).italic(sb.sbsIsItalic).frame(width: scoreBoxW).frame(height: h)
                //match score
                Text("\(t2.m)").font(font).italic(sb.sbsIsItalic).frame(width: matchBoxW).frame(height: h)
                    .background(Color.black.opacity(0.25))
                //name
                Text(generic.away.uppercased()).font(font).italic(sb.sbsIsItalic).lineLimit(1).padding(.leading, 3)
                    .frame(maxWidth: .infinity, alignment: .leading).frame(height: h)
                //serving indicator
                ZStack { if t2.s { Image("VolleyballIndicator").resizable().renderingMode(.template).scaledToFit().frame(width: fSize * 1.3).foregroundStyle(.white) } }
                .frame(width: serveW).frame(height: h)
            }
            .background(t2.bg).foregroundStyle(t2.txt)
        }
        .frame(width: CGFloat(sb.sbsWidth))
        .clipShape(RoundedRectangle(cornerRadius: 5))
    }

    @ViewBuilder
    private func renderTeamRow(name: String, score: Int, match: Int, serve: Bool, bg: Color, txt: Color, sb: SettingsWidgetScoreboard) -> some View {
        let h = CGFloat(sb.stackedRowHeight)
        let fSize = CGFloat(sb.stackedFontSize)
        let scoreBoxWidth = fSize * 2.2
        let serveColumnWidth = fSize * 1.0
        let rowFont = Font.system(size: fSize, weight: sb.stackedIsBold ? .bold : .regular)

        HStack(spacing: 0) {
            Text("\(match)")
                .font(rowFont).italic(sb.stackedIsItalic)
                .frame(width: scoreBoxWidth, height: h)
                .background(Color.black.opacity(0.25))
            
            Text(name.uppercased())
                .font(rowFont).italic(sb.stackedIsItalic)
                .lineLimit(1)
                .padding(.leading, 3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: h)
            
            ZStack {
                if serve {
                    Image("VolleyballIndicator").resizable().renderingMode(.template).scaledToFit()
                        .frame(width: fSize * 1.3).foregroundStyle(.white)
                }
            }
            .frame(width: serveColumnWidth, height: h)

            Text("\(score)")
                .font(rowFont).italic(sb.stackedIsItalic)
                .frame(width: scoreBoxWidth, height: h)
        }
        .background(bg).foregroundStyle(txt)
    }

    @ViewBuilder
    private func renderTeamBox(name: String, score: Int, match: Int, serve: Bool, bg: Color, txt: Color, sb: SettingsWidgetScoreboard) -> some View {
        VStack(spacing: 0) {
            Text(name.uppercased())
                .font(.system(size: 16, weight: .bold))
                .lineLimit(1)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(bg)
                .foregroundStyle(txt)
            
            HStack(spacing: 0) {
                VStack {
                    Text("SET").font(.system(size: 8))
                    Text("\(score)").font(.system(size: 30, weight: .black))
                }
                .frame(maxWidth: .infinity)
                
                VStack {
                    if serve {
                        Image("VolleyballIndicator")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .frame(width: 15) // Fixed size for Side-by-Side box
                            .foregroundStyle(.white)
                    } else {
                        Rectangle().fill(.white.opacity(0.2)).frame(width: 1, height: 20)
                    }
                }
                
                VStack {
                    Text("SETS").font(.system(size: 8))
                    Text("\(match)").font(.system(size: 22, weight: .bold))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.4))
            .foregroundStyle(.white)
        }
        .frame(width: 165)
        .cornerRadius(5)
    }
} //end of scoreboard

//color helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255, opacity: Double(a) / 255)
    }
}
