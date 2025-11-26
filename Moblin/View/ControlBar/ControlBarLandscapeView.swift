import SwiftUI

private func edgesToIgnore() -> Edge.Set {
    if isPhone() {
        return [.trailing]
    } else {
        return []
    }
}

func controlBarWidth(quickButtons: SettingsQuickButtons) -> Double {
    if quickButtons.bigButtons && quickButtons.twoColumns {
        return controlBarWidthBigQuickButtons
    } else {
        return controlBarWidthDefault
    }
}

private struct QuickButtonsView: View {
    let model: Model
    @ObservedObject var quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    let page: Int
    let width: Double

    private func buttonSize() -> Double {
        if quickButtonsSettings.bigButtons {
            return controlBarQuickButtonSingleQuickButtonSize
        } else {
            return controlBarButtonSize
        }
    }

    private func nameSize() -> Double {
        if quickButtonsSettings.bigButtons {
            return controlBarQuickButtonNameSingleColumnSize
        } else {
            return controlBarQuickButtonNameSize
        }
    }

    var body: some View {
        VStack {
            ForEach(model.getQuickButtonPairs(page: page)) { pair in
                if quickButtonsSettings.twoColumns {
                    HStack(alignment: .bottom) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                quickButtons: quickButtons,
                                quickButtonsSettings: quickButtonsSettings,
                                orientation: model.orientation,
                                state: second,
                                size: buttonSize(),
                                nameSize: nameSize(),
                                nameWidth: buttonSize()
                            )
                        } else {
                            QuickButtonPlaceholderImage(size: buttonSize())
                        }
                        QuickButtonsInnerView(
                            quickButtons: quickButtons,
                            quickButtonsSettings: quickButtonsSettings,
                            orientation: model.orientation,
                            state: pair.first,
                            size: buttonSize(),
                            nameSize: nameSize(),
                            nameWidth: buttonSize()
                        )
                    }
                } else {
                    if let second = pair.second {
                        QuickButtonsInnerView(
                            quickButtons: quickButtons,
                            quickButtonsSettings: quickButtonsSettings,
                            orientation: model.orientation,
                            state: second,
                            size: buttonSize(),
                            nameSize: nameSize(),
                            nameWidth: width - 10
                        )
                        .frame(width: width - 10)
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        quickButtons: quickButtons,
                        quickButtonsSettings: quickButtonsSettings,
                        orientation: model.orientation,
                        state: pair.first,
                        size: buttonSize(),
                        nameSize: nameSize(),
                        nameWidth: width - 10
                    )
                    .frame(width: width - 10)
                }
            }
        }
    }
}

private struct StatusView: View {
    let model: Model
    @ObservedObject var status: StatusOther
    @State var presentingThermalState: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            if isPhone() {
                BatteryView(model: model, database: model.database, battery: model.battery)
            }
            Spacer(minLength: 0)
            Button {
                presentingThermalState.toggle()
            } label: {
                ThermalStateView(thermalState: status.thermalState)
            }
            Spacer(minLength: 0)
            if isPhone() {
                Text(status.digitalClock)
                    .foregroundStyle(.white)
                    .font(smallFont)
            }
        }
        .padding([.leading, .bottom], 0)
        .padding([.trailing], 5)
        .sheet(isPresented: $presentingThermalState) {
            ThermalStateSheetView(presenting: $presentingThermalState)
        }
    }
}

private struct IconAndSettingsView: View {
    let model: Model
    @ObservedObject var cosmetics: Cosmetics

    var body: some View {
        HCenter {
            Button {
                model.toggleShowingPanel(type: nil, panel: .cosmetics)
            } label: {
                Image("\(cosmetics.iconImage)NoBackground")
                    .interpolation(.high)
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
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct PageView: View {
    let model: Model
    let quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    let page: Int
    let width: Double

    var body: some View {
        ScrollView(showsIndicators: false) {
            QuickButtonsView(model: model,
                             quickButtons: quickButtons,
                             quickButtonsSettings: quickButtonsSettings,
                             page: page,
                             width: width)
        }
        .scrollDisabled(!quickButtonsSettings.enableScroll)
        .rotationEffect(.degrees(180))
        .padding([.leading, .trailing], 0)
    }
}

private struct MainPageView: View {
    let model: Model
    let quickButtons: QuickButtons
    let quickButtonsSettings: SettingsQuickButtons
    let cosmetics: Cosmetics
    let width: Double

    private func buttonsWidth() -> Double {
        if quickButtonsSettings.bigButtons && quickButtonsSettings.twoColumns {
            return width - 20
        } else {
            return width - 10
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            IconAndSettingsView(model: model, cosmetics: cosmetics)
                .padding([.top, .bottom], 2)
                .frame(width: buttonsWidth())
            PageView(model: model,
                     quickButtons: quickButtons,
                     quickButtonsSettings: quickButtonsSettings,
                     page: 0,
                     width: width)
            HStack {
                Spacer(minLength: 0)
                StreamButton()
                    .padding([.top], 5)
                Spacer(minLength: 0)
            }
            .frame(width: buttonsWidth())
        }
    }
}

@available(iOS 17, *)
private struct ControlBarPageScrollTargetBehavior: ScrollTargetBehavior {
    let model: Model

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.x = controlBarScrollTargetBehavior(
            model: model,
            containerWidth: context.containerSize.width,
            targetPosition: target.rect.minX
        )
    }
}

private struct PagesView: View {
    let model: Model
    @ObservedObject var quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    let width: Double

    var body: some View {
        if #available(iOS 17, *) {
            ScrollView(.horizontal) {
                HStack {
                    Group {
                        MainPageView(model: model,
                                     quickButtons: quickButtons,
                                     quickButtonsSettings: quickButtonsSettings,
                                     cosmetics: model.cosmetics,
                                     width: width)
                        ForEach(1 ..< controlBarPages, id: \.self) { page in
                            if !quickButtons.pairs[page].isEmpty {
                                PageView(model: model,
                                         quickButtons: quickButtons,
                                         quickButtonsSettings: quickButtonsSettings,
                                         page: page,
                                         width: width)
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
                MainPageView(model: model,
                             quickButtons: quickButtons,
                             quickButtonsSettings: quickButtonsSettings,
                             cosmetics: model.cosmetics,
                             width: width)
                    .padding([.leading], 5)
            }
            .scrollIndicators(.never)
            .ignoresSafeArea(.all, edges: edgesToIgnore())
        }
    }
}

struct ControlBarLandscapeView: View {
    let model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                if !isPhone() {
                    Spacer(minLength: 0)
                }
                StatusView(model: model, status: model.statusOther)
                    .frame(width: controlBarWidthDefault)
                Spacer(minLength: 0)
            }
            PagesView(model: model,
                      quickButtons: model.quickButtons,
                      quickButtonsSettings: quickButtons,
                      width: controlBarWidth(quickButtons: quickButtons))
        }
        .padding([.top, .bottom], 0)
        .frame(width: controlBarWidth(quickButtons: quickButtons))
        .background(.black)
        .ignoresSafeArea(.all, edges: edgesToIgnore())
    }
}
