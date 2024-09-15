import AVFoundation
import SwiftUI

let singleQuickButtonSize: CGFloat = 45

private struct QuickButtonImage: View {
    var state: ButtonState
    var buttonSize: CGFloat
    var slash: Bool = false
    var pause: Bool = false
    var overlayColor: Color = .white

    private func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.systemImageNameOn
        } else {
            return state.button.systemImageNameOff
        }
    }

    private var backgroundColor: Color {
        state.button.backgroundColor!.color()
    }

    var body: some View {
        let image = Image(systemName: getImage(state: state))
            .frame(width: buttonSize, height: buttonSize)
            .foregroundColor(.white)
            .background(backgroundColor)
            .clipShape(Circle())
        ZStack {
            if state.isOn {
                image.overlay(
                    Circle()
                        .stroke(.white)
                        .frame(width: buttonSize - 1, height: buttonSize - 1)
                )
            } else {
                image
            }
            if slash {
                // Button press animation not perfect.
                Image(systemName: "line.diagonal")
                    .frame(width: buttonSize, height: buttonSize)
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: 90))
                    .shadow(color: backgroundColor, radius: 0, x: 1, y: 0)
                    .shadow(color: backgroundColor, radius: 0, x: -1, y: 0)
                    .shadow(color: backgroundColor, radius: 0, x: 0, y: 1)
                    .shadow(color: backgroundColor, radius: 0, x: 0, y: -1)
                    .shadow(color: backgroundColor, radius: 0, x: -2, y: -2)
            }
            if pause {
                // Button press animation not perfect.
                Image(systemName: "pause")
                    .bold()
                    .font(.system(size: 9))
                    .frame(width: buttonSize, height: buttonSize)
                    .offset(y: -1)
                    .foregroundColor(overlayColor)
            }
        }
    }
}

struct QuickButtonPlaceholderImage: View {
    var body: some View {
        Button {} label: {
            Image(systemName: "pawprint")
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.black)
        }
        .opacity(0.0)
    }
}

private func startStopText(button: ButtonState) -> String {
    return button.isOn ? "Stop" : "Start"
}

struct QuickButtonsInnerView: View {
    @EnvironmentObject var model: Model
    var state: ButtonState
    var size: CGFloat
    var nameSize: CGFloat
    var nameWidth: CGFloat
    @State private var isPresentingRecordConfirm: Bool = false
    @State private var isPresentingStartWorkoutTypePicker: Bool = false
    @State private var isPresentingStopWorkoutConfirm: Bool = false

