import AVFoundation
import SwiftUI

private let imageBackground = Color(red: 0.25, green: 0.25, blue: 0.25)
private let singleButtonSize: CGFloat = 45

struct ButtonImage: View {
    var image: String
    var on: Bool
    var buttonSize: CGFloat
    var slash: Bool = false
    var pause: Bool = false
    var overlayColor: Color = .white

    var body: some View {
        let image = Image(systemName: image)
            .frame(width: buttonSize, height: buttonSize)
            .foregroundColor(.white)
            .background(imageBackground)
            .clipShape(Circle())
        ZStack {
            if on {
                image.overlay(
                    Circle()
                        .stroke(.white)
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
                    .shadow(color: imageBackground, radius: 0, x: 1, y: 0)
                    .shadow(color: imageBackground, radius: 0, x: -1, y: 0)
                    .shadow(color: imageBackground, radius: 0, x: 0, y: 1)
                    .shadow(color: imageBackground, radius: 0, x: 0, y: -1)
                    .shadow(color: imageBackground, radius: 0, x: -2, y: -2)
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

struct ButtonPlaceholderImage: View {
    var body: some View {
        Button {} label: {
            Image(systemName: "pawprint")
                .frame(width: buttonSize, height: buttonSize)
                .foregroundColor(.black)
        }
        .opacity(0.0)
    }
}

struct MicButtonView: View {
    @EnvironmentObject var model: Model
    @State var selectedMic: Mic
    var done: () -> Void

    var body: some View {
        Form {
            Section("Mic") {
                Picker("", selection: Binding(get: {
                    model.mic
                }, set: { mic, _ in
                    selectedMic = mic
                })) {
                    ForEach(model.listMics()) { mic in
                        Text(mic.name).tag(mic)
                    }
                }
                .onChange(of: selectedMic) { mic in
                    model.selectMicById(id: mic.id)
                    done()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
        }
        .toolbar {
            QuickSettingsToolbar(done: done)
        }
    }
}

struct ObsSceneView: View {
    @EnvironmentObject var model: Model
    var done: () -> Void

    var body: some View {
        Form {
            Section("OBS Scene") {
                if !model.isObsConfigured() {
                    Text("""
                    OBS remote control is not configured. Configure it in \
                    Settings → Streams → \(model.stream.name) → OBS remote control.
                    """)
                } else if !model.isObsConnected() {
                    Text("OBS remote control is not connected to the server")
                } else if model.obsScenes.isEmpty {
                    Text("Fetching OBS scenes from server...")
                } else {
                    Picker("", selection: $model.obsCurrentScene) {
                        ForEach(model.obsScenes, id: \.self) { scene in
                            Text(scene)
                        }
                    }
                    .onChange(of: model.obsCurrentScene) { _ in
                        model.setObsScene(name: model.obsCurrentScene)
                        done()
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }
            }
        }
        .toolbar {
            QuickSettingsToolbar(done: done)
        }
    }
}

private func startStopText(button: ButtonState) -> String {
    return button.isOn ? "Stop" : "Start"
}

struct ButtonsView: View {
    @EnvironmentObject var model: Model
    @State private var isPresentingObsStartStopConfirm: Bool = false
    @State private var isPresentingRecordConfirm: Bool = false

    private func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.systemImageNameOn
        } else {
            return state.button.systemImageNameOff
        }
    }

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
        model.updateButtonStates()
        model.sceneUpdated(store: false)
    }

    private func chatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.showChatMessages.toggle()
        model.updateButtonStates()
        model.sceneUpdated(store: false)
    }

    private func pauseChatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleChatPaused()
        model.updateButtonStates()
        model.sceneUpdated(store: false)
    }

    private func pauseChatOverlayColor() -> Color {
        if model.chatPaused {
            return imageBackground
        } else {
            return .white
        }
    }

    private func blackScreenAction(state _: ButtonState) {
        model.toggleBlackScreen()
        model.makeToast(
            title: String(localized: "Black screen"),
            subTitle: String(localized: "Double tap to return to main view")
        )
        model.updateButtonStates()
    }

    private func obsSceneAction(state _: ButtonState) {
        guard model.isObsConfigured() else {
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
        model.listObsScenes()
        model.showingObsScene = true
    }

    private func obsStartStopStreamAction(state: ButtonState) {
        guard model.isObsConfigured() else {
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
        if state.button.isOn {
            model.obsStopStream()
        } else {
            model.obsStartStream()
        }
        model.updateButtonStates()
        isPresentingObsStartStopConfirm = false
    }

    private func recordAction(state: ButtonState) {
        state.button.isOn.toggle()
        if state.button.isOn {
            model.startRecording()
        } else {
            model.stopRecording()
        }
        model.updateButtonStates()
    }

    var body: some View {
        VStack {
            ForEach(model.buttonPairs) { pair in
                if model.database.quickButtons!.twoColumns {
                    HStack(alignment: .top) {
                        if let second = pair.second {
                            VStack {
                                switch second.button.type {
                                case .torch:
                                    Button(action: {
                                        torchAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .mute:
                                    Button(action: {
                                        muteAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .bitrate:
                                    Button(action: {
                                        model.showingBitrate = true
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .widget:
                                    Button(action: {
                                        widgetAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .mic:
                                    Button(action: {
                                        model.showingMic = true
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .chat:
                                    Button(action: {
                                        chatAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize,
                                            slash: true
                                        )
                                    })
                                case .pauseChat:
                                    Button(action: {
                                        pauseChatAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize,
                                            pause: true,
                                            overlayColor: pauseChatOverlayColor()
                                        )
                                    })
                                case .blackScreen:
                                    Button(action: {
                                        blackScreenAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .obsScene:
                                    Button(action: {
                                        obsSceneAction(state: second)
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                case .obsStartStopStream:
                                    Button(action: {
                                        isPresentingObsStartStopConfirm = true
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                    .confirmationDialog("", isPresented: $isPresentingObsStartStopConfirm) {
                                        Button(startStopText(button: second)) {
                                            obsStartStopStreamAction(state: second)
                                        }
                                    }
                                case .record:
                                    Button(action: {
                                        isPresentingRecordConfirm = true
                                    }, label: {
                                        ButtonImage(
                                            image: getImage(state: second),
                                            on: second.isOn,
                                            buttonSize: buttonSize
                                        )
                                    })
                                    .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                                        Button(startStopText(button: second)) {
                                            recordAction(state: second)
                                        }
                                    }
                                }
                                if model.database.quickButtons!.showName {
                                    Text(second.button.name)
                                        .foregroundColor(.white)
                                        .font(.system(size: 10))
                                }
                            }
                        } else {
                            ButtonPlaceholderImage()
                        }
                        VStack {
                            switch pair.first.button.type {
                            case .torch:
                                Button(action: {
                                    torchAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .mute:
                                Button(action: {
                                    muteAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .bitrate:
                                Button(action: {
                                    model.showingBitrate = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .widget:
                                Button(action: {
                                    widgetAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .mic:
                                Button(action: {
                                    model.showingMic = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .chat:
                                Button(action: {
                                    chatAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize,
                                        slash: true
                                    )
                                })
                            case .pauseChat:
                                Button(action: {
                                    pauseChatAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize,
                                        pause: true,
                                        overlayColor: pauseChatOverlayColor()
                                    )
                                })
                            case .blackScreen:
                                Button(action: {
                                    blackScreenAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .obsScene:
                                Button(action: {
                                    obsSceneAction(state: pair.first)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                            case .obsStartStopStream:
                                Button(action: {
                                    isPresentingObsStartStopConfirm = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                                .confirmationDialog("", isPresented: $isPresentingObsStartStopConfirm) {
                                    Button(startStopText(button: pair.first)) {
                                        obsStartStopStreamAction(state: pair.first)
                                    }
                                }
                            case .record:
                                Button(action: {
                                    isPresentingRecordConfirm = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: pair.first),
                                        on: pair.first.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                                .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                                    Button(startStopText(button: pair.first)) {
                                        recordAction(state: pair.first)
                                    }
                                }
                            }
                            if model.database.quickButtons!.showName {
                                Text(pair.first.button.name)
                                    .foregroundColor(.white)
                                    .font(.system(size: 10))
                            }
                        }
                    }
                    .id(pair.first.button.id)
                } else {
                    if let second = pair.second {
                        VStack {
                            switch second.button.type {
                            case .torch:
                                Button(action: {
                                    torchAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .mute:
                                Button(action: {
                                    muteAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .bitrate:
                                Button(action: {
                                    model.showingBitrate = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .widget:
                                Button(action: {
                                    widgetAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .mic:
                                Button(action: {
                                    model.showingMic = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .chat:
                                Button(action: {
                                    chatAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize,
                                        slash: true
                                    )
                                })
                            case .pauseChat:
                                Button(action: {
                                    pauseChatAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize,
                                        pause: true,
                                        overlayColor: pauseChatOverlayColor()
                                    )
                                })
                            case .blackScreen:
                                Button(action: {
                                    blackScreenAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .obsScene:
                                Button(action: {
                                    obsSceneAction(state: second)
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                            case .obsStartStopStream:
                                Button(action: {
                                    isPresentingObsStartStopConfirm = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: singleButtonSize
                                    )
                                })
                                .confirmationDialog("", isPresented: $isPresentingObsStartStopConfirm) {
                                    Button(startStopText(button: second)) {
                                        obsStartStopStreamAction(state: second)
                                    }
                                }
                            case .record:
                                Button(action: {
                                    isPresentingRecordConfirm = true
                                }, label: {
                                    ButtonImage(
                                        image: getImage(state: second),
                                        on: second.isOn,
                                        buttonSize: buttonSize
                                    )
                                })
                                .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                                    Button(startStopText(button: second)) {
                                        recordAction(state: second)
                                    }
                                }
                            }
                            if model.database.quickButtons!.showName {
                                Text(second.button.name)
                                    .foregroundColor(.white)
                                    .font(.system(size: 10))
                            }
                        }
                    } else {
                        EmptyView()
                    }
                    VStack {
                        switch pair.first.button.type {
                        case .torch:
                            Button(action: {
                                torchAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .mute:
                            Button(action: {
                                muteAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .bitrate:
                            Button(action: {
                                model.showingBitrate = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .widget:
                            Button(action: {
                                widgetAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .mic:
                            Button(action: {
                                model.showingMic = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .chat:
                            Button(action: {
                                chatAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize,
                                    slash: true
                                )
                            })
                        case .pauseChat:
                            Button(action: {
                                pauseChatAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize,
                                    pause: true,
                                    overlayColor: pauseChatOverlayColor()
                                )
                            })
                        case .blackScreen:
                            Button(action: {
                                blackScreenAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .obsScene:
                            Button(action: {
                                obsSceneAction(state: pair.first)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                        case .obsStartStopStream:
                            Button(action: {
                                isPresentingObsStartStopConfirm = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: singleButtonSize
                                )
                            })
                            .confirmationDialog("", isPresented: $isPresentingObsStartStopConfirm) {
                                Button(startStopText(button: pair.first)) {
                                    obsStartStopStreamAction(state: pair.first)
                                }
                            }
                        case .record:
                            Button(action: {
                                isPresentingRecordConfirm = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: pair.first),
                                    on: pair.first.isOn,
                                    buttonSize: buttonSize
                                )
                            })
                            .confirmationDialog("", isPresented: $isPresentingRecordConfirm) {
                                Button(startStopText(button: pair.first)) {
                                    recordAction(state: pair.first)
                                }
                            }
                        }
                        if model.database.quickButtons!.showName {
                            Text(pair.first.button.name)
                                .foregroundColor(.white)
                                .font(.system(size: 10))
                        }
                    }
                    .id(pair.first.button.id)
                }
            }
        }
    }
}
