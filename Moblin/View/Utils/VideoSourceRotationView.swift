import SwiftUI

struct VideoSourceRotationView: View {
    @Binding var selectedRotation: Double

    var body: some View {
        Picker("Rotation", selection: $selectedRotation) {
            ForEach([0.0, 90.0, 180.0, 270.0], id: \.self) { rotation in
                Text("\(Int(rotation))°")
                    .tag(rotation)
            }
        }
    }
}
