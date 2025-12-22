import SwiftUI

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

private struct TitleView: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.footnote)
            .foregroundStyle(.white)
            .padding([.trailing], 7)
    }
}

private struct SliderAndLockView: View {
    let model: Model
    @Binding var value: Float
    @Binding var locked: Bool
    @Binding var editingLocked: Bool
    let onEditingChanged: (Bool) -> Void
    let setManual: (Float) -> Void
    let setAuto: () -> Void

    var body: some View {
        HStack {
            Slider(
                value: $value,
                in: 0 ... 1,
                step: 0.01,
                label: { EmptyView() },
                onEditingChanged: onEditingChanged
            )
            .onChange(of: value) { _ in
                if editingLocked {
                    setManual(value)
                }
            }
            Button {
                if locked {
                    setAuto()
                } else {
                    setManual(value)
                }
                model.updateImageButtonState()
            } label: {
                Image(systemName: locked ? "lock" : "lock.open")
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
    }
}

private struct ExposureBiasView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        TitleView(title: "EXPOSURE BIAS")
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
        TitleView(title: "WHITE BALANCE")
        if model.isCameraSupportingManualWhiteBalance() {
            SliderAndLockView(model: model,
                              value: $camera.lockedWhiteBalance,
                              locked: $camera.isWhiteBalanceLocked,
                              editingLocked: $camera.editingLockedWhiteBalance,
                              onEditingChanged: { begin in
                                  camera.editingLockedWhiteBalance = begin
                                  guard !begin else {
                                      return
                                  }
                                  model.setManualWhiteBalance(factor: camera.lockedWhiteBalance)
                              },
                              setManual: model.setManualWhiteBalance,
                              setAuto: model.setAutoWhiteBalance)
        } else {
            NotSupportedForThisCameraView()
        }
    }
}

private struct IsoView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        TitleView(title: "ISO")
        if model.isCameraSupportingManualExposureAndIso() {
            SliderAndLockView(model: model,
                              value: $camera.lockedIso,
                              locked: $camera.isExposureAndIsoLocked,
                              editingLocked: $camera.editingLockedIso,
                              onEditingChanged: { begin in
                                  camera.editingLockedIso = begin
                                  guard !begin else {
                                      return
                                  }
                                  model.setManualIso(factor: camera.lockedIso)
                              },
                              setManual: model.setManualIso,
                              setAuto: model.setAutoExposureAndIso)
        } else {
            NotSupportedForThisCameraView()
        }
    }
}

private struct ExposureView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        TitleView(title: "EXPOSURE")
        if model.isCameraSupportingManualExposureAndIso() {
            SliderAndLockView(model: model,
                              value: $camera.lockedExposure,
                              locked: $camera.isExposureAndIsoLocked,
                              editingLocked: $camera.editingLockedExposure,
                              onEditingChanged: { begin in
                                  camera.editingLockedExposure = begin
                                  guard !begin else {
                                      return
                                  }
                                  model.setManualExposure(factor: camera.lockedExposure)
                              },
                              setManual: model.setManualExposure,
                              setAuto: model.setAutoExposureAndIso)
        } else {
            NotSupportedForThisCameraView()
        }
    }
}

struct FocusView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var camera: CameraState

    var body: some View {
        TitleView(title: "FOCUS")
        if model.isCameraSupportingManualFocus() {
            SliderAndLockView(model: model,
                              value: $camera.lockedFocus,
                              locked: $camera.isFocusLocked,
                              editingLocked: $camera.editingLockedFocus,
                              onEditingChanged: { begin in
                                  camera.editingLockedFocus = begin
                                  guard !begin else {
                                      return
                                  }
                                  model.setManualFocus(lensPosition: camera.lockedFocus)
                              },
                              setManual: model.setManualFocus,
                              setAuto: model.setAutoFocus)
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
