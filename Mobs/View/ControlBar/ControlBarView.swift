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
    @EnvironmentObject var model: Model
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
    @EnvironmentObject var model: Model
    var showSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BatteryView(level: model.batteryLevel)
                Spacer()
                ThermalStateView(thermalState: model.thermalState)
                Spacer()
                Text(model.digitalClock)
                    .foregroundColor(.white)
                    .font(smallFont)
            }
            .padding([.bottom], 10)
            HStack(spacing: 0) {
                Image("\(model.iconImage)NoBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding([.bottom], 4)
                    .offset(x: 7)
                    .frame(width: 40, height: 40)
                Button {
                    showSettings()
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(.secondary)
                        )
                        .foregroundColor(.white)
                }
                .padding([.leading], 15)
            }
            GeometryReader { metrics in
                VStack(spacing: 0) {
                    Spacer()
                    ButtonsView(height: metrics.size.height)
                }
            }
            StreamButton()
                .padding([.top], 10)
        }
        .padding([.leading, .trailing], 10)
        .padding([.top, .bottom], 0)
        .frame(width: 100)
        .background(.black)
    }
}
