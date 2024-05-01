import SwiftUI

private let segmentHeight = 40.0
private let zoomSegmentWidth = 50.0
private let sceneSegmentWidth = 70.0
private let cameraButtonWidth = 70.0
private let pickerBorderColor = Color.gray
private var pickerBackgroundColor = Color.black.opacity(0.6)

private struct CameraSettingButtonView: View {
    var title: String
    var value: String
    var locked: Bool
    var on: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text(title)
                .font(.subheadline)
            HStack(spacing: 0) {
                Text(value)
                if locked {
                    Image(systemName: "lock")
                }
            }
            .font(.footnote)
        }
        .frame(width: cameraButtonWidth, height: segmentHeight)
        .background(pickerBackgroundColor)
        .foregroundColor(.white)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(on ? .white : pickerBorderColor)
        )
    }
}

private struct SegmentedPicker<T: Equatable, Content: View>: View {
    @Namespace private var selectionAnimation
    @Binding var selectedItem: T?
    private let items: [T]
    private let content: (T) -> Content

    init(_ items: [T],
         selectedItem: Binding<T?>,
         @ViewBuilder content: @escaping (T) -> Content)
    {
        _selectedItem = selectedItem
        self.items = items
        self.content = content
    }

    @ViewBuilder func overlay(for item: T) -> some View {
        if item == selectedItem {
            RoundedRectangle(cornerRadius: 6)
                .fill(.gray.opacity(0.6))
                .padding(2)
                .matchedGeometryEffect(id: "selectedSegmentHighlight", in: selectionAnimation)
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(self.items.indices, id: \.self) { index in
                ZStack {
                    Rectangle()
                        .overlay(self.overlay(for: self.items[index]))
                        .foregroundColor(.black.opacity(0.1))
                    Button(action: {
                        withAnimation(.linear.speed(1.5)) {
                            self.selectedItem = self.items[index]
                        }
                    }, label: {
                        self.content(self.items[index])
                            .contentShape(Rectangle())
                    })
                    .buttonStyle(.plain)
                }
                Divider()
                    .background(pickerBorderColor)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CameraSettingsControlView: View {
    @EnvironmentObject var model: Model

    private func formatIso() -> String {
        guard let device = model.cameraDevice else {
            return ""
        }
        return String(Int(calcIso(device: device, factor: model.manualExposure)))
    }

    private func formatExposureBias() -> String {
        var value = formatOneDecimal(value: model.bias)
        if model.bias >= 0 {
            value = "+\(value)"
        }
        return value
    }

    private func formatFocus() -> String {
        return String(Int(model.manualFocus * 100))
    }

    private func lockImage(locked: Bool) -> String {
        if locked {
            return "lock"
        } else {
            return "lock.open"
        }
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.showingCameraBias {
                Slider(
                    value: $model.bias,
                    in: -2 ... 2,
                    step: 0.1,
                    onEditingChanged: { begin in
                        guard !begin else {
                            return
                        }
                        model.setExposureBias(bias: model.bias)
                    }
                )
                .onChange(of: model.bias) { _ in
                    model.setExposureBias(bias: model.bias)
                }
                .padding([.top, .bottom], 5)
                .padding([.leading, .trailing], 7)
                .frame(width: 200)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(7)
                .padding([.bottom], 5)
            }
            if model.showingCameraExposure {
                let supported = model.isCameraSupportingManualExposure()
                HStack {
                    Slider(
                        value: $model.manualExposure,
                        in: 0 ... 1,
                        step: 0.01,
                        onEditingChanged: { begin in
                            model.editingManualExposure = begin
                            guard !begin else {
                                return
                            }
                            model.setManualExposure(exposure: model.manualExposure)
                        }
                    )
                    .onChange(of: model.manualExposure) { _ in
                        if model.editingManualExposure {
                            model.setManualExposure(exposure: model.manualExposure)
                        }
                    }
                    let enabled = model.getIsManualExposureEnabled()
                    Button {
                        if enabled {
                            model.setAutoExposure()
                        } else {
                            model.setManualExposure(exposure: model.manualExposure)
                        }
                    } label: {
                        Image(systemName: lockImage(locked: enabled))
                            .font(.title2)
                            .foregroundColor(supported ? .white : .gray)
                    }
                }
                .padding([.top, .bottom], 5)
                .padding([.leading, .trailing], 7)
                .frame(width: 200)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(7)
                .padding([.bottom], 5)
                .disabled(!supported)
            }
            if model.showingCameraFocus {
                let supported = model.isCameraSupportingManualFocus()
                HStack {
                    Slider(
                        value: $model.manualFocus,
                        in: 0 ... 1,
                        step: 0.01,
                        onEditingChanged: { begin in
                            model.editingManualFocus = begin
                            guard !begin else {
                                return
                            }
                            model.setManualFocus(lensPosition: model.manualFocus)
                        }
                    )
                    .onChange(of: model.manualFocus) { _ in
                        if model.editingManualFocus {
                            model.setManualFocus(lensPosition: model.manualFocus)
                        }
                    }
                    let enabled = model.getIsManualFocusEnabled()
                    Button {
                        if enabled {
                            model.setAutoFocus()
                        } else {
                            model.setManualFocus(lensPosition: model.manualFocus)
                        }
                    } label: {
                        Image(systemName: lockImage(locked: enabled))
                            .font(.title2)
                            .foregroundColor(supported ? .white : .gray)
                    }
                }
                .padding([.top, .bottom], 5)
                .padding([.leading, .trailing], 7)
                .frame(width: 200)
                .background(Color(white: 0, opacity: 0.6))
                .cornerRadius(7)
                .padding([.bottom], 5)
                .disabled(!supported)
            }
            HStack {
                Button {
                    model.showingCameraBias.toggle()
                    if model.showingCameraBias {
                        model.showingCameraExposure = false
                        model.showingCameraFocus = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: "EXB",
                        value: formatExposureBias(),
                        locked: true,
                        on: model.showingCameraBias
                    )
                }
                Button {
                    model.showingCameraExposure.toggle()
                    if model.showingCameraExposure {
                        model.showingCameraBias = false
                        model.showingCameraFocus = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: "ISO",
                        value: formatIso(),
                        locked: model.getIsManualExposureEnabled(),
                        on: model.showingCameraExposure
                    )
                }
                Button {
                    model.showingCameraFocus.toggle()
                    if model.showingCameraFocus {
                        model.showingCameraBias = false
                        model.showingCameraExposure = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: "FOC",
                        value: formatFocus(),
                        locked: model.getIsManualFocusEnabled(),
                        on: model.showingCameraFocus
                    )
                }
            }
            .onAppear {
                model.startObservingFocus()
                model.startObservingExposure()
            }
            .onDisappear {
                model.stopObservingFocus()
                model.stopObservingExposure()
            }
            .padding([.bottom], 5)
        }
    }
}

private struct ZoomPresetSelctorView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.cameraPosition == .front {
                SegmentedPicker(model.frontZoomPresets(), selectedItem: Binding(get: {
                    model.frontZoomPresets().first { $0.id == model.frontZoomPresetId }
                }, set: { value in
                    if let value {
                        model.frontZoomPresetId = value.id
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(width: zoomSegmentWidth, height: segmentHeight)
                }
                .onChange(of: model.frontZoomPresetId) { id in
                    model.setCameraZoomPreset(id: id)
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: zoomSegmentWidth * Double(model.frontZoomPresets().count))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .padding([.bottom], 5)
            } else {
                SegmentedPicker(model.backZoomPresets(), selectedItem: Binding(get: {
                    model.backZoomPresets().first { $0.id == model.backZoomPresetId }
                }, set: { value in
                    if let value {
                        model.backZoomPresetId = value.id
                    }
                })) {
                    Text($0.name)
                        .font(.subheadline)
                        .frame(width: zoomSegmentWidth, height: segmentHeight)
                }
                .onChange(of: model.backZoomPresetId) { id in
                    model.setCameraZoomPreset(id: id)
                }
                .background(pickerBackgroundColor)
                .foregroundColor(.white)
                .frame(width: zoomSegmentWidth * Double(model.backZoomPresets().count))
                .cornerRadius(7)
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(pickerBorderColor)
                )
                .padding([.bottom], 5)
            }
        }
    }
}

private struct SceneSelectorView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        SegmentedPicker(model.enabledScenes, selectedItem: Binding(get: {
            if model.sceneIndex < model.enabledScenes.count {
                model.enabledScenes[model.sceneIndex]
            } else {
                nil
            }
        }, set: { value in
            if let value, let index = model.enabledScenes.firstIndex(of: value) {
                model.sceneIndex = index
            } else {
                model.sceneIndex = 0
            }
        })) {
            Text($0.name)
                .font(.subheadline)
                .frame(width: sceneSegmentWidth, height: segmentHeight)
        }
        .onChange(of: model.sceneIndex) { tag in
            model.setSceneId(id: model.enabledScenes[tag].id)
            model.sceneUpdated(store: false)
        }
        .background(pickerBackgroundColor)
        .foregroundColor(.white)
        .frame(width: sceneSegmentWidth * Double(model.enabledScenes.count))
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(pickerBorderColor)
        )
    }
}

