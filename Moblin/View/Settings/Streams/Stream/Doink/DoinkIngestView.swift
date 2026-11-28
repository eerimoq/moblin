import SwiftUI

struct DoinkIngestView: View {
    let ingest: DoinkApiIngest
    @Binding var url: String
    @State private var pings: [String: Int] = [:]

    private func label(region: DoinkApiRegion) -> String {
        if let ping = pings[region.region] {
            "\(region.label) · \(ping) ms"
        } else {
            region.label
        }
    }

    var body: some View {
        Picker("Region", selection: $url) {
            ForEach(ingest.regions, id: \.region) {
                Text(label(region: $0))
                    .tag($0.srtlaUrl)
            }
        }
        .onAppear {
            for region in ingest.regions {
                if let pingUrl = region.pingUrl, let pingUrl = URL(string: pingUrl) {
                    doinkPing(url: pingUrl) {
                        pings[region.region] = $0
                    }
                }
            }
        }
    }
}
