import SwiftUI

struct ChatBotSettingsView: View {
    var body: some View {
        Form {
            Section {
                Text("""
                Only configured Twitch and Kick channel names and Twitch mods are \
                allowed to execute commands.
                """)
            }
            Section {
                Text("!moblin tts on")
            } footer: {
                Text("Turn on chat text to speech.")
            }
            Section {
                Text("!moblin tts off")
            } footer: {
                Text("Turn off chat text to speech.")
            }
            Section {
                Text("!moblin obs fix")
            } footer: {
                Text("Fix OBS input.")
            }
            Section {
                Text("!moblin map zoom out")
            } footer: {
                Text("Zoom out map widget temporarily.")
            }
        }
        .navigationTitle("Bot")
        .toolbar {
            SettingsToolbar()
        }
    }
}
