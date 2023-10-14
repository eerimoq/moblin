import SwiftUI

struct Icon: Identifiable {
    var id: UUID = .init()
    var name: String
    var image: String
}

let plainIcon = Icon(name: "Plain", image: "AppIconNoBackground")

private let myIcons = [
    plainIcon,
    Icon(name: "Halloween", image: "AppIconNoBackgroundHalloween"),
]

func isInMyIcons(image: String) -> Bool {
    return myIcons.contains(where: { icon in
        icon.image == image
    })
}

private let allIcons = [
    plainIcon,
    Icon(name: "King", image: "AppIconNoBackgroundCrown"),
    Icon(name: "Heart", image: "AppIconNoBackgroundHeart"),
    Icon(name: "Basque", image: "AppIconNoBackgroundBasque"),
    Icon(name: "Looking", image: "AppIconNoBackgroundLooking"),
    Icon(name: "Halloween", image: "AppIconNoBackgroundHalloween"),
    Icon(name: "Eyebrows", image: "AppIconNoBackgroundEyes"),
    Icon(name: "South Korea", image: "AppIconNoBackgroundSouthKorea"),
    Icon(name: "China", image: "AppIconNoBackgroundChina"),
    Icon(name: "Sweden", image: "AppIconNoBackgroundSweden"),
    Icon(name: "United States", image: "AppIconNoBackgroundUnitedStates"),
]

struct CosmeticsSettingsView: View {
    @ObservedObject var model: Model
    @State var isPresentingBuyPopup = false

    private func getIconsInStock() -> [Icon] {
        return allIcons.filter { icon in
            !isInMyIcons(image: icon.image)
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
                                "The store is closed",
                                isPresented: $isPresentingBuyPopup
                            ) {}
                        }
                        .tag(icon.image)
                    }
                }
            } header: {
                Text("Icons in store")
            } footer: {
                Text("Support MOBS developers by buying icons.")
            }
        }
        .navigationTitle("Cosmetics")
    }
}
