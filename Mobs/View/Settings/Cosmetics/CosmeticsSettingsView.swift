import SwiftUI

struct CosmeticsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var isPresentingBuyPopup = false

    private func setAppIcon(iconImage: String) {
        var iconImage: String? = iconImage
        if iconImage == "AppIcon" {
            iconImage = nil
        }
        UIApplication.shared.setAlternateIconName(iconImage) { error in
            if let error {
                logger.error("Failed to change app icon with error \(error)")
            }
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("", selection: $model.iconImage) {
                    ForEach(model.getMyIcons()) { icon in
                        HStack {
                            Text("")
                            Image(icon.imageNoBackground())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                        }
                        .tag(icon.image())
                    }
                }
                .onChange(of: model.iconImage) { iconImage in
                    model.database.iconImage = iconImage
                    model.store()
                    setAppIcon(iconImage: iconImage)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text("My icons")
            } footer: {
                Text("Displayed in main view and as app icon.")
            }
            Section {
                List {
                    ForEach(model.getIconsInStore()) { icon in
                        HStack {
                            Text("")
                            Image(icon.imageNoBackground())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                            Button(action: {
                                isPresentingBuyPopup = true
                            }, label: {
                                Text(icon.price)
                            })
                            .padding([.leading], 10)
                            .alert(
                                "The store is closed",
                                isPresented: $isPresentingBuyPopup
                            ) {}
                        }
                        .tag(icon.image())
                    }
                }
            } header: {
                Text("Icons in store")
            } footer: {
                Text("Support MOBS developers by buying icons.")
            }
            Section {
                List {
                    ForEach(model.getIconsNotYetInStore()) { icon in
                        HStack {
                            Text("")
                            Image(icon.imageNoBackground())
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 40, height: 40)
                            Spacer()
                            Text(icon.name)
                            Text(icon.price)
                                .padding([.leading], 10)
                        }
                        .tag(icon.image())
                    }
                }
            } header: {
                Text("Icons not yet in store")
            }
        }
        .navigationTitle("Cosmetics")
    }
}
