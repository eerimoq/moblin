import SwiftUI

struct HelpAndSupportSettingsView: View {
    func openGithub() {
        UIApplication.shared.open(URL(string: "https://github.com/eerimoq/mobs")!)
    }
    
    func openDiscord() {
        UIApplication.shared.open(URL(string: "https://discord.gg/kRCXKuRu")!)
    }
    
    var body: some View {
        Form {
            Section {
                Button(action: {
                    openDiscord()
                }, label: {
                    Text("Discord")
                })
                Button(action: {
                    openGithub()
                }, label: {
                    Text("Github")
                })
            }
        }
        .navigationTitle("Help & support")
    }
}

