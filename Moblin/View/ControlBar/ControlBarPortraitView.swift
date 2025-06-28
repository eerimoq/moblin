import SwiftUI

@available(iOS 17, *)
private struct ControlBarPageScrollTargetBehavior: ScrollTargetBehavior {
    var model: Model

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = controlBarScrollTargetBehavior(
            model: model,
            containerWidth: context.containerSize.height,
            targetPosition: target.rect.minY
        )
    }
}

private struct QuickButtonsView: View {
    @EnvironmentObject var model: Model
    var page: Int
    var height: Double

    private func buttonSize() -> Double {
        if model.database.quickButtonsGeneral.bigButtons {
            return controlBarQuickButtonSingleQuickButtonSize
        } else {
            return controlBarButtonSize
        }
    }

    var body: some View {
        HStack {
            ForEach(model.getQuickButtonPairs(page: page)) { pair in
                if model.database.quickButtonsGeneral.twoColumns {
                    VStack(alignment: .leading) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                state: second,
                                size: buttonSize(),
                                nameSize: buttonSize(),
                                nameWidth: buttonSize(),
                            )
                        } else {
                            QuickButtonPlaceholderImage(size: buttonSize())
                        }
                        QuickButtonsInnerView(
                            state: pair.first,
                            size: buttonSize(),
                            nameSize: buttonSize(),
                            nameWidth: buttonSize(),
                        )
                    }
                } else {
                    if let second = pair.second {
                        QuickButtonsInnerView(
                            state: second,
                            size: buttonSize(),
                            nameSize: buttonSize(),
                            nameWidth: buttonSize(),
                        )
                        .frame(height: height - 10)
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        state: pair.first,
                        size: buttonSize(),
                        nameSize: buttonSize(),
                        nameWidth: buttonSize(),
                    )
                    .frame(height: height - 10)
                }
            }
        }
    }
}

private struct PageView: View {
    @EnvironmentObject var model: Model
    var page: Int
    var height: Double

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            QuickButtonsView(page: page, height: height)
        }
        .scrollDisabled(!model.database.quickButtonsGeneral.enableScroll)
        .rotationEffect(.degrees(180))
    }
}

private struct IconAndSettingsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var cosmetics: Cosmetics

    var body: some View {
        HStack(spacing: 0) {
            Button {
                model.toggleShowingPanel(type: nil, panel: .cosmetics)
            } label: {
                Image("\(cosmetics.iconImage)NoBackground")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding([.bottom], 4)
                    .offset(x: 2)
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
            .padding([.leading], 10)
        }
        .padding([.leading, .trailing], 10)
    }
}

private struct MainPageView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var status: Status
    var height: Double

    var body: some View {
        HStack(spacing: 0) {
            PageView(page: 0, height: height)
                .padding([.top, .leading], 5)
                .padding([.trailing], 0)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    ThermalStateView(thermalState: status.thermalState)
                    Spacer(minLength: 0)
                }
                .padding([.bottom, .trailing], 5)
                .padding([.leading], 0)
                IconAndSettingsView(cosmetics: model.cosmetics)
                StreamButton(createStreamWizard: model.createStreamWizard)
                    .padding([.top], 10)
                    .padding([.leading, .trailing], 5)
            }
            .padding([.leading], 0)
            .frame(width: height)
        }
    }
}

private struct PagesView: View {
    @EnvironmentObject var model: Model
    var height: Double

    var body: some View {
        if #available(iOS 17, *) {
            ScrollView(.vertical) {
                LazyVStack {
                    Group {
                        MainPageView(status: model.status, height: height)
                        ForEach(1 ..< controlBarPages, id: \.self) { page in
                            if !model.buttonPairs[page].isEmpty {
                                PageView(page: page, height: height)
                                    .padding([.top, .leading, .trailing], 5)
                            }
                        }
                    }
                    .containerRelativeFrame(.vertical, count: 1, spacing: 0, alignment: .top)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(ControlBarPageScrollTargetBehavior(model: model))
            .scrollIndicators(.never)
            .ignoresSafeArea(.all, edges: [.bottom])
        } else {
            ScrollView(.vertical) {
                MainPageView(status: model.status, height: height)
            }
            .scrollIndicators(.never)
            .ignoresSafeArea(.all, edges: [.bottom])
        }
    }
}

struct ControlBarPortraitView: View {
    @EnvironmentObject var model: Model
    @Environment(\.accessibilityShowButtonShapes)
    private var accessibilityShowButtonShapes

    private func controlBarHeight() -> CGFloat {
        if accessibilityShowButtonShapes {
            return controlBarWidthAccessibility
        } else {
            return controlBarWidthDefault
        }
    }

    var body: some View {
        PagesView(height: controlBarHeight())
            .frame(height: controlBarHeight())
            .background(.black)
    }
}
