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
    
    func getImage(state: ButtonState) -> String {
        if state.isOn {
            return state.button.systemImageNameOn
        } else {
            return state.button.systemImageNameOff
        }
    }
    
    func torchAction(state: ButtonState) {
        state.button.isOn = !state.button.isOn
        model.toggleTorch()
        model.updateButtonStates()
        model.store()
    }
    
    func muteAction(state: ButtonState) {
        state.button.isOn = !state.button.isOn
        model.toggleMute()
        model.updateButtonStates()
        model.store()
    }
    
    func widgetAction(state: ButtonState) {
        state.button.isOn = !state.button.isOn
        if state.button.isOn {
            model.movieEffectOn()
        } else {
            model.movieEffectOff()
        }
        model.updateButtonStates()
        model.store()
    }
    
    var body: some View {
        VStack {
            ForEach(model.buttonPairs) { pair in
                HStack {
                    if let second = pair.second {
                        switch second.button.type {
                        case "Torch":
                            Button(action: {
                                torchAction(state: second)
                            }, label: {
                                ButtonImage(image: getImage(state: second), on: second.isOn)
                            })
                        case "Mute":
                            Button(action: {
                                muteAction(state: second)
                            }, label: {
                                ButtonImage(image: getImage(state: second), on: second.isOn)
                            })
                        case "Widget":
                            Button(action: {
                                widgetAction(state: second)
                            }, label: {
                                ButtonImage(image: getImage(state: second), on: second.isOn)
                            })
                        default:
                            EmptyView()
                        }
                    } else {
                        ButtonPlaceholderImage()
                    }
                    switch pair.first.button.type {
                    case "Torch":
                        Button(action: {
                            torchAction(state: pair.first)
                        }, label: {
                            ButtonImage(image: getImage(state: pair.first), on: pair.first.isOn)
                        })
                    case "Mute":
                        Button(action: {
                            muteAction(state: pair.first)
                        }, label: {
                            ButtonImage(image: getImage(state: pair.first), on: pair.first.isOn)
                        })
                    case "Widget":
                        Button(action: {
                            widgetAction(state: pair.first)
                        }, label: {
                            ButtonImage(image: getImage(state: pair.first), on: pair.first.isOn)
                        })
                    default:
                        EmptyView()
                    }
                }
            }
        }
    }
}
