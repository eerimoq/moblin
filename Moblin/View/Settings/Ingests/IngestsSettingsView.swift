import SwiftUI

private func drawIngestsCable(
    context: GraphicsContext,
    y: Double,
    endOffset: Double,
    endX: Double,
    time: Double
) {
    var path = Path()
    path.move(to: CGPoint(x: 34, y: y))
    path.addCurve(to: CGPoint(x: endX, y: 112 + endOffset),
                  control1: CGPoint(x: 80, y: y),
                  control2: CGPoint(x: 95, y: 112 + endOffset))
    strokeTradingCardDash(context: context,
                          path: path,
                          color: .white.opacity(0.7),
                          lineWidth: 1.5,
                          dash: 6,
                          gap: 10,
                          time: time)
}

private func drawIngestsCard(context: GraphicsContext, time: Double) {
    drawIngestsCable(context: context, y: 24, endOffset: -8, endX: 150, time: time)
    drawIngestsCable(context: context, y: 54, endOffset: -2, endX: 150, time: time)
    drawIngestsCable(context: context, y: 84, endOffset: 4, endX: 150, time: time)
    drawIngestsCable(context: context, y: 114, endOffset: 10, endX: 155, time: time)
}

struct IngestsSettingsView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                TradingCardView(name: "Ingests",
                                background: Color(red: 0xE4 / 255, green: 0xE1 / 255, blue: 0xD3 / 255),
                                draw: drawIngestsCard)
            }
            Section {
                RtmpServerSettingsView(rtmpServer: database.rtmpServer)
                SrtlaServerSettingsView(srtlaServer: database.srtlaServer)
                SrtClientSettingsView(srtClient: database.srtClient)
                RistServerSettingsView(model: model, ristServer: database.ristServer)
                RtspClientSettingsView(model: model, rtspClient: database.rtspClient)
                WhipServerSettingsView(whipServer: database.whipServer)
                WhepClientSettingsView(model: model, whepClient: database.whepClient)
                if #available(iOS 26, *), false {
                    #if !targetEnvironment(macCatalyst)
                    NavigationLink {
                        WiFiAwareSettingsView(model: model, wiFiAware: database.wiFiAware)
                    } label: {
                        Text(String("WiFi Aware"))
                    }
                    #endif
                }
            }
            Section {
                Toggle("Software video decoding", isOn: $database.ingestsSoftwareVideoDecoding)
                    .onChange(of: database.ingestsSoftwareVideoDecoding) { _ in
                        model.reloadIngests()
                    }
            } footer: {
                VStack(alignment: .leading) {
                    Text("""
                    Decode ingested video on the CPU instead of using the hardware video decoder. \
                    Uses more CPU, battery and generates more heat, but can decode video the hardware \
                    decoder does not support and allows decoding more streams at the same time.
                    """)
                    Text("")
                    Text("Only enable this if hardware video decoding does not work.")
                }
            }
        }
        .navigationTitle("Ingests")
    }
}