    private func torchAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleTorch()
        model.updateButtonStates()
    }

    private func muteAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleMute()
        model.updateButtonStates()
    }

    private func widgetAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.sceneUpdated(store: false)
    }

    private func blackScreenAction() {
        model.toggleBlackScreen()
        model.makeToast(
            title: String(localized: "Black screen"),
            subTitle: String(localized: "Double tap to return to main view")
        )
        model.updateButtonStates()
    }

    private func imageAction(state: ButtonState) {
        model.showingCamera.toggle()
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .image, isOn: state.button.isOn)
        model.updateButtonStates()
    }

    private func recordAction() {
        if !model.isRecording {
            model.startRecording()
        } else {
            model.stopRecording()
        }
    }

    private func videoEffectAction(state: ButtonState, type: SettingsButtonType) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: type, isOn: state.button.isOn)
        model.sceneUpdated(store: false)
        model.updateButtonStates()
    }

    private func movieAction(state: ButtonState) {
        videoEffectAction(state: state, type: .movie)
    }

    private func fourThreeAction(state: ButtonState) {
        videoEffectAction(state: state, type: .fourThree)
    }

    private func grayScaleAction(state: ButtonState) {
        videoEffectAction(state: state, type: .grayScale)
    }

    private func sepiaAction(state: ButtonState) {
        videoEffectAction(state: state, type: .sepia)
    }

    private func tripleAction(state: ButtonState) {
        videoEffectAction(state: state, type: .triple)
    }

    private func pixellateAction(state: ButtonState) {
        videoEffectAction(state: state, type: .pixellate)
    }

    private func streamAction(state _: ButtonState) {
        model.showingStreamSwitcher = true
    }

    private func gridAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showingGrid.toggle()
        model.sceneUpdated(store: false)
        model.updateButtonStates()
    }

    private func obsAction(state _: ButtonState) {
        guard model.isObsRemoteControlConfigured() else {
            model.makeErrorToast(
                title: String(localized: "OBS remote control is not configured"),
                subTitle: String(
                    localized: """
                    Configure it in Settings → Streams → \(model.stream.name) → \
                    OBS remote control.
                    """
                )
            )
            return
        }
        model.showingObs = true
        model.listObsScenes()
        model.startObsSourceScreenshot()
        model.startObsAudioVolume()
        model.updateObsAudioDelay()
    }

    private func remoteAction(state _: ButtonState) {
        guard model.isRemoteControlAssistantConfigured() else {
            model.makeErrorToast(
                title: String(localized: "Remote control assistant is not configured"),
                subTitle: String(localized: "Configure it in Settings → Remote control")
            )
            return
        }
        model.showingRemoteControl = true
        model.updateRemoteControlAssistantStatus()
        model.detachCamera()
        model.updateScreenAutoOff()
        if model.remoteControlAssistantShowPreview {
            model.remoteControlAssistantStartPreview()
        }
    }

    private func drawAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .draw, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleDrawOnStream()
    }

    private func localOverlaysAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .localOverlays, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleLocalOverlays()
    }

    private func browserAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.setGlobalButtonState(type: .browser, isOn: state.button.isOn)
        model.updateButtonStates()
        model.toggleBrowser()
    }

    private func cameraPreviewAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.updateButtonStates()
        model.showCameraPreview.toggle()
    }

    private func faceAction(state _: ButtonState) {
        state.button.isOn.toggle()
        model.updateButtonStates()
        model.showFace.toggle()
    }

    private func pollAction(state _: ButtonState) {
        model.togglePoll()
        videoEffectAction(state: state, type: .poll)
    }

    private func snapshotAction(state _: ButtonState) {
        model.takeSnapshot()
    }

    var body: some View {
        VStack {
            switch state.button.type {
            case .unknown:
                QuickButtonPlaceholderImage()
            case .torch:
                Button(action: {
                    torchAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .mute:
                Button(action: {
                    muteAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .bitrate:
                Button(action: {
                    model.showingBitrate = true
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .widget:
                Button(action: {
                    widgetAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .mic:
                Button(action: {
                    model.showingMic = true
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .chat:
                Button(action: {
                    model.showingChat = true
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .blackScreen:
                Button(action: {
                    blackScreenAction()
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .record:
                Button(action: {
                    if model.database.startStopRecordingConfirmations! {
                        isPresentingRecordConfirm = true
                    } else {
                        recordAction()
                    }
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
                .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                    Button(startStopText(button: state)) {
                        recordAction()
                    }
                }
            case .recordings:
                Button(action: {
                    model.showingRecordings = true
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .image:
                Button(action: {
                    imageAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .movie:
                Button(action: {
                    movieAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .fourThree:
                Button(action: {
                    fourThreeAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .grayScale:
                Button(action: {
                    grayScaleAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .sepia:
                Button(action: {
                    sepiaAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .triple:
                Button(action: {
                    tripleAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .pixellate:
                Button(action: {
                    pixellateAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .stream:
                Button(action: {
                    streamAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .grid:
                Button(action: {
                    gridAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .obs:
                Button(action: {
                    obsAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .remote:
                Button(action: {
                    remoteAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .draw:
                Button(action: {
                    drawAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .localOverlays:
                Button(action: {
                    localOverlaysAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .browser:
                Button(action: {
                    browserAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .lut:
                Button(action: {}, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .cameraPreview:
                Button(action: {
                    cameraPreviewAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .face:
                Button(action: {
                    faceAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .poll:
                Button(action: {
                    pollAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .snapshot:
                Button(action: {
                    snapshotAction(state: state)
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .widgets:
                Button(action: {
                    model.showingWidgets = true
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .luts:
                Button(action: {
                    model.showingLuts = true
                }, label: {
                    QuickButtonImage(state: state, buttonSize: size)
                })
            case .workout:
                if state.isOn {
                    Button(action: {
                        isPresentingStopWorkoutConfirm = true
                    }, label: {
                        QuickButtonImage(state: state, buttonSize: size)
                    })
                    .confirmationDialog("", isPresented: $isPresentingStopWorkoutConfirm) {
                        Button("Stop workout") {
                            model.stopWorkout()
                        }
                    }
                } else {
                    Button(action: {
                        isPresentingStartWorkoutTypePicker = true
                    }, label: {
                        QuickButtonImage(state: state, buttonSize: size)
                    })
                    .confirmationDialog("", isPresented: $isPresentingStartWorkoutTypePicker) {
                        Button("Start walking workout") {
                            model.startWorkout(type: .walking)
                        }
                        Button("Start running workout") {
                            model.startWorkout(type: .running)
                        }
                        Button("Start cycling workout") {
                            model.startWorkout(type: .cycling)
                        }
                    }
                }
            }
            if model.database.quickButtons!
                .showName && !(model.stream.portrait! || model.database.portrait!)
            {
                Text(state.button.name)
                    .multilineTextAlignment(.center)
                    .frame(width: nameWidth, alignment: .center)
                    .foregroundColor(.white)
                    .font(.system(size: nameSize))
            }
        }
    }
}
