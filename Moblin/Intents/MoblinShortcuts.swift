import AppIntents
import IntentsUI

class MoblinShortcuts: AppShortcutsProvider {
    static var shortcutTileColor = ShortcutTileColor.navy

    static var appShortcuts: [AppShortcut] = [
        AppShortcut(intent: MuteIntent(), phrases: [
            "\(.applicationName), mute",
        ],
        shortTitle: "Mute",
        systemImageName: "microphone.slash"),
        AppShortcut(intent: UnmuteIntent(), phrases: [
            "\(.applicationName), unmute",
        ],
        shortTitle: "Unmute",
        systemImageName: "microphone"),
        AppShortcut(intent: SnapshotIntent(), phrases: [
            "\(.applicationName), take snapshot",
        ],
        shortTitle: "Take snapshot",
        systemImageName: "microphone"),
    ]
}
