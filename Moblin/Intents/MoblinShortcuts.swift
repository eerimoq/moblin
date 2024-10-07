import AppIntents
import IntentsUI

class MoblinShortcuts: AppShortcutsProvider {
    static var shortcutTileColor = ShortcutTileColor.navy

    static var appShortcuts: [AppShortcut] = [
        AppShortcut(intent: MuteIntent(), phrases: [
            "Mute \(.applicationName)",
        ],
        shortTitle: "Mute",
        systemImageName: "microphone.slash"),
        AppShortcut(intent: UnmuteIntent(), phrases: [
            "Unmute \(.applicationName)",
        ],
        shortTitle: "Unmute",
        systemImageName: "microphone"),
    ]
}
