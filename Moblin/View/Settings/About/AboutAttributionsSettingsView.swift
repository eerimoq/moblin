import SwiftUI

private struct Attribution {
    let name: String
    let text: String
}

private let soundAttributions: [Attribution] = [
    Attribution(
        name: "Notification",
        text: "Message Notification 4 by AnthonyRox -- https://freesound.org/s/740423/ -- License: Creative Commons 0"
    ),
]

struct AboutAttributionsSettingsView: View {
    var body: some View {
        ScrollView {
            HStack {
                LazyVStack(alignment: .leading) {
                    Text("Sounds")
                        .font(.title)
                    ForEach(soundAttributions, id: \.name) { attribution in
                        Text(attribution.name)
                            .font(.title2)
                            .padding([.top])
                        Text(attribution.text)
                            .padding([.top, .leading], 5)
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .navigationTitle("Attributions")
        .toolbar {
            SettingsToolbar()
        }
    }
}
