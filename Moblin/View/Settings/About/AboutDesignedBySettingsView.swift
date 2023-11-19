import SwiftUI

struct Designer {
    var name: String
}

private let designers = [
    Designer(name: "Erik Moqvist"),
    Designer(name: "JohannesLiv"),
    Designer(name: "Rick9K"),
    Designer(name: "adriportela95"),
    Designer(name: "megahallon"),
    Designer(name: "TicanUK"),
]

struct AboutDesignedBySettingsView: View {
    var body: some View {
        Form {
            Section {
                ForEach(designers, id: \.name) { designer in
                    Text(designer.name)
                }
            } footer: {
                Text("""
                An incomplete list of people who has contributed ideas, programming,
                testing, promotion and more.
                """)
            }
        }
        .navigationTitle("Designed by")
        .toolbar {
            SettingsToolbar()
        }
    }
}
