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
                Button {
                    database.streamButtonColor = defaultStreamButtonColor
                    database.streamButtonColorColor = database.streamButtonColor.color()
                } label: {
                    HCenter {
                        Text("Reset")
                    }
                }
            } header: {
                Text("Color")
            }
        }
        .navigationTitle("Stream button")
    }
}
