import SwiftUI

struct FixedHorizonView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Toggle("Fixed horizon", isOn: $database.fixedHorizon)
            .onChange(of: database.fixedHorizon) { _ in
                model.sceneUpdated()
            }
    }
}
