import SwiftUI

struct WidgetSlideshowSlidePickerView: View {
    @ObservedObject var database: Database
    @ObservedObject var slide: SettingsWidgetSlideshowSlide

    private func widgets() -> [SettingsWidget] {
        database.widgets.filter { $0.type == .text || $0.type == .image }
    }

    var body: some View {
        Picker(selection: $slide.widgetId) {
            Text("-- None --")
                .tag(nil as UUID?)
            ForEach(widgets()) {
                WidgetNameView(widget: $0)
                    .tag($0.id as UUID?)
            }
        } label: {
            Text("Widget")
        }
    }
}

struct WidgetSlideshowSlideSummaryView: View {
    let model: Model
    @ObservedObject var slide: SettingsWidgetSlideshowSlide

    var body: some View {
        HStack {
            DraggableItemPrefixView()
            if let widgetId = slide.widgetId, let widget = model.findWidget(id: widgetId) {
                WidgetNameView(widget: widget)
            } else {
                Text("-- None --")
            }
            Spacer()
            Text("\(slide.time)s")
        }
    }
}

private struct SlideView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var slide: SettingsWidgetSlideshowSlide

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    WidgetSlideshowSlidePickerView(database: database, slide: slide)
                        .onChange(of: slide.widgetId) { _ in
                            model.resetSelectedScene(changeScene: false, attachCamera: false)
                        }
                    SwitcherTimePickerView(time: $slide.time)
                        .onChange(of: slide.time) { _ in
                            model.resetSelectedScene(changeScene: false, attachCamera: false)
                        }
                }
                if let widgetId = slide.widgetId, let widget = model.findWidget(id: widgetId) {
                    ShortcutSectionView {
                        WidgetShortcutView(model: model, database: database, widget: widget)
                    }
                }
            }
        } label: {
            WidgetSlideshowSlideSummaryView(model: model, slide: slide)
        }
    }
}

private struct SlidesView: View {
    let model: Model
    @ObservedObject var slideshow: SettingsWidgetSlideshow

    private func deleteSlide(at offsets: IndexSet) {
        slideshow.slides.remove(atOffsets: offsets)
        model.resetSelectedScene(changeScene: false, attachCamera: false)
    }

    var body: some View {
        Section {
            ForEach(slideshow.slides) { slide in
                SlideView(model: model, database: model.database, slide: slide)
                    .contextMenuDeleteButton {
                        if let offsets = makeOffsets(slideshow.slides, slide.id) {
                            deleteSlide(at: offsets)
                        }
                    }
            }
            .onMove { froms, to in
                slideshow.slides.move(fromOffsets: froms, toOffset: to)
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            .onDelete(perform: deleteSlide)
            AddButtonView {
                slideshow.slides.append(SettingsWidgetSlideshowSlide())
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
        } header: {
            Text("Slides")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a slide"))
        }
    }
}

struct WidgetSlideshowSettingsView: View {
    @EnvironmentObject var model: Model
    let widget: SettingsWidget

    var body: some View {
        SlidesView(model: model, slideshow: widget.slideshow)
    }
}
