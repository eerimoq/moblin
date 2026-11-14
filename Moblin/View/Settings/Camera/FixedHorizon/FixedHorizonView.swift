import SwiftUI

struct FixedHorizonView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Toggle("Fixed horizon", isOn: $database.fixedHorizon)
            .onChange(of: database.fixedHorizon) { _ in
                model.sceneUpdated()
            }
    }
}
