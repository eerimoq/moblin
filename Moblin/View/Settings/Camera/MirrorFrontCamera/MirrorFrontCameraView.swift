import SwiftUI

struct MirrorFrontCameraOnStreamView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Toggle("Mirror front camera on stream", isOn: Binding(get: {
            model.database.mirrorFrontCameraOnStream!
        }, set: { value in
            model.database.mirrorFrontCameraOnStream = value
            model.store()
            model.reattachCamera()
        }))
    }
}
