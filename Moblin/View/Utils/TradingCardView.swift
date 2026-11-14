import SwiftUI

func strokeTradingCardDash(
    context: GraphicsContext,
    path: Path,
    color: Color,
    lineWidth: Double,
    dash: Double,
    gap: Double,
    time: Double
) {
    let length = dash + gap
    let period = length * 0.055
    let phase = -length * time.truncatingRemainder(dividingBy: period) / period
    context.stroke(path,
                   with: .color(color),
                   style: StrokeStyle(lineWidth: lineWidth, dash: [dash, gap], dashPhase: phase))
}

func tradingCardPulseOpacity(time: Double) -> Double {
    let progress = time.truncatingRemainder(dividingBy: 1.6) / 1.6
    let x = progress < 0.5 ? 2 * progress : 2 - 2 * progress
    return 1 - 0.75 * x * x * (3 - 2 * x)
}

struct TradingCardView: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    let name: String
    let background: Color
    var hasFront = true
    var draw: ((GraphicsContext, Double) -> Void)?

    var body: some View {
        ZStack {
            if let draw {
                Image("\(name)CardBack")
                    .resizable()
                TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion)) { timeline in
                    Canvas { context, size in
                        let scale = size.width / 260
                        context.scaleBy(x: scale, y: scale)
                        draw(context, timeline.date.timeIntervalSinceReferenceDate)
                    }
                }
                if hasFront {
                    Image("\(name)CardFront")
                        .resizable()
                }
            } else {
                Image("\(name)Card")
                    .resizable()
            }
        }
        .aspectRatio(260 / 150, contentMode: .fit)
        .frame(maxWidth: 500)
        .frame(maxWidth: .infinity)
        .background(background)
        .listRowInsets(EdgeInsets())
        .accessibilityHidden(true)
    }
}
