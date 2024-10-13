import SwiftUI

struct WidgetVideoSourceSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var cornerRadius: Float

    private func onCameraChange(cameraId: String) {
        if isSrtlaCamera(camera: cameraId) {
            widget.videoSource!.cameraPosition = .srtla
            widget.videoSource!.srtlaCameraId = model.getSrtlaStream(camera: cameraId)?.id ?? .init()
        } else if isRtmpCamera(camera: cameraId) {
            widget.videoSource!.cameraPosition = .rtmp
            widget.videoSource!.rtmpCameraId = model.getRtmpStream(camera: cameraId)?.id ?? .init()
        } else if isMediaPlayerCamera(camera: cameraId) {
            widget.videoSource!.cameraPosition = .mediaPlayer
            widget.videoSource!.mediaPlayerCameraId = model.getMediaPlayer(camera: cameraId)?.id ?? .init()
        } else if model.isBackCamera(cameraId: cameraId) {
            widget.videoSource!.cameraPosition = .back
            widget.videoSource!.backCameraId = cameraId
        } else if model.isFrontCamera(cameraId: cameraId) {
            widget.videoSource!.cameraPosition = .front
            widget.videoSource!.frontCameraId = cameraId
        } else if model.isScreenCaptureCamera(cameraId: cameraId) {
            widget.videoSource!.cameraPosition = .screenCapture
        } else {
            widget.videoSource!.cameraPosition = .external
            widget.videoSource!.externalCameraId = cameraId
            widget.videoSource!.externalCameraName = model.getExternalCameraName(cameraId: cameraId)
        }
        model.sceneUpdated()
    }

    var body: some View {
        Section {
            Text("Will use the scene's video source. The plan is to select any video source here later on.")
            if false {
                NavigationLink {
                    InlinePickerView(
                        title: String(localized: "Video source"),
                        onChange: onCameraChange,
                        items: model.listCameraPositions(excludeBuiltin: true).map { id, name in
                            InlinePickerItem(id: id, text: name)
                        },
                        selectedId: model.getCameraPositionId(videoSourceWidget: widget.videoSource)
                    )
                } label: {
                    HStack {
                        Text(String(localized: "Video source"))
                        Spacer()
                        Text(model.getCameraPositionName(videoSourceWidget: widget.videoSource))
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                }
            }
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
