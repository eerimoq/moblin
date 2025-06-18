import SwiftUI

struct CameraControlsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database

    var body: some View {
        Toggle("Camera controls", isOn: $database.cameraControlsEnabled)
            .onChange(of: database.cameraControlsEnabled) { _ in
                model.setCameraControlsEnabled()
            }
    }
}
