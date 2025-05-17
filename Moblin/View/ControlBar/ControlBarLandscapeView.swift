import SwiftUI

private struct QuickButtonsView: View {
    @EnvironmentObject var model: Model
    var page: Int

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
                            nameWidth: 90,
                        )
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        state: pair.first,
                        size: singleQuickButtonSize,
                        nameSize: 12,
                        nameWidth: 90,
                    )
                    .id(pair.first.button.id)
                }
            }
        }
    }
}

private struct StatusView: View {
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

private struct IconAndSettingsView: View {
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
        .padding([.bottom], 5)
    }
}

private struct PageView: View {
    @EnvironmentObject var model: Model
    var page: Int

    var body: some View {
        ScrollView(showsIndicators: false) {
            QuickButtonsView(page: page)
        }
        .scrollDisabled(!model.database.quickButtons!.enableScroll)
        .rotationEffect(.degrees(180))
        .padding([.leading, .trailing], 0)
    }
}

private struct MainPageView: View {
    var body: some View {
        VStack(spacing: 0) {
            IconAndSettingsView()
            PageView(page: 0)
            StreamButton()
                .padding([.top], 10)
                .padding([.leading, .trailing], 5)
        }
    }
}

private struct PagesView: View {
    @EnvironmentObject var model: Model
    var width: Double

    var body: some View {
        if #available(iOS 17, *) {
            VStack {
                ScrollView(.horizontal) {
                    HStack {
                        Group {
                            MainPageView()
                            ForEach([1, 2, 3, 4], id: \.self) { page in
                                if !model.buttonPairs[page].isEmpty {
                                    PageView(page: page)
                                }
                            }
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
            MainPageView()
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
            StatusView()
            PagesView(width: controlBarWidth())
        }
        .padding([.top, .bottom], 0)
        .frame(width: controlBarWidth())
        .background(.black)
    }
}
