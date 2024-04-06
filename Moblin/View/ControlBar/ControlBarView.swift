import SwiftUI

struct StreamButtonText: View {
    @EnvironmentObject var model: Model
    var text: String

    var body: some View {
        Text(text)
            .foregroundColor(.white)
            .frame(minWidth: 60)
            .padding(5)
            .background(model.database.streamButtonColor!.color())
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
                StreamButtonText(text: String(localized: "End"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white)
                    )
            })
            .confirmationDialog("", isPresented: $isPresentingStopConfirm) {
                Button("End") {
                    model.stopStream()
                }
            }
        } else if model.isStreamConfigured() {
            Button(action: {
                isPresentingGoLiveConfirm = true
            }, label: {
                StreamButtonText(text: String(localized: "Go Live"))
            })
            .confirmationDialog("", isPresented: $isPresentingGoLiveConfirm) {
                Button("Go Live") {
                    model.startStream()
                }
            }
        } else {
            Button(action: {
                model.resetWizard()
                model.isPresentingSetupWizard = true
            }, label: {
                StreamButtonText(text: String(localized: "Setup"))
            })
            .sheet(isPresented: $model.isPresentingSetupWizard) {
                NavigationStack {
                    StreamWizardSettingsView()
                }
            }
        }
    }
}

struct ControlBarLandscapeView: View {
    @EnvironmentObject var model: Model
    @Environment(\.accessibilityShowButtonShapes)
    private var accessibilityShowButtonShapes

    private func controlBarWidth() -> CGFloat {
        if accessibilityShowButtonShapes {
            return 150
        } else {
            return 100
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                BatteryView()
                Spacer(minLength: 0)
                ThermalStateView(thermalState: model.thermalState)
                Spacer(minLength: 0)
                Text(model.digitalClock)
                    .foregroundColor(.white)
                    .font(smallFont)
            }
            .padding([.bottom], 5)
            .padding([.leading], 0)
            .padding([.trailing], 5)
            HStack(spacing: 0) {
                Button {
                    model.showingCosmetics.toggle()
                } label: {
                    Image("\(model.iconImage)NoBackground")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding([.bottom], 4)
                        .offset(x: 2)
                        .frame(width: buttonSize, height: buttonSize)
                }
                Button {
                    model.showingSettings.toggle()
                } label: {
                    Image(systemName: "gearshape")
                        .frame(width: buttonSize, height: buttonSize)
                        .overlay(
                            Circle()
                                .stroke(.secondary)
                        )
                        .foregroundColor(.white)
                }
                .padding([.leading], 10)
            }
            .padding([.leading, .trailing], 10)
            GeometryReader { metrics in
                ScrollView(showsIndicators: false) {
                    ScrollViewReader { reader in
                        VStack {
                            Spacer(minLength: 0)
                            ButtonsLandscapeView(width: metrics.size.width)
                                .frame(width: metrics.size.width)
                                .onChange(of: model.scrollQuickButtons) { _ in
                                    let id = model.buttonPairs.last?.first.button.id ?? model.buttonPairs
                                        .last?.second?.button.id ?? UUID()
                                    reader.scrollTo(id, anchor: .bottom)
                                }
                        }
                        .frame(minHeight: metrics.size.height)
                        .onChange(of: metrics.size) { _ in
                            model.scrollQuickButtonsToBottom()
                        }
                    }
                }
                .scrollDisabled(!model.database.quickButtons!.enableScroll)
                .padding([.top], 5)
            }
            .padding([.leading, .trailing], 0)
            StreamButton()
                .padding([.top], 10)
                .padding([.leading, .trailing], 5)
        }
        .padding([.top, .bottom], 0)
        .frame(width: controlBarWidth())
        .background(.black)
    }
}

struct ControlBarPortraitView: View {
    @EnvironmentObject var model: Model
    @Environment(\.accessibilityShowButtonShapes)
    private var accessibilityShowButtonShapes

    private func controlBarWidth() -> CGFloat {
        if accessibilityShowButtonShapes {
            return 150
        } else {
            return 100
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            GeometryReader { metrics in
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { reader in
                        HStack {
                            Spacer(minLength: 0)
                            ButtonsPortraitView(width: metrics.size.height)
                                .frame(height: metrics.size.height)
                                .onChange(of: model.scrollQuickButtons) { _ in
                                    let id = model.buttonPairs.last?.first.button.id ?? model.buttonPairs
                                        .last?.second?.button.id ?? UUID()
                                    reader.scrollTo(id, anchor: .bottom)
                                }
                        }
                        .frame(minWidth: metrics.size.width)
                        .onChange(of: metrics.size) { _ in
                            model.scrollQuickButtonsToBottom()
                        }
                    }
                }
                .scrollDisabled(!model.database.quickButtons!.enableScroll)
                .padding([.top], 5)
            }
            .padding([.leading, .trailing], 0)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    BatteryView()
                    Spacer(minLength: 0)
                    ThermalStateView(thermalState: model.thermalState)
                    Spacer(minLength: 0)
                    Text(model.digitalClock)
                        .foregroundColor(.white)
                        .font(smallFont)
                }
                .padding([.bottom], 5)
                .padding([.leading], 0)
                .padding([.trailing], 5)
                HStack(spacing: 0) {
                    Button {
                        model.showingCosmetics.toggle()
                    } label: {
                        Image("\(model.iconImage)NoBackground")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding([.bottom], 4)
                            .offset(x: 2)
                            .frame(width: buttonSize, height: buttonSize)
                    }
                    Button {
                        model.showingSettings.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                            .frame(width: buttonSize, height: buttonSize)
                            .overlay(
                                Circle()
                                    .stroke(.secondary)
                            )
                            .foregroundColor(.white)
                    }
                    .padding([.leading], 10)
                }
                .padding([.leading, .trailing], 10)
                StreamButton()
                    .padding([.top], 10)
                    .padding([.leading, .trailing], 5)
            }
            .frame(width: controlBarWidth())
        }
        .padding([.top], 10)
        .padding([.bottom], 0)
        .frame(height: controlBarWidth())
        .background(.black)
    }
}
