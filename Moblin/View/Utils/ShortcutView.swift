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

struct ScenesShortcutView: View {
    let database: Database

    var body: some View {
        NavigationLink {
            ScenesSettingsView(database: database)
        } label: {
            Label("Scenes", systemImage: "photo.on.rectangle")
        }
    }
}

struct StreamingPlatformsShortcutView: View {
    let model: Model
    let stream: SettingsStream

    var body: some View {
        NavigationLink {
            Form {
                StreamPlatformsSettingsView(model: model, stream: stream)
            }
            .navigationTitle("Streaming platforms")
        } label: {
            Label("Streaming platforms", systemImage: "dot.radiowaves.left.and.right")
        }
    }
}

struct RemoteControlWebShortcutView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                RemoteControlSettingsWebView(
                    model: model,
                    web: model.database.remoteControl.web
                )
            }
            .navigationTitle("Web")
        } label: {
            Label("Remote control", systemImage: "appletvremote.gen1")
        }
    }
}

struct RemoteControlAssistantShortcutView: View {
    let model: Model

    var body: some View {
        NavigationLink {
            Form {
                RemoteControlStreamersView(
                    model: model,
                    remoteControlSettings: model.database.remoteControl
                )
            }
            .navigationTitle("Remote control assistant")
        } label: {
            Label("Remote control assistant", systemImage: "appletvremote.gen1")
        }
    }
}
