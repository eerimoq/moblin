import SwiftUI

struct DoinkIngestView: View {
    let ingest: DoinkApiIngest
    @Binding var url: String

    var body: some View {
        Picker("Region", selection: $url) {
            ForEach(ingest.regions, id: \.region) {
                Text($0.label)
                    .tag($0.srtlaUrl)
            }
        }
    }
}
