import SwiftUI

struct Designer {
    var name: String
}

private let designers: [Designer] = [
    Designer(name: "Erik Moqvist"),
    Designer(name: "JohannesLiv"),
    Designer(name: "Rick9K"),
    Designer(name: "TicanUK"),
]

struct AboutDesignedBySettingsView: View {
    var body: some View {
        Form {
            ForEach(designers, id: \.name) { designer in
                Text(designer.name)
            }
        }
        .navigationTitle("Designed by")
        .toolbar {
            SettingsToolbar()
        }
    }
}
