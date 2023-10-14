import SwiftUI

struct Icon: Identifiable {
    var id: UUID = .init()
    var name: String
    var image: String
}

private let myIcons = [
    Icon(name: "Plain", image: "AppIconNoBackground"),
    Icon(name: "Halloween", image: "AppIconNoBackgroundHalloween"),
]

private let allIcons = [
    Icon(name: "Plain", image: "AppIconNoBackground"),
    Icon(name: "King", image: "AppIconNoBackgroundCrown"),
    Icon(name: "Heart", image: "AppIconNoBackgroundHeart"),
    Icon(name: "Basque", image: "AppIconNoBackgroundBasque"),
    Icon(name: "Eyebrows", image: "AppIconNoBackgroundEyes"),
    Icon(name: "Halloween", image: "AppIconNoBackgroundHalloween"),
]

struct CosmeticsSettingsView: View {
    @ObservedObject var model: Model
    @State var isPresentingBuyPopup = false

    private func getIconsInStock() -> [Icon] {
        return allIcons.filter { icon in
            !myIcons.contains(where: { myIcon in
                myIcon.image == icon.image
            })
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $model.iconImage) {
                    ForEach(myIcons) { icon in
                        HStack {
                            Text("")
                            Image(icon.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                        }
                        .tag(icon.image)
                    }
                }
                .onChange(of: model.iconImage) { iconImage in
                    model.database.iconImage = iconImage
                    model.store()
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("My icons")
            } footer: {
                Text("Icon to show in main view.")
            }
            Section {
                List {
                    ForEach(getIconsInStock()) { icon in
                        HStack {
                            Text("")
                            Image(icon.image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                            Button(action: {
                                isPresentingBuyPopup = true
                            }, label: {
                                Text("$2.00")
                            })
                            .padding([.leading], 10)
                            .alert(
                                "Store will open if/when MOBS is in AppStore",
                                isPresented: $isPresentingBuyPopup
                            ) {}
                        }
                        .tag(icon.image)
                    }
                }
            } header: {
                Text("Icons in store")
            }
        }
        .navigationTitle("Cosmetics")
    }
}
