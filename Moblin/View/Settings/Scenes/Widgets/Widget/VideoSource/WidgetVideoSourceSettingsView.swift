import SwiftUI

struct WidgetVideoSourceSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var cornerRadius: Float

    private func onCameraChange(cameraId: String) {
        widget.videoSource?
            .updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated()
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: String(localized: "Video source"),
                    onChange: onCameraChange,
                    footers: [
                        String(localized: "Only RTMP, SRT(LA) and screen capture video sources are currently supported.")
                    ],
                    items: model.listCameraPositions(excludeBuiltin: true).map { id, name in
                        InlinePickerItem(id: id, text: name)
                    },
                    selectedId: model.getCameraPositionId(videoSourceWidget: widget.videoSource)
                )
            } label: {
                HStack {
                    Text("Video source")
                    Spacer()
                    Text(model.getCameraPositionName(videoSourceWidget: widget.videoSource))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
        }
        Section {
            Slider(
                value: $cornerRadius,
                in: 0 ... 1,
                step: 0.01
            )
            .onChange(of: cornerRadius) { _ in
                widget.videoSource!.cornerRadius = cornerRadius
                model.getVideoSourceEffect(id: widget.id)?.setRadius(radius: cornerRadius)
            }
        } header: {
            Text("Corner radius")
        }
    }
}
