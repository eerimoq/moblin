import AVFoundation
import SwiftUI

struct ButtonImage: View {
    var image: String
    var on: Bool

    var body: some View {
        let image = Image(systemName: image)
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
            .background(.gray.opacity(0.5))
            .clipShape(Circle())
        if on {
            image.overlay(
                Circle()
                    .stroke(.white)
            )
        } else {
            image
        }
    }
}

struct ButtonPlaceholderImage: View {
    var body: some View {
        Image(systemName: "pawprint")
            .frame(width: 40, height: 40)
            .foregroundColor(.black)
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

    func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.systemImageNameOn
        } else {
            return state.button.systemImageNameOff
        }
    }

    func torchAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleTorch()
        model.updateButtonStates()
    }

    func muteAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.toggleMute()
        model.updateButtonStates()
    }

    func widgetAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.updateButtonStates()
        model.sceneUpdated()
    }

    func chatAction(state: ButtonState) {
        state.button.isOn.toggle()
        model.database.show.chat.toggle()
        model.updateButtonStates()
        model.sceneUpdated()
    }

    var body: some View {
        VStack {
            ForEach(model.buttonPairs) { pair in
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
                                    on: second.isOn
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
                                on: pair.first.isOn
                            )
                        })
                    }
                }
            }
        }
    }
}
