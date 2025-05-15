import SwiftUI

private struct ButtonsLandscapeView: View {
    @EnvironmentObject var model: Model
    var page: Int
    var width: CGFloat

    var body: some View {
        VStack {
            ForEach(model.getButtonPairs(page: page)) { pair in
                if model.database.quickButtons!.twoColumns {
                    HStack(alignment: .top) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                state: second,
                                size: buttonSize,
                                nameSize: 10,
                                nameWidth: buttonSize,
                            )
                        } else {
                            QuickButtonPlaceholderImage()
                        }
                        QuickButtonsInnerView(
                            state: pair.first,
                            size: buttonSize,
                            nameSize: 10,
                            nameWidth: buttonSize,
                        )
                    }
                    .id(pair.first.button.id)
                } else {
                    if let second = pair.second {
                        QuickButtonsInnerView(
                            state: second,
                            size: singleQuickButtonSize,
                            nameSize: 12,
                            nameWidth: width - 10,
                        )
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        state: pair.first,
                        size: singleQuickButtonSize,
                        nameSize: 12,
                        nameWidth: width - 10,
                    )
                    .id(pair.first.button.id)
                }
            }
        }
    }
}

private struct ControlBarLandscapeStatusView: View {
    @EnvironmentObject var model: Model

    var body: some View {
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
    }
}

private struct ControlBarLandscapeIconAndSettingsView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.toggleShowingPanel(type: nil, panel: .cosmetics)
            } label: {
                Image("\(model.iconImage)NoBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding([.bottom], 4)
                    .offset(x: 2)
                    .frame(width: buttonSize, height: buttonSize)
            }
            Button {
                model.toggleShowingPanel(type: nil, panel: .settings)
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
    }
}

private struct ControlBarLandscapeQuickButtonsView: View {
    @EnvironmentObject var model: Model
    var page: Int

    var body: some View {
        GeometryReader { metrics in
            ScrollView(showsIndicators: false) {
                ScrollViewReader { reader in
                    VStack {
                        Spacer(minLength: 0)
                        ButtonsLandscapeView(page: page, width: metrics.size.width)
                            .frame(width: metrics.size.width)
                            .onChange(of: model.scrollQuickButtons) { _ in
                                let id = model.buttonPairs[page].last?.first.button.id ?? model.buttonPairs[page]
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
    }
}

private struct ControlBarLandscapeQuickButtonsPagesView: View {
    @EnvironmentObject var model: Model
    var width: Double

    var body: some View {
        if #available(iOS 17, *) {
            VStack {
                ScrollView(.horizontal) {
                    HStack {
                        Group {
                            ControlBarLandscapeQuickButtonsView(page: 0)
                            ControlBarLandscapeQuickButtonsView(page: 1)
                            ControlBarLandscapeQuickButtonsView(page: 2)
                            ControlBarLandscapeQuickButtonsView(page: 3)
                            ControlBarLandscapeQuickButtonsView(page: 4)
                        }
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollIndicators(.never)
                .frame(width: width - 1)
            }
        } else {
            ControlBarLandscapeQuickButtonsView(page: 0)
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
            ControlBarLandscapeStatusView()
            ControlBarLandscapeIconAndSettingsView()
            ControlBarLandscapeQuickButtonsPagesView(width: controlBarWidth())
            StreamButton()
                .padding([.top], 10)
                .padding([.leading, .trailing], 5)
        }
        .padding([.top, .bottom], 0)
        .frame(width: controlBarWidth())
        .background(.black)
    }
}
