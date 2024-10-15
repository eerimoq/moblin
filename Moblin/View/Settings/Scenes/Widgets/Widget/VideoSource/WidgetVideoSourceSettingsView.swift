import SwiftUI

struct WidgetVideoSourceSettingsView: View {
    @EnvironmentObject var model: Model
    var widget: SettingsWidget
    @State var cornerRadius: Float

    private func onCameraChange(cameraId: String) {
        widget.videoSource!
            .updateCameraId(settingsCameraId: model.cameraIdToSettingsCameraId(cameraId: cameraId))
        model.sceneUpdated()
    }

    private func submitX(value: String) {
        guard let x = Int(value) else {
            return
        }
        guard x >= 0 && x <= 100 else {
            return
        }
        widget.videoSource!.cropX = x
        setEffectSettings()
    }

    private func submitY(value: String) {
        guard let y = Int(value) else {
            return
        }
        guard y >= 0 && y <= 100 else {
            return
        }
        widget.videoSource!.cropY = y
        setEffectSettings()
    }

    private func submitWidth(value: String) {
        guard let width = Int(value) else {
            return
        }
        guard width > 0 && width <= 100 else {
            return
        }
        widget.videoSource!.cropWidth = width
        setEffectSettings()
    }

    private func submitHeight(value: String) {
        guard let height = Int(value) else {
            return
        }
        guard height > 0 && height <= 100 else {
            return
        }
        widget.videoSource!.cropHeight = height
        setEffectSettings()
    }

    private func setEffectSettings() {
        model.getVideoSourceEffect(id: widget.id)?
            .setSettings(settings: widget.videoSource!.toEffectSettings())
    }

    var body: some View {
        Section {
            NavigationLink {
                InlinePickerView(
                    title: String(localized: "Video source"),
                    onChange: onCameraChange,
                    footers: [
                        String(
                            localized: "Only RTMP, SRT(LA) and screen capture video sources are currently supported."
                        ),
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
                setEffectSettings()
            }
        } header: {
            Text("Corner radius")
        }
        Section {
            Toggle(isOn: Binding(get: {
                widget.videoSource!.cropEnabled!
            }, set: { value in
                widget.videoSource!.cropEnabled = value
                setEffectSettings()
            })) {
                Text("Enabled")
            }
            TextEditNavigationView(
                title: String(localized: "X"),
                value: String(widget.videoSource!.cropX!),
                onSubmit: submitX,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(
                title: String(localized: "Y"),
                value: String(widget.videoSource!.cropY!),
                onSubmit: submitY,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(
                title: String(localized: "Width"),
                value: String(widget.videoSource!.cropWidth!),
                onSubmit: submitWidth,
                keyboardType: .numbersAndPunctuation
            )
            TextEditNavigationView(
                title: String(localized: "Height"),
                value: String(widget.videoSource!.cropHeight!),
                onSubmit: submitHeight,
                keyboardType: .numbersAndPunctuation
            )
        } header: {
            Text("Crop")
        }
    }
}
