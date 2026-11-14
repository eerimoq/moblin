import SwiftUI

struct StreamButtonsSettingsView: View {
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                RgbColorPickerView(title: "Background", color: $database.streamButtonColorColor) {
                    database.streamButtonColor = $0
                }
                TextButtonView("Reset") {
                    database.streamButtonColor = defaultStreamButtonColor
                    database.streamButtonColorColor = database.streamButtonColor.color()
                }
            } header: {
                Text("Color")
            }
        }
        .navigationTitle("Stream button")
    }
}
