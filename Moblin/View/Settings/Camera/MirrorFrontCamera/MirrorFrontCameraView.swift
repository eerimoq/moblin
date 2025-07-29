import SwiftUI

struct MirrorFrontCameraOnStreamView: View {
    let model: Model
    @ObservedObject var database: Database

    var body: some View {
        Toggle("Mirror front camera on stream", isOn: $database.mirrorFrontCameraOnStream)
            .onChange(of: database.mirrorFrontCameraOnStream) { _ in
                model.reattachCamera()
            }
    }
}
