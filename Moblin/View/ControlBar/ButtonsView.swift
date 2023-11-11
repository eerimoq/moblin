import AVFoundation
import SwiftUI

private let imageBackground = Color(red: 0.25, green: 0.25, blue: 0.25)

struct ButtonImage: View {
    var image: String
    var on: Bool
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

struct ButtonsView: View {
    @EnvironmentObject var model: Model
    var height: CGFloat
    @Environment(\.accessibilityShowButtonShapes)
    private var accessibilityShowButtonShapes

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

    private func buttonHeight() -> CGFloat {
        if accessibilityShowButtonShapes {
            return 60
        } else {
            return 45
        }
    }

    var body: some View {
        VStack {
            ForEach(model.buttonPairs.suffix(Int(height / buttonHeight()))) { pair in
                HStack {
                    if let second = pair.second {
                        switch second.button.type {
                        case .torch:
                            Button(action: {
                                torchAction(state: second)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn
                                )
                            })
                        case .mute:
                            Button(action: {
                                muteAction(state: second)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn
                                )
                            })
                        case .bitrate:
                            Button(action: {
                                model.showingBitrate = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn
                                )
                            })
                        case .widget:
                            Button(action: {
                                widgetAction(state: second)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn
                                )
                            })
                        case .mic:
                            Button(action: {
                                model.showingMic = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn
                                )
                            })
                        case .chat:
                            Button(action: {
                                chatAction(state: second)
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn,
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
                                    pause: true,
                                    overlayColor: pauseChatOverlayColor()
                                )
                            })
                        }
                    } else {
                        ButtonPlaceholderImage()
                    }
                    switch pair.first.button.type {
                    case .torch:
                        Button(action: {
                            torchAction(state: pair.first)
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn
                            )
                        })
                    case .mute:
                        Button(action: {
                            muteAction(state: pair.first)
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn
                            )
                        })
                    case .bitrate:
                        Button(action: {
                            model.showingBitrate = true
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn
                            )
                        })
                    case .widget:
                        Button(action: {
                            widgetAction(state: pair.first)
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn
                            )
                        })
                    case .mic:
                        Button(action: {
                            model.showingMic = true
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn
                            )
                        })
                    case .chat:
                        Button(action: {
                            chatAction(state: pair.first)
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn,
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
                                pause: true,
                                overlayColor: pauseChatOverlayColor()
                            )
                        })
                    }
                }
            }
        }
    }
}
