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
    Designer(name: "CoffeeFan"),
    Designer(name: "Seebuch"),
    Designer(name: "MaurisonX"),
    Designer(name: "Recharg_ing"),
    Designer(name: "DR. GOBLIN"),
    Designer(name: "PhatMale"),
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
