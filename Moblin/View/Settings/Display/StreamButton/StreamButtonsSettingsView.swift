import SwiftUI

struct StreamButtonsSettingsView: View {
    @ObservedObject var database: Database

    var body: some View {
        Form {
            Section {
                ColorPicker("Background", selection: $database.streamButtonColorColor, supportsOpacity: false)
                    .onChange(of: database.streamButtonColorColor) { _ in
                        guard let color = database.streamButtonColorColor.toRgb() else {
                            return
                        }
                        database.streamButtonColor = color
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
