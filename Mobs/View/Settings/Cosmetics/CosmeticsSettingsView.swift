import SwiftUI

struct CosmeticsSettingsView: View {
    @EnvironmentObject var model: Model

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
                    ForEach(model.myIcons) { icon in
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
                if model.iconsInStore.count > 0 {
                    List {
                        ForEach(model.iconsInStore) { icon in
                            HStack {
                                Text("")
                                Image(icon.imageNoBackground())
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 40, height: 40)
                                Spacer()
                                Text(icon.name)
                                Button(action: {
                                    Task {
                                        do {
                                            try await model.buyIcon(id: icon.id)
                                        } catch {
                                            logger.info("Buy failed with error \(error)")
                                        }
                                    }
                                }, label: {
                                    Text(icon.price)
                                })
                                .padding([.leading], 10)
                            }
                            .tag(icon.image())
                        }
                    }
                } else {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                        Text("You already bought everything!")
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                    }
                }
            } header: {
                Text("Icons in store")
            } footer: {
                Text("Support MOBS developers by buying icons.")
            }
            Section {
                List {
                    ForEach(model.iconsNotYetInStore) { icon in
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
            } header: {
                Text("Icons not yet in store")
            }
        }
        .navigationTitle("Cosmetics")
    }
}
