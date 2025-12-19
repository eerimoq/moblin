import SwiftUI

private struct SlideView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var slide: SettingsWidgetSlideshowSlide
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        NavigationLink {
            Form {
                WidgetSlideshowSlidePickerView(database: database, slide: slide)
                SwitcherTimePickerView(time: $slide.time)
            }
            .toolbar {
                CloseToolbar(presenting: $presentingCreateWizard)
            }
        } label: {
            WidgetSlideshowSlideSummaryView(model: model, slide: slide)
        }
    }
}

private struct SlidesView: View {
    let model: Model
    @ObservedObject var slideshow: SettingsWidgetSlideshow
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Section {
            ForEach(slideshow.slides) {
                SlideView(model: model,
                          database: model.database,
                          slide: $0,
                          presentingCreateWizard: $presentingCreateWizard)
            }
            .onMove { froms, to in
                slideshow.slides.move(fromOffsets: froms, toOffset: to)
            }
            .onDelete { offsets in
                slideshow.slides.remove(atOffsets: offsets)
            }
            AddButtonView {
                slideshow.slides.append(SettingsWidgetSlideshowSlide())
            }
        } header: {
            Text("Slides")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a slide"))
        }
    }
}

struct WidgetWizardSlideshowSettingsView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var createWidgetWizard: CreateWidgetWizard
    @ObservedObject var slideshow: SettingsWidgetSlideshow
    @Binding var presentingCreateWizard: Bool

    var body: some View {
        Form {
            SlidesView(model: model, slideshow: slideshow, presentingCreateWizard: $presentingCreateWizard)
            WidgetWizardSelectScenesNavigationView(model: model,
                                                   database: database,
                                                   createWidgetWizard: createWidgetWizard,
                                                   presentingCreateWizard: $presentingCreateWizard)
                .disabled(slideshow.slides.isEmpty)
        }
        .navigationTitle(basicWidgetSettingsTitle(createWidgetWizard))
        .toolbar {
            CloseToolbar(presenting: $presentingCreateWizard)
        }
    }
}
