import SwiftUI

private func edgesToIgnore() -> Edge.Set {
    if isPhone() {
        return [.trailing]
    } else {
        return []
    }
}

private struct QuickButtonsView: View {
    @EnvironmentObject var model: Model
    var page: Int
    let width: Double

    private func buttonSize() -> Double {
        if model.database.quickButtonsGeneral.bigButtons {
            return controlBarQuickButtonSingleQuickButtonSize
        } else {
            return controlBarButtonSize
        }
    }

    private func nameSize() -> Double {
        if model.database.quickButtonsGeneral.bigButtons {
            return controlBarQuickButtonNameSingleColumnSize
        } else {
            return controlBarQuickButtonNameSize
        }
    }

    var body: some View {
        VStack {
            ForEach(model.getQuickButtonPairs(page: page)) { pair in
                if model.database.quickButtonsGeneral.twoColumns {
                    HStack(alignment: .bottom) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                state: second,
                                size: buttonSize(),
                                nameSize: nameSize(),
                                nameWidth: buttonSize(),
                            )
                        } else {
                            QuickButtonPlaceholderImage(size: buttonSize())
                        }
                        QuickButtonsInnerView(
                            state: pair.first,
                            size: buttonSize(),
                            nameSize: nameSize(),
                            nameWidth: buttonSize(),
                        )
                    }
                } else {
                    if let second = pair.second {
                        QuickButtonsInnerView(
                            state: second,
                            size: buttonSize(),
                            nameSize: nameSize(),
                            nameWidth: width - 10,
                        )
                        .frame(width: width - 10)
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        state: pair.first,
                        size: buttonSize(),
                        nameSize: nameSize(),
                        nameWidth: width - 10,
                    )
                    .frame(width: width - 10)
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
        .padding([.leading], 0)
        .padding([.trailing, .bottom], 5)
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
                    .frame(width: controlBarButtonSize, height: controlBarButtonSize)
            }
            Button {
                model.toggleShowingPanel(type: nil, panel: .settings)
            } label: {
                Image(systemName: "gearshape")
                    .frame(width: controlBarButtonSize, height: controlBarButtonSize)
                    .overlay(
                        Circle()
                            .stroke(.secondary)
                    )
                    .foregroundColor(.white)
            }
            .padding([.leading], 7)
        }
        .padding([.leading], 0)
        .padding([.trailing], 10)
        .padding([.bottom], 5)
    }
}

private struct PageView: View {
    @EnvironmentObject var model: Model
    var page: Int
    let width: Double

    var body: some View {
        ScrollView(showsIndicators: false) {
            QuickButtonsView(page: page, width: width)
        }
        .scrollDisabled(!model.database.quickButtonsGeneral.enableScroll)
        .rotationEffect(.degrees(180))
        .padding([.leading, .trailing], 0)
    }
}

private struct MainPageView: View {
    let width: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconAndSettingsView()
            PageView(page: 0, width: width)
            StreamButton()
                .padding([.top], 10)
                .frame(width: width - 10)
        }
    }
}

@available(iOS 17, *)
private struct ControlBarPageScrollTargetBehavior: ScrollTargetBehavior {
    var model: Model

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = controlBarScrollTargetBehavior(
            model: model,
            containerWidth: context.containerSize.width,
            targetPosition: target.rect.minX
        )
    }
}

private struct PagesView: View {
    @EnvironmentObject var model: Model
    var width: Double

    var body: some View {
        if #available(iOS 17, *) {
            ScrollView(.horizontal) {
                HStack {
                    Group {
                        MainPageView(width: width)
                        ForEach(1 ..< controlBarPages, id: \.self) { page in
                            if !model.buttonPairs[page].isEmpty {
                                PageView(page: page, width: width)
                            }
                        }
                    }
                    .padding([.leading], 5)
                    .containerRelativeFrame(.horizontal, count: 1, spacing: 0, alignment: .leading)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(ControlBarPageScrollTargetBehavior(model: model))
            .scrollIndicators(.never)
            .ignoresSafeArea(.all, edges: edgesToIgnore())
        } else {
            ScrollView(.horizontal) {
                MainPageView(width: width)
                    .padding([.leading], 5)
            }
            .scrollIndicators(.never)
            .ignoresSafeArea(.all, edges: edgesToIgnore())
        }
    }
}

struct ControlBarLandscapeView: View {
    @EnvironmentObject var model: Model
    @Environment(\.accessibilityShowButtonShapes)
    private var accessibilityShowButtonShapes

    private func controlBarWidth() -> Double {
        if accessibilityShowButtonShapes {
            return controlBarWidthAccessibility
        } else {
            return controlBarWidthDefault
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
        .ignoresSafeArea(.all, edges: edgesToIgnore())
    }
}
