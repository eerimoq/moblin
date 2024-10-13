import SwiftUI

struct WidgetVideoSourceSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var cornerRadius: Float

    var body: some View {
        Section {
            Text("Will use the scene's video source. The plan is to select any video source here later on.")
        }
        Section {
            HStack {
                Text("Corner radius")
                Slider(
                    value: $cornerRadius,
                    in: 0 ... 1,
                    step: 0.01
                )
                .onChange(of: cornerRadius) { _ in
                    widget.videoSource!.cornerRadius = cornerRadius
                    model.getVideoSourceEffect(id: widget.id)?.setRadius(radius: cornerRadius)
                }
            }
        }
    }
}
