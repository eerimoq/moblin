import SwiftUI

private let sliderWidth = 250.0

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

    var body: some View {
        Text("EXPOSURE BIAS")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
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
}

private struct WhiteBalanceView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Text("WHITE BALANCE")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
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
}

private struct IsoView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Text("ISO")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
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
}

struct FocusView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Text("FOCUS")
            .font(.footnote)
            .foregroundColor(.white)
            .padding([.trailing], 7)
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
}

private struct ButtonsView: View {
    @EnvironmentObject var model: Model

    private func formatExposureBias() -> String {
        var value = formatOneDecimal(model.bias)
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
    }
}

struct StreamOverlayRightCameraSettingsControlView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if model.showingCameraBias {
                ExposureBiasView()
            }
            if model.showingCameraWhiteBalance {
                WhiteBalanceView()
            }
            if model.showingCameraIso {
                IsoView()
            }
            if model.showingCameraFocus {
                FocusView()
            }
            ButtonsView()
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
