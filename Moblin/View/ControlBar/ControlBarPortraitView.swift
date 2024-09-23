import SwiftUI

private struct ButtonsPortraitView: View {
    @EnvironmentObject var model: Model
    var width: CGFloat

    var body: some View {
        HStack {
            ForEach(model.buttonPairs) { pair in
                if model.database.quickButtons!.twoColumns {
                    VStack(alignment: .leading) {
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
                                    reader.scrollTo(id, anchor: .trailing)
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
                    Spacer(minLength: 0)
                    ThermalStateView(thermalState: model.thermalState)
                    Spacer(minLength: 0)
                }
                .padding([.bottom], 5)
                .padding([.leading], 0)
                .padding([.trailing], 5)
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
                StreamButton()
                    .padding([.top], 10)
                    .padding([.leading, .trailing], 5)
            }
            .frame(width: controlBarHeight())
        }
        .padding([.top], 10)
        .padding([.bottom], 0)
        .frame(height: controlBarHeight())
        .background(.black)
    }
}
