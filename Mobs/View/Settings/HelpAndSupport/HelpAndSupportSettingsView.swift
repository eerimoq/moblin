import SwiftUI

struct HelpAndSupportSettingsView: View {
    func openUrl(url: String) {
        UIApplication.shared.open(URL(string: url)!)
    }
    
    var body: some View {
        Form {
            Section {
                Button(action: {
                    openUrl(url: "https://discord.gg/nt3UwHqbMM")
                }, label: {
                    Text("Discord")
                })
                Button(action: {
                    openUrl(url: "https://github.com/eerimoq/mobs")
                }, label: {
                    Text("Github")
                })
            }
        }
        .navigationTitle("Help & support")
    }
}

