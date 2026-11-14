import SwiftUI

private struct FilterTextFieldView: View {
    let model: Model
    @ObservedObject var quickButtonsFilter: QuickButtonsFilter
    @FocusState private var focused: Bool

    var body: some View {
        TextField("Filter", text: $quickButtonsFilter.filter)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textFieldStyle(.roundedBorder)
            .focused($focused)
            .onAppear {
                focused = true
            }
            .onChange(of: quickButtonsFilter.filter) { _ in
                model.updateFilteredQuickButtonPairs()
            }
            .onChange(of: focused) { focused in
                if !focused {
                    model.quickButtonsFilterFocusLost()
                }
            }
    }
}

private struct QuickButtonsFilterView: View {
    let model: Model
    @ObservedObject var quickButtonsFilter: QuickButtonsFilter
    @ObservedObject var quickButtonsSettings: SettingsQuickButtons
    @ObservedObject var orientation: Orientation

    var body: some View {
        if orientation.isPortrait {
            HStack(alignment: .top, spacing: 0) {
                ControlBarPortraitPageView(model: model,
                                           quickButtons: model.quickButtons,
                                           quickButtonsSettings: quickButtonsSettings,
                                           pairs: quickButtonsFilter.pairs,
                                           height: controlBarWidth(quickButtons: quickButtonsSettings))
                    .padding([.top, .leading], 5)
                FilterTextFieldView(model: model, quickButtonsFilter: quickButtonsFilter)
                    .padding(.top, 3)
                    .padding(.horizontal, 5)
                    .frame(width: controlBarWidthDefault)
            }
        } else {
            VStack(spacing: 0) {
                ControlBarLandscapePageView(model: model,
                                            quickButtons: model.quickButtons,
                                            quickButtonsSettings: quickButtonsSettings,
                                            pairs: quickButtonsFilter.pairs,
                                            width: controlBarWidth(quickButtons: quickButtonsSettings))
                    .padding(.leading, 5)
                FilterTextFieldView(model: model, quickButtonsFilter: quickButtonsFilter)
                    .padding(5)
            }
        }
    }
}

private struct QuickButtonsFilterOverlayView: View {
    let model: Model
    @ObservedObject var quickButtonsFilter: QuickButtonsFilter

    var body: some View {
        if quickButtonsFilter.filtering {
            QuickButtonsFilterView(model: model,
                                   quickButtonsFilter: quickButtonsFilter,
                                   quickButtonsSettings: model.database.quickButtonsGeneral,
                                   orientation: model.orientation)
                .background {
                    ControlBarBackgroundView(controlBar: model.controlBar)
                }
                .contentShape(Rectangle())
        }
    }
}

extension View {
    func controlBarDoubleTapArea(model: Model) -> some View {
        background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    model.startFilteringQuickButtons()
                }
        }
    }

    func controlBarFilter(model: Model) -> some View {
        background {
            ControlBarBackgroundView(controlBar: model.controlBar)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture(count: 2) {
                    model.startFilteringQuickButtons()
                }
        }
        .overlay {
            QuickButtonsFilterOverlayView(model: model, quickButtonsFilter: model.quickButtonsFilter)
        }
    }
}

@available(iOS 18, *)
private struct FilterOnOverscrollModifier: ViewModifier {
    let model: Model
    let axis: Axis
    @State private var interacting = false

    private func overscroll(geometry: ScrollGeometry) -> CGFloat {
        switch axis {
        case .vertical:
            geometry.visibleRect.maxY - geometry.contentSize.height
        case .horizontal:
            geometry.visibleRect.maxX - geometry.contentSize.width
        }
    }

    func body(content: Content) -> some View {
        content
            .onScrollPhaseChange { _, phase in
                interacting = phase == .interacting
            }
            .onScrollGeometryChange(for: Bool.self) { geometry in
                overscroll(geometry: geometry) > 50
            } action: { _, overscrolled in
                if overscrolled, interacting {
                    model.startFilteringQuickButtons()
                }
            }
    }
}

extension View {
    @ViewBuilder
    func filterQuickButtonsOnOverscroll(model: Model, axis: Axis) -> some View {
        if #available(iOS 18, *) {
            modifier(FilterOnOverscrollModifier(model: model, axis: axis))
        } else {
            self
        }
    }
}
