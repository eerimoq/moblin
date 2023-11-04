import AVFoundation
import SwiftUI

private let imageBackground = Color(red: 0.25, green: 0.25, blue: 0.25)

struct ButtonImage: View {
    var image: String
    var on: Bool
    var slash: Bool = false

    var body: some View {
        let image = Image(systemName: image)
            .frame(width: 40, height: 40)
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
                    .frame(width: 40, height: 40)
                    .foregroundColor(.white)
                    .rotationEffect(Angle(degrees: 90))
                    .shadow(color: imageBackground, radius: 0, x: 1, y: 0)
                    .shadow(color: imageBackground, radius: 0, x: -1, y: 0)
                    .shadow(color: imageBackground, radius: 0, x: 0, y: 1)
                    .shadow(color: imageBackground, radius: 0, x: 0, y: -1)
                    .shadow(color: imageBackground, radius: 0, x: -2, y: -2)
            }
        }
    }
}

struct ButtonPlaceholderImage: View {
    var body: some View {
        Button {} label: {
            Image(systemName: "pawprint")
                .frame(width: 40, height: 40)
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
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: {
                    done()
                }, label: {
                    Text("Close")
                        .padding(5)
                        .foregroundColor(.blue)
                })
            }
            .background(Color(uiColor: .systemGroupedBackground))
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
        model.sceneUpdated()
    }

    private func chatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.database.show.chat.toggle()
        model.updateButtonStates()
        model.sceneUpdated()
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
                    }
                }
            }
        }
    }
}
