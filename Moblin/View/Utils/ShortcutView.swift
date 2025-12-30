import SwiftUI

struct ShortcutSectionView<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        Section {
            content()
        } header: {
            Text("Shortcut")
        }
    }
}

struct WidgetShortcutView: View {
    let model: Model
    let database: Database
    let widget: SettingsWidget

    var body: some View {
        NavigationLink {
            WidgetSettingsView(model: model, database: database, widget: widget)
        } label: {
            Text("Widget")
        }
    }
}

struct StreamingPlatformsShortcutView: View {
    let stream: SettingsStream

    var body: some View {
        NavigationLink {
            Form {
                StreamPlatformsSettingsView(stream: stream)
            }
            .navigationTitle("Streaming platforms")
        } label: {
            Label("Streaming platforms", systemImage: "dot.radiowaves.left.and.right")
        }
    }
}
