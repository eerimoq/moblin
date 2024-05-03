import SwiftUI

private let segmentHeight = 40.0
private let zoomSegmentWidth = 50.0
private let sceneSegmentWidth = 70.0
private let cameraButtonWidth = 70.0
private let sliderWidth = 250.0
private let sliderHeight = 40.0
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

private struct NotSupportedForThisCameraView: View {
    var body: some View {
        Text("Not supported for this camera")
            .foregroundColor(.white)
            .padding([.top, .bottom], 5)
            .padding([.leading, .trailing], 7)
            .frame(height: sliderHeight)
            .background(backgroundColor)
            .cornerRadius(7)
            .padding([.bottom], 5)
    }
}

private struct CameraSettingsControlView: View {
    @EnvironmentObject var model: Model

    private func formatExposureBias() -> String {
        var value = formatOneDecimal(value: model.bias)
        if model.bias >= 0 {
            value = "+\(value)"
        }
        return value
    }

    private func formatWhiteBalance() -> String {
        return String(Int(minimumWhiteBalanceTemperature +
                (maximumWhiteBalanceTemperature - minimumWhiteBalanceTemperature) * model.manualWhiteBalance))
    }

    private func formatIso() -> String {
        guard let device = model.cameraDevice else {
            return ""
        }
        return String(Int(factorToIso(device: device, factor: model.manualIso)))
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
                Text("EXPOSURE BIAS")
                    .font(.footnote)
                    .foregroundColor(.white)
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
                .frame(width: sliderWidth, height: sliderHeight)
                .background(backgroundColor)
                .cornerRadius(7)
                .padding([.bottom], 5)
            }
            if model.showingCameraWhiteBalance {
                Text("WHITE BALANCE")
                    .font(.footnote)
                    .foregroundColor(.white)
                if model.isCameraSupportingManualWhiteBalance() {
                    HStack {
                        Slider(
                            value: $model.manualWhiteBalance,
                            in: 0 ... 1,
                            step: 0.01,
                            onEditingChanged: { begin in
                                model.editingManualWhiteBalance = begin
                                guard !begin else {
                                    return
                                }
                                model.setManualWhiteBalance(factor: model.manualWhiteBalance)
                            }
                        )
                        .onChange(of: model.manualWhiteBalance) { _ in
                            if model.editingManualWhiteBalance {
                                model.setManualWhiteBalance(factor: model.manualWhiteBalance)
                            }
                        }
                        Button {
                            if model.manualWhiteBalanceEnabled {
                                model.setAutoWhiteBalance()
                            } else {
                                model.setManualWhiteBalance(factor: model.manualWhiteBalance)
                            }
                        } label: {
                            Image(systemName: lockImage(locked: model.manualWhiteBalanceEnabled))
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding([.top, .bottom], 5)
                    .padding([.leading, .trailing], 7)
                    .frame(width: sliderWidth, height: sliderHeight)
                    .background(backgroundColor)
                    .cornerRadius(7)
                    .padding([.bottom], 5)
                } else {
                    NotSupportedForThisCameraView()
                }
            }
            if model.showingCameraIso {
                Text("ISO")
                    .font(.footnote)
                    .foregroundColor(.white)
                if model.isCameraSupportingManualIso() {
                    HStack {
                        Slider(
                            value: $model.manualIso,
                            in: 0 ... 1,
                            step: 0.01,
                            onEditingChanged: { begin in
                                model.editingManualIso = begin
                                guard !begin else {
                                    return
                                }
                                model.setManualIso(factor: model.manualIso)
                            }
                        )
                        .onChange(of: model.manualIso) { _ in
                            if model.editingManualIso {
                                model.setManualIso(factor: model.manualIso)
                            }
                        }
                        Button {
                            if model.manualIsoEnabled {
                                model.setAutoIso()
                            } else {
                                model.setManualIso(factor: model.manualIso)
                            }
                        } label: {
                            Image(systemName: lockImage(locked: model.manualIsoEnabled))
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding([.top, .bottom], 5)
                    .padding([.leading, .trailing], 7)
                    .frame(width: sliderWidth, height: sliderHeight)
                    .background(backgroundColor)
                    .cornerRadius(7)
                    .padding([.bottom], 5)
                } else {
                    NotSupportedForThisCameraView()
                }
            }
            if model.showingCameraFocus {
                Text("FOCUS")
                    .font(.footnote)
                    .foregroundColor(.white)
                if model.isCameraSupportingManualFocus() {
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
                        Button {
                            if model.manualFocusEnabled {
                                model.setAutoFocus()
                            } else {
                                model.setManualFocus(lensPosition: model.manualFocus)
                            }
                        } label: {
                            Image(systemName: lockImage(locked: model.manualFocusEnabled))
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .padding([.top, .bottom], 5)
                    .padding([.leading, .trailing], 7)
                    .frame(width: sliderWidth, height: sliderHeight)
                    .background(backgroundColor)
                    .cornerRadius(7)
                    .padding([.bottom], 5)
                } else {
                    NotSupportedForThisCameraView()
                }
            }
            HStack {
                Button {
                    model.showingCameraBias.toggle()
                    if model.showingCameraBias {
                        model.showingCameraWhiteBalance = false
                        model.showingCameraIso = false
                        model.showingCameraFocus = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: String(localized: "EXB"),
                        value: formatExposureBias(),
                        locked: true,
                        on: model.showingCameraBias
                    )
                }
                Button {
                    model.showingCameraWhiteBalance.toggle()
                    if model.showingCameraWhiteBalance {
                        model.showingCameraBias = false
                        model.showingCameraIso = false
                        model.showingCameraFocus = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: String(localized: "WB"),
                        value: formatWhiteBalance(),
                        locked: model.manualWhiteBalanceEnabled,
                        on: model.showingCameraWhiteBalance
                    )
                }
                Button {
                    model.showingCameraIso.toggle()
                    if model.showingCameraIso {
                        model.showingCameraBias = false
                        model.showingCameraWhiteBalance = false
                        model.showingCameraFocus = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: String(localized: "ISO"),
                        value: formatIso(),
                        locked: model.manualIsoEnabled,
                        on: model.showingCameraIso
                    )
                }
                Button {
                    model.showingCameraFocus.toggle()
                    if model.showingCameraFocus {
                        model.showingCameraBias = false
                        model.showingCameraWhiteBalance = false
                        model.showingCameraIso = false
                    }
                } label: {
                    CameraSettingButtonView(
                        title: String(localized: "FOC"),
                        value: formatFocus(),
                        locked: model.manualFocusEnabled,
                        on: model.showingCameraFocus
                    )
                }
            }
            .onAppear {
                model.startObservingFocus()
                model.startObservingIso()
                model.startObservingWhiteBalance()
            }
            .onDisappear {
                model.stopObservingFocus()
                model.stopObservingIso()
                model.stopObservingWhiteBalance()
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
            if !(model.showDrawOnStream || model.showFace) {
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
