import SwiftUI

private struct ButtonsPortraitView: View {
    @EnvironmentObject var model: Model
    var page: Int
    var width: CGFloat

    var body: some View {
        HStack {
            ForEach(model.getButtonPairs(page: page)) { pair in
                if model.database.quickButtons!.twoColumns {
                    VStack(alignment: .leading) {
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

private struct ControlBarPortraitQuickButtonsView: View {
    @EnvironmentObject var model: Model
    var page: Int

    var body: some View {
        GeometryReader { metrics in
            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { reader in
                    HStack {
                        Spacer(minLength: 0)
                        ButtonsPortraitView(page: page, width: metrics.size.height)
                            .frame(height: metrics.size.height)
                            .onChange(of: model.scrollQuickButtons) { _ in
                                let id = model.buttonPairs[page].last?.first.button.id ?? model.buttonPairs[page]
                                    .last?.second?.button.id ?? UUID()
                                reader.scrollTo(id, anchor: .trailing)
                            }
                    }
                    .frame(minWidth: metrics.size.width)
                }
            }
            .scrollDisabled(!model.database.quickButtons!.enableScroll)
            .padding([.top], 5)
        }
        .padding([.leading, .trailing], 0)
    }
}

private struct ControlBarPortraitQuickButtonsPagesView: View {
    @EnvironmentObject var model: Model
    var height: Double

    var body: some View {
        if #available(iOS 17, *) {
            ScrollView(.vertical) {
                LazyVStack {
                    Group {
                        ControlBarPortraitQuickButtonsView(page: 0)
                        ControlBarPortraitQuickButtonsView(page: 1)
                        ControlBarPortraitQuickButtonsView(page: 2)
                        ControlBarPortraitQuickButtonsView(page: 3)
                        ControlBarPortraitQuickButtonsView(page: 4)
                    }
                    .containerRelativeFrame(.vertical, count: 1, spacing: 0)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollIndicators(.never)
            .frame(height: height - 1)
        } else {
            ControlBarPortraitQuickButtonsView(page: 0)
        }
    }
}

private struct ControlBarPortraitIconAndSettingsView: View {
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

struct ControlBarPortraitView: View {
    @EnvironmentObject var model: Model
    @Environment(\.accessibilityShowButtonShapes)
    private var accessibilityShowButtonShapes

    private func controlBarHeight() -> CGFloat {
        if accessibilityShowButtonShapes {
            return 150
        } else {
            return 100
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            ControlBarPortraitQuickButtonsPagesView(height: controlBarHeight())
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ThermalStateView(thermalState: model.thermalState)
                    Spacer(minLength: 0)
                }
                .padding([.bottom], 5)
                .padding([.leading], 0)
                .padding([.trailing], 5)
                ControlBarPortraitIconAndSettingsView()
                StreamButton()
                    .padding([.top], 10)
                    .padding([.leading, .trailing], 5)
            }
            .frame(width: controlBarHeight())
        }
        .frame(height: controlBarHeight())
        .background(.black)
    }
}
