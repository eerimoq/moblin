import SwiftUI

private let platforms = ["twitch", "kick", "custom"]

private func platformName(platform: String) -> String {
    switch platform {
    case "twitch":
        String(localized: "Twitch")
    case "kick":
        String(localized: "Kick")
    default:
        String(localized: "Custom")
    }
}

private struct DoinkAddTargetView: View {
    let add: (String, String, String, String) -> Void
    @State private var name = ""
    @State private var platform = "twitch"
    @State private var url = ""
    @State private var key = ""
    @Environment(\.dismiss) var dismiss

    private func addDisabled() -> Bool {
        key.trim().isEmpty || (platform == "custom" && url.trim().isEmpty)
    }

    var body: some View {
        Form {
            Section {
                TextField("", text: $name)
                    .disableAutocorrection(true)
            } header: {
                Text("Name")
            }
            Section {
                Picker("Platform", selection: $platform) {
                    ForEach(platforms, id: \.self) {
                        Text(platformName(platform: $0))
                    }
                }
            }
            if platform == "custom" {
                Section {
                    TextField(String("rtmp://foobar.org:3321/app"), text: $url)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                } header: {
                    Text("URL")
                }
            }
            Section {
                TextField("", text: $key)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } header: {
                Text("Stream key")
            }
            Section {
                TextButtonView("Add") {
                    add(name.trim(), platform, url.trim(), key.trim())
                    dismiss()
                }
                .disabled(addDisabled())
            }
        }
        .navigationTitle("Add destination")
    }
}

struct DoinkTargetsView: View {
    let api: DoinkApi
    let targets: [DoinkApiTarget]
    let targetLimit: Int
    let onComplete: (DoinkApiResult<DoinkApiOk>) -> Void

    var body: some View {
        Section {
            List {
                ForEach(targets, id: \.target_id) { target in
                    Toggle(isOn: Binding(get: {
                        target.enabled != 0
                    }, set: {
                        api.setTargetEnabled(targetId: target.target_id, enabled: $0, onComplete: onComplete)
                    })) {
                        VStack(alignment: .leading) {
                            Text(target.name ?? platformName(platform: target.platform))
                            Text(target.rtmp_url)
                                .font(.footnote)
                                .foregroundStyle(.gray)
                        }
                    }
                }
                .onDelete { offsets in
                    for offset in offsets {
                        api.deleteTarget(targetId: targets[offset].target_id, onComplete: onComplete)
                    }
                }
            }
            if targets.count < targetLimit {
                NavigationLink {
                    DoinkAddTargetView { name, platform, url, key in
                        api.addTarget(
                            name: name,
                            platform: platform,
                            url: url,
                            key: key,
                            onComplete: onComplete
                        )
                    }
                } label: {
                    Text("Add destination")
                }
            }
        } header: {
            Text("Multi streaming")
        } footer: {
            SwipeLeftToDeleteHelpView(kind: String(localized: "a destination"))
        }
    }
}
