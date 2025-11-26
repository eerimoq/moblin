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
        .frame(maxWidth: cameraButtonWidth, maxHeight: height)
        .background(pickerBackgroundColor)
        .foregroundStyle(.white)
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
            .foregroundStyle(.white)
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
            .foregroundStyle(.white)
            .padding([.trailing], 7)
        Slider(
            value: $camera.bias,
            in: -2 ... 2,
            step: 0.1,
            label: { EmptyView() },
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
            .foregroundStyle(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualWhiteBalance() {
            HStack {
                Slider(
                    value: $camera.lockedWhiteBalance,
                    in: 0 ... 1,
                    step: 0.01,
                    label: { EmptyView() },
                    onEditingChanged: { begin in
                        model.camera.editingLockedWhiteBalance = begin
                        guard !begin else {
                            return
                        }
                        model.setManualWhiteBalance(factor: camera.lockedWhiteBalance)
                    }
                )
                .onChange(of: camera.lockedWhiteBalance) { _ in
                    if model.camera.editingLockedWhiteBalance {
                        model.setManualWhiteBalance(factor: camera.lockedWhiteBalance)
                    }
                }
                Button {
                    if camera.isWhiteBalanceLocked {
                        model.setAutoWhiteBalance()
                    } else {
                        model.setManualWhiteBalance(factor: camera.lockedWhiteBalance)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.isWhiteBalanceLocked))
                        .font(.title2)
                        .foregroundStyle(.white)
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
            .foregroundStyle(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualExposureAndIso() {
            HStack {
                Slider(
                    value: $camera.lockedIso,
                    in: 0 ... 1,
                    step: 0.01,
                    label: { EmptyView() },
                    onEditingChanged: { begin in
                        camera.editingLockedIso = begin
                        guard !begin else {
                            return
                        }
                        model.setManualIso(factor: camera.lockedIso)
                    }
                )
                .onChange(of: camera.lockedIso) { _ in
                    if camera.editingLockedIso {
                        model.setManualIso(factor: camera.lockedIso)
                    }
                }
                Button {
                    if camera.isExposureAndIsoLocked {
                        model.setAutoExposureAndIso()
                    } else {
                        model.setManualIso(factor: camera.lockedIso)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.isExposureAndIsoLocked))
                        .font(.title2)
                        .foregroundStyle(.white)
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

private struct ExposureView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        Text("EXPOSURE")
            .font(.footnote)
            .foregroundStyle(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualExposureAndIso() {
            HStack {
                Slider(
                    value: $camera.lockedExposure,
                    in: 0 ... 1,
                    step: 0.01,
                    label: { EmptyView() },
                    onEditingChanged: { begin in
                        camera.editingLockedExposure = begin
                        guard !begin else {
                            return
                        }
                        model.setManualExposure(factor: camera.lockedExposure)
                    }
                )
                .onChange(of: camera.lockedExposure) { _ in
                    if camera.editingLockedExposure {
                        model.setManualExposure(factor: camera.lockedExposure)
                    }
                }
                Button {
                    if camera.isExposureAndIsoLocked {
                        model.setAutoExposureAndIso()
                    } else {
                        model.setManualExposure(factor: camera.lockedExposure)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.isExposureAndIsoLocked))
                        .font(.title2)
                        .foregroundStyle(.white)
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
            .foregroundStyle(.white)
            .padding([.trailing], 7)
        if model.isCameraSupportingManualFocus() {
            HStack {
                Slider(
                    value: $camera.lockedFocus,
                    in: 0 ... 1,
                    step: 0.01,
                    label: { EmptyView() },
                    onEditingChanged: { begin in
                        camera.editingLockedFocus = begin
                        guard !begin else {
                            return
                        }
                        model.setManualFocus(lensPosition: camera.lockedFocus)
                    }
                )
                .onChange(of: camera.lockedFocus) { _ in
                    if camera.editingLockedFocus {
                        model.setManualFocus(lensPosition: camera.lockedFocus)
                    }
                }
                Button {
                    if camera.isFocusLocked {
                        model.setAutoFocus()
                    } else {
                        model.setManualFocus(lensPosition: camera.lockedFocus)
                    }
                    model.updateImageButtonState()
                } label: {
                    Image(systemName: lockImage(locked: camera.isFocusLocked))
                        .font(.title2)
                        .foregroundStyle(.white)
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
    @ObservedObject var show: Show

    private func formatExposureBias() -> String {
        var value = formatOneDecimal(camera.bias)
        if camera.bias >= 0 {
            value = "+\(value)"
        }
        return value
    }

    private func formatWhiteBalance() -> String {
        return String(Int(minimumWhiteBalanceTemperature +
                (maximumWhiteBalanceTemperature - minimumWhiteBalanceTemperature) * camera.lockedWhiteBalance))
    }

    private func formatIso() -> String {
        guard let device = model.cameraDevice else {
            return ""
        }
        return String(Int(factorToIso(device: device, factor: camera.lockedIso)))
    }

    private func formatExposure() -> String {
        guard let device = model.cameraDevice else {
            return ""
        }
        return String(Int(factorToExposure(device: device, factor: camera.lockedExposure).seconds * 1000))
    }

    private func formatFocus() -> String {
        return String(Int(camera.lockedFocus * 100))
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
                show.cameraBias.toggle()
                if show.cameraBias {
                    show.cameraWhiteBalance = false
                    show.cameraIso = false
                    show.cameraExposure = false
                    show.cameraFocus = false
                }
            } label: {
                CameraSettingButtonView(
                    title: String(localized: "EXB"),
                    value: formatExposureBias(),
                    locked: true,
                    on: show.cameraBias,
                    height: height()
                )
            }
            Button {
                show.cameraWhiteBalance.toggle()
                if show.cameraWhiteBalance {
                    show.cameraBias = false
                    show.cameraIso = false
                    show.cameraExposure = false
                    show.cameraFocus = false
                }
            } label: {
                CameraSettingButtonView(
                    title: String(localized: "WB"),
                    value: formatWhiteBalance(),
                    locked: camera.isWhiteBalanceLocked,
                    on: show.cameraWhiteBalance,
                    height: height()
                )
            }
            Button {
                show.cameraIso.toggle()
                if show.cameraIso {
                    show.cameraBias = false
                    show.cameraExposure = false
                    show.cameraWhiteBalance = false
                    show.cameraFocus = false
                }
            } label: {
                CameraSettingButtonView(
                    title: String(localized: "ISO"),
                    value: formatIso(),
                    locked: camera.isExposureAndIsoLocked,
                    on: show.cameraIso,
                    height: height()
                )
            }
            Button {
                show.cameraExposure.toggle()
                if show.cameraExposure {
                    show.cameraBias = false
                    show.cameraIso = false
                    show.cameraWhiteBalance = false
                    show.cameraFocus = false
                }
            } label: {
                CameraSettingButtonView(
                    title: String(localized: "EXP"),
                    value: formatExposure(),
                    locked: camera.isExposureAndIsoLocked,
                    on: show.cameraExposure,
                    height: height()
                )
            }
            Button {
                show.cameraFocus.toggle()
                if show.cameraFocus {
                    show.cameraBias = false
                    show.cameraWhiteBalance = false
                    show.cameraIso = false
                    show.cameraExposure = false
                }
            } label: {
                CameraSettingButtonView(
                    title: String(localized: "FOC"),
                    value: formatFocus(),
                    locked: camera.isFocusLocked,
                    on: show.cameraFocus,
                    height: height()
                )
            }
        }
    }
}

struct StreamOverlayRightCameraSettingsControlView: View {
    let model: Model
    @ObservedObject var show: Show

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            if show.cameraBias {
                ExposureBiasView(camera: model.camera)
            }
            if show.cameraWhiteBalance {
                WhiteBalanceView(camera: model.camera)
            }
            if show.cameraIso {
                IsoView(camera: model.camera)
            }
            if show.cameraExposure {
                ExposureView(camera: model.camera)
            }
            if show.cameraFocus {
                FocusView(camera: model.camera)
            }
            ButtonsView(database: model.database, camera: model.camera, show: show)
                .onAppear {
                    model.startObservingFocus()
                    model.startObservingIso()
                    model.startObservingExposure()
                    model.startObservingWhiteBalance()
                }
                .onDisappear {
                    model.stopObservingFocus()
                    model.stopObservingIso()
                    model.stopObservingExposure()
                    model.stopObservingWhiteBalance()
                }
                .padding([.bottom], 5)
        }
    }
}
