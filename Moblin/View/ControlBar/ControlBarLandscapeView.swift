import SwiftUI

func controlBarScrollTargetBehavior(model: Model, containerWidth: Double, targetPosition: Double) -> Double {
    let spacing = 8.0
    let originalPagePosition = Double(model.controlBarPage - 1) * (containerWidth + spacing)
    let distance = targetPosition - originalPagePosition
    if distance > 15 {
        model.controlBarPage += 1
    } else if distance < -15 {
        model.controlBarPage -= 1
    }
    let pages = model.buttonPairs.filter { !$0.isEmpty }.count
    model.controlBarPage = model.controlBarPage.clamped(to: 1 ... pages)
    return Double(model.controlBarPage - 1) * (containerWidth + spacing)
}

private struct QuickButtonsView: View {
    @EnvironmentObject var model: Model
    var page: Int
    let width: Double

    var body: some View {
        VStack {
            ForEach(model.getQuickButtonPairs(page: page)) { pair in
                if model.database.quickButtonsGeneral.twoColumns {
                    HStack(alignment: .bottom) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                state: second,
                                size: controlBarButtonSize,
                                nameSize: controlBarQuickButtonNameSize,
                                nameWidth: controlBarButtonSize,
                            )
                        } else {
                            QuickButtonPlaceholderImage()
                        }
                        QuickButtonsInnerView(
                            state: pair.first,
                            size: controlBarButtonSize,
                            nameSize: controlBarQuickButtonNameSize,
                            nameWidth: controlBarButtonSize,
                        )
                    }
                } else {
                    if let second = pair.second {
                        QuickButtonsInnerView(
                            state: second,
                            size: controlBarQuickButtonSingleQuickButtonSize,
                            nameSize: controlBarQuickButtonNameSingleColumnSize,
                            nameWidth: width - 10,
                        )
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        state: pair.first,
                        size: controlBarQuickButtonSingleQuickButtonSize,
                        nameSize: controlBarQuickButtonNameSingleColumnSize,
                        nameWidth: width - 10,
                    )
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
        VStack(spacing: 0) {
            IconAndSettingsView()
            PageView(page: 0, width: width)
            StreamButton()
                .padding([.top], 10)
                .padding([.leading, .trailing], 5)
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
            VStack {
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
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 0)
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(ControlBarPageScrollTargetBehavior(model: model))
                .scrollIndicators(.never)
                .frame(width: width - 1)
            }
        } else {
            MainPageView(width: width)
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
    }
}
