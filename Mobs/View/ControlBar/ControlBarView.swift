import SwiftUI

struct StreamButtonText: View {
    var text: String

    var body: some View {
        Text(text)
            .foregroundColor(.white)
            .frame(width: 60)
            .padding(5)
            .background(.red)
            .cornerRadius(10)
    }
}

struct StreamButton: View {
    @ObservedObject var model: Model
    @State private var isPresentingGoLiveConfirm: Bool = false
    @State private var isPresentingStopConfirm: Bool = false

    var body: some View {
        if model.isLive {
            Button(action: {
                isPresentingStopConfirm = true
            }, label: {
                StreamButtonText(text: "End")
            })
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white)
            )
            .confirmationDialog("", isPresented: $isPresentingStopConfirm) {
                Button("End") {
                    model.stopStream()
                }
            }
        } else {
            Button(action: {
                isPresentingGoLiveConfirm = true
            }, label: {
                StreamButtonText(text: "Go Live")
            })
            .confirmationDialog("", isPresented: $isPresentingGoLiveConfirm) {
                Button("Go live") {
                    model.startStream()
                }
            }
        }
    }
}

struct ControlBarView: View {
    @ObservedObject var model: Model

    var body: some View {
        VStack {
            VStack {
                HStack {
                    BatteryView(level: model.batteryLevel)
                    Spacer()
                    ThermalStateView(thermalState: model.thermalState)
                    Spacer()
                    Text(model.digitalClock)
                        .foregroundColor(.white)
                        .font(.system(size: 13))
                }
                HStack {
                    Image("AppIconNoBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding([.bottom], 5)
                        .frame(width: 40, height: 40)
                    Button(action: {
                        logger.error("Settings")
                    }, label: {
                        NavigationLink(destination: SettingsView(model: model)) {
                            Image(systemName: "gearshape")
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Circle()
                                        .stroke(.secondary)
                                )
                                .foregroundColor(.white)
                        }
                    })
                }
                Spacer()
                ButtonsView(model: model)
                StreamButton(model: model)
                    .padding([.top], 10)
            }
            .padding([.leading, .trailing, .top], 10)
        }
        .frame(width: 100)
        .background(.black)
    }
}
