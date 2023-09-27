import SwiftUI

struct ButtonImage: View {
    var image: String
    var on: Bool

    var body: some View {
        let image = Image(systemName: image)
            .frame(width: 40, height: 40)
            .foregroundColor(.white)
            .background(.blue)
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

struct ButtonsView: View {
    @ObservedObject var model: Model
    @State var showingBitrate = false

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
                                showingBitrate = true
                            }, label: {
                                ButtonImage(
                                    image: getImage(state: second),
                                    on: second.isOn
                                )
                            })
                            .popover(isPresented: $showingBitrate) {
                                StreamVideoBitrateSettingsButtonView(model: model, done: {
                                    showingBitrate = false
                                })
                            }
                        case .widget:
                            Button(action: {
                                widgetAction(state: second)
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
                            showingBitrate = true
                        }, label: {
                            ButtonImage(
                                image: getImage(state: pair.first),
                                on: pair.first.isOn
                            )
                        })
                        .popover(isPresented: $showingBitrate) {
                            StreamVideoBitrateSettingsButtonView(model: model, done: {
                                showingBitrate = false
                            })
                        }
                    case .widget:
                        Button(action: {
                            widgetAction(state: pair.first)
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