struct RightOverlayView: View {
    @EnvironmentObject var model: Model

    private var database: Database {
        model.settings.database
    }

    private func netStreamColor() -> Color {
        if model.isStreaming() {
            switch model.streamState {
            case .connecting:
                return .white
            case .connected:
                return .white
            case .disconnected:
                return .red
            }
        } else {
            return .white
        }
    }

    private func remoteControlColor() -> Color {
        if model.isRemoteControlStreamerConfigured() && !model.isRemoteControlStreamerConnected() {
            return .red
        } else if model.isRemoteControlAssistantConfigured() && !model.isRemoteControlAssistantConnected() {
            return .red
        }
        return .white
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.isShowingStatusAudioLevel() {
                AudioLevelView(
                    showBar: database.show.audioBar,
                    level: model.audioLevel,
                    channels: model.numberOfAudioChannels
                )
            }
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRtmpServer(),
                icon: "server.rack",
                text: model.rtmpSpeedAndTotal,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRemoteControl(),
                icon: "appletvremote.gen1",
                text: model.remoteControlStatus,
                textFirst: true,
                color: remoteControlColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusGameController(),
                icon: "gamecontroller",
                text: model.gameControllersTotal,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBitrate(),
                icon: "speedometer",
                text: model.speedAndTotal,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusUptime(),
                icon: "deskclock",
                text: model.uptime,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusLocation(),
                icon: "location",
                text: model.location,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusSrtla(),
                icon: "phone.connection",
                text: model.srtlaConnectionStatistics,
                textFirst: true,
                color: netStreamColor()
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusRecording(),
                icon: "record.circle",
                text: model.recordingLength,
                textFirst: true,
                color: .white
            )
            StreamOverlayIconAndTextView(
                show: model.isShowingStatusBrowserWidgets(),
                icon: "globe",
                text: model.browserWidgetsStatus,
                textFirst: true,
                color: .white
            )
            Spacer()
            if !model.showDrawOnStream {
                if model.showingCamera {
                    CameraSettingsControlView()
                }
                if database.show.zoomPresets && model.hasZoom {
                    ZoomPresetSelctorView()
                }
                SceneSelectorView()
            }
        }
    }
}
