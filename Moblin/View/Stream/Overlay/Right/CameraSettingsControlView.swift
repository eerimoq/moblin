import SwiftUI

private func lockImage(locked: Bool) -> String {
    if locked {
        return "lock"
    } else {
        return "lock.open"
    }
}

private struct CameraSettingButtonView: View {
    var title: String
    var value: String
    var locked: Bool
    var on: Bool
    var height: Double

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
            .padding([.trailing], 7)
        }
        .frame(width: cameraButtonWidth, height: height)
        .background(pickerBackgroundColor)
        .foregroundColor(.white)
        .cornerRadius(7)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(on ? .white : pickerBorderColor)
        )
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

private struct ExposureBiasView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        Text("EXPOSURE BIAS")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
        Slider(
            value: $camera.bias,
            in: -2 ... 2,
            step: 0.1,
            onEditingChanged: { begin in
                guard !begin else {
                    return
                }
                model.setExposureBias(bias: camera.bias)
                model.updateImageButtonState()
            }
        )
        .onChange(of: camera.bias) { _ in
            model.setExposureBias(bias: camera.bias)
            model.updateImageButtonState()
        }
        .padding([.top, .bottom], 5)
        .padding([.leading, .trailing], 7)
        .frame(width: sliderWidth, height: sliderHeight)
        .background(backgroundColor)
        .cornerRadius(7)
        .padding([.bottom], 5)
    }
}

private struct WhiteBalanceView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        Text("WHITE BALANCE")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualWhiteBalance() {
            HStack {
                Slider(
                    value: $camera.manualWhiteBalance,
                    in: 0 ... 1,
                    step: 0.01,
                    onEditingChanged: { begin in
                        model.editingManualWhiteBalance = begin
                        guard !begin else {
                            return
                        }
                        model.setManualWhiteBalance(factor: camera.manualWhiteBalance)
                    }
                )
                .onChange(of: camera.manualWhiteBalance) { _ in
                    if model.editingManualWhiteBalance {
                        model.setManualWhiteBalance(factor: camera.manualWhiteBalance)
                    }
                }
                Button {
                    if camera.manualWhiteBalanceEnabled {
                        model.setAutoWhiteBalance()
                    } else {
                        model.setManualWhiteBalance(factor: camera.manualWhiteBalance)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.manualWhiteBalanceEnabled))
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
}

private struct IsoView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        Text("ISO")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualIso() {
            HStack {
                Slider(
                    value: $camera.manualIso,
                    in: 0 ... 1,
                    step: 0.01,
                    onEditingChanged: { begin in
                        model.editingManualIso = begin
                        guard !begin else {
                            return
                        }
                        model.setManualIso(factor: camera.manualIso)
                    }
                )
                .onChange(of: camera.manualIso) { _ in
                    if model.editingManualIso {
                        model.setManualIso(factor: camera.manualIso)
                    }
                }
                Button {
                    if camera.manualIsoEnabled {
                        model.setAutoIso()
                    } else {
                        model.setManualIso(factor: camera.manualIso)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.manualIsoEnabled))
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
}

struct FocusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        Text("FOCUS")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualFocus() {
            HStack {
                Slider(
                    value: $camera.manualFocus,
                    in: 0 ... 1,
                    step: 0.01,
                    onEditingChanged: { begin in
                        model.editingManualFocus = begin
                        guard !begin else {
                            return
                        }
                        model.setManualFocus(lensPosition: camera.manualFocus)
                    }
                )
                .onChange(of: camera.manualFocus) { _ in
                    if model.editingManualFocus {
                        model.setManualFocus(lensPosition: camera.manualFocus)
                    }
                }
                Button {
                    if camera.manualFocusEnabled {
                        model.setAutoFocus()
                    } else {
                        model.setManualFocus(lensPosition: camera.manualFocus)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.manualFocusEnabled))
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
}

private struct ButtonsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var database: Database
    @ObservedObject var camera: CameraState

    private func formatExposureBias() -> String {
        var value = formatOneDecimal(camera.bias)
        if camera.bias >= 0 {
            value = "+\(value)"
        }
        return value
    }

    private func formatWhiteBalance() -> String {
        return String(Int(minimumWhiteBalanceTemperature +
                (maximumWhiteBalanceTemperature - minimumWhiteBalanceTemperature) * camera.manualWhiteBalance))
    }

    private func formatIso() -> String {
        guard let device = model.cameraDevice else {
            return ""
        }
        return String(Int(factorToIso(device: device, factor: camera.manualIso)))
    }

    private func formatFocus() -> String {
        return String(Int(camera.manualFocus * 100))
    }

    private func height() -> Double {
        if database.bigButtons {
            return segmentHeightBig
        } else {
            return segmentHeight
        }
    }

    var body: some View {
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
                    on: model.showingCameraBias,
                    height: height()
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
                    locked: camera.manualWhiteBalanceEnabled,
                    on: model.showingCameraWhiteBalance,
                    height: height()
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
                    locked: camera.manualIsoEnabled,
                    on: model.showingCameraIso,
                    height: height()
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
                    locked: camera.manualFocusEnabled,
                    on: model.showingCameraFocus,
                    height: height()
                )
            }
        }
    }
}

struct StreamOverlayRightCameraSettingsControlView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.showingCameraBias {
                ExposureBiasView(camera: model.camera)
            }
            if model.showingCameraWhiteBalance {
                WhiteBalanceView(camera: model.camera)
            }
            if model.showingCameraIso {
                IsoView(camera: model.camera)
            }
            if model.showingCameraFocus {
                FocusView(camera: model.camera)
            }
            ButtonsView(database: model.database, camera: model.camera)
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
