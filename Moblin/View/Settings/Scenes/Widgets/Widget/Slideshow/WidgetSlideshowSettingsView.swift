import SwiftUI

private struct SlideView: View {
    let model: Model
    @ObservedObject var database: Database
    @ObservedObject var slide: SettingsWidgetSlideshowSlide

    private func getWidgetName(widgetId: UUID?) -> String {
        if let widgetId {
            return model.getWidgetName(id: widgetId)
        } else {
            return String(localized: "-- None --")
        }
    }

    private func widgets() -> [SettingsWidget] {
        return database.widgets.filter { $0.type == .text }
    }

    var body: some View {
        NavigationLink {
            Form {
                Section {
                    Picker(selection: $slide.widgetId) {
                        Text("-- None --")
                            .tag(nil as UUID?)
                        ForEach(widgets()) {
                            Text($0.name)
                                .tag($0.id as UUID?)
                        }
                    } label: {
                        Text("Widget")
                    }
                    .onChange(of: slide.widgetId) { _ in
                        model.resetSelectedScene(changeScene: false, attachCamera: false)
                    }
                    SwitcherTimePickerView(time: $slide.time)
                        .onChange(of: slide.time) { _ in
                            model.resetSelectedScene(changeScene: false, attachCamera: false)
                        }
                }
                if let widgetId = slide.widgetId, let widget = model.findWidget(id: widgetId) {
                    Section {
                        NavigationLink {
                            WidgetSettingsView(database: database, widget: widget)
                        } label: {
                            Text("Widget")
                        }
                    } header: {
                        Text("Shortcut")
                    }
                }
            }
        } label: {
            HStack {
                DraggableItemPrefixView()
                Text(getWidgetName(widgetId: slide.widgetId))
                Spacer()
                Text("\(slide.time)s")
            }
        }
    }
}

private struct SlidesView: View {
    let model: Model
    @ObservedObject var slideshow: SettingsWidgetSlideshow

    var body: some View {
        Section {
            ForEach(slideshow.slides) {
                SlideView(model: model, database: model.database, slide: $0)
            }
            .onMove { froms, to in
                slideshow.slides.move(fromOffsets: froms, toOffset: to)
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
            .onDelete { offsets in
                slideshow.slides.remove(atOffsets: offsets)
                model.resetSelectedScene(changeScene: false, attachCamera: false)
            }
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
