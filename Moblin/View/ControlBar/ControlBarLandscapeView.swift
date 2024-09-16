import SwiftUI

private struct ButtonsLandscapeView: View {
    @EnvironmentObject var model: Model
    var width: CGFloat

    var body: some View {
        VStack {
            ForEach(model.buttonPairs) { pair in
                if model.database.quickButtons!.twoColumns {
                    HStack(alignment: .top) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                state: second,
                                size: buttonSize,
                                nameSize: 10,
                                nameWidth: buttonSize
                            )
                        } else {
                            QuickButtonPlaceholderImage()
                        }
                        QuickButtonsInnerView(
                            state: pair.first,
                            size: buttonSize,
                            nameSize: 10,
                            nameWidth: buttonSize
                        )
                    }
                    .id(pair.first.button.id)
                } else {
                    if let second = pair.second {
                        QuickButtonsInnerView(
                            state: second,
                            size: singleQuickButtonSize,
                            nameSize: 12,
                            nameWidth: width - 10
                        )
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        state: pair.first,
                        size: singleQuickButtonSize,
                        nameSize: 12,
                        nameWidth: width - 10
                    )
                    .id(pair.first.button.id)
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
                if isPhone() {
                    BatteryView()
                }
                Spacer(minLength: 0)
                ThermalStateView(thermalState: model.thermalState)
                Spacer(minLength: 0)
                if isPhone() {
                    Text(model.digitalClock)
                        .foregroundColor(.white)
                        .font(smallFont)
                }
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
