import SwiftUI

@available(iOS 17, *)
private struct ControlBarPageScrollTargetBehavior: ScrollTargetBehavior {
    let model: Model

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        target.rect.origin.y = controlBarScrollTargetBehavior(
            model: model,
            containerWidth: context.containerSize.height,
            targetPosition: target.rect.minY
        )
    }
}

private struct QuickButtonsView: View {
    let model: Model
    @ObservedObject var quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    let page: Int
    let height: Double

    private func buttonSize() -> Double {
        if quickButtonsSettings.bigButtons {
            return controlBarQuickButtonSingleQuickButtonSize
        } else {
            return controlBarButtonSize
        }
    }

    var body: some View {
        HStack {
            ForEach(model.getQuickButtonPairs(page: page)) { pair in
                if quickButtonsSettings.twoColumns {
                    VStack(alignment: .leading) {
                        if let second = pair.second {
                            QuickButtonsInnerView(
                                quickButtons: quickButtons,
                                quickButtonsSettings: quickButtonsSettings,
                                orientation: model.orientation,
                                state: second,
                                size: buttonSize(),
                                nameSize: buttonSize(),
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
                            nameSize: buttonSize(),
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
                            nameSize: buttonSize(),
                            nameWidth: buttonSize()
                        )
                        .frame(height: height - 10)
                    } else {
                        EmptyView()
                    }
                    QuickButtonsInnerView(
                        quickButtons: quickButtons,
                        quickButtonsSettings: quickButtonsSettings,
                        orientation: model.orientation,
                        state: pair.first,
                        size: buttonSize(),
                        nameSize: buttonSize(),
                        nameWidth: buttonSize()
                    )
                    .frame(height: height - 10)
                }
            }
        }
    }
}

private struct PageView: View {
    let model: Model
    let quickButtons: QuickButtons
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    var page: Int
    var height: Double

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            QuickButtonsView(model: model,
                             quickButtons: quickButtons,
                             quickButtonsSettings: quickButtonsSettings,
                             page: page,
                             height: height)
        }
        .scrollDisabled(!quickButtonsSettings.enableScroll)
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
                    .interpolation(.high)
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
                    .foregroundStyle(.white)
            }
            .padding([.leading], 10)
        }
        .padding([.leading, .trailing], 10)
    }
}

private struct MainPageView: View {
    let model: Model
    let quickButtons: QuickButtons
    let quickButtonsSettings: SettingsQuickButtons
    @ObservedObject var status: StatusOther
    var height: Double
    @State var presentingThermalState: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            PageView(model: model,
                     quickButtons: quickButtons,
                     quickButtonsSettings: quickButtonsSettings,
                     page: 0,
                     height: height)
                .padding([.top, .leading], 5)
                .padding([.trailing], 0)
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Button {
                        presentingThermalState.toggle()
                    } label: {
                        ThermalStateView(thermalState: status.thermalState)
                    }
                    Spacer(minLength: 0)
                }
                .padding([.top], 3)
                .padding([.trailing], 5)
                .padding([.leading], 0)
                IconAndSettingsView(cosmetics: model.cosmetics)
                StreamButton()
                    .padding([.top], 10)
                    .padding([.leading, .trailing], 5)
            }
            .padding([.leading], 0)
            .frame(width: controlBarWidthDefault)
            .sheet(isPresented: $presentingThermalState) {
                ThermalStateSheetView(presenting: $presentingThermalState)
            }
        }
    }
}

private struct PagesView: View {
    let model: Model
    @ObservedObject var quickButtons: QuickButtons
    let quickButtonsSettings: SettingsQuickButtons
    var height: Double

    var body: some View {
        if #available(iOS 17, *) {
            ScrollView(.vertical) {
                LazyVStack {
                    Group {
                        MainPageView(model: model,
                                     quickButtons: quickButtons,
                                     quickButtonsSettings: quickButtonsSettings,
                                     status: model.statusOther,
                                     height: height)
                        ForEach(1 ..< controlBarPages, id: \.self) { page in
                            if !quickButtons.pairs[page].isEmpty {
                                PageView(model: model,
                                         quickButtons: quickButtons,
                                         quickButtonsSettings: quickButtonsSettings,
                                         page: page,
                                         height: height)
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
                MainPageView(model: model,
                             quickButtons: quickButtons,
                             quickButtonsSettings: quickButtonsSettings,
                             status: model.statusOther,
                             height: height)
            }
            .scrollIndicators(.never)
            .ignoresSafeArea(.all, edges: [.bottom])
        }
    }
}

struct ControlBarPortraitView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var quickButtons: SettingsQuickButtons

    private func controlBarHeight() -> CGFloat {
        return controlBarWidthDefault
    }

    var body: some View {
        PagesView(model: model,
                  quickButtons: model.quickButtons,
                  quickButtonsSettings: model.database.quickButtonsGeneral,
                  height: controlBarWidth(quickButtons: quickButtons))
            .frame(height: controlBarWidth(quickButtons: quickButtons))
            .background(.black)
    }
}
