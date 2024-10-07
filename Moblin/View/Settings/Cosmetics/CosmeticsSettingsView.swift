import SwiftUI

private struct CosmeticsSettingsRestoreView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            Button {
                Task {
                    await model.updateProductFromAppStore()
                }
            } label: {
                HStack {
                    Spacer()
                    Text("Restore purchases")
                    Spacer()
                }
            }
        }
    }
}

private struct CosmeticsSettingsBoughtEverythingView: View {
    var body: some View {
        Section {
            HStack {
                Text("You already bought everything!")
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
            }
        } header: {
            Text("Icons in store")
        } footer: {
            Text("Many thanks from the Moblin developers!")
        }
    }
}

private struct CosmeticsSettingsIconsInStoreView: View {
    @EnvironmentObject var model: Model
    @State var disabledPurchaseButtons: Set<String> = []

    var body: some View {
        Section {
            List {
                ForEach(model.iconsInStore) { icon in
                    HStack {
                        Text("")
                        Image(icon.imageNoBackground())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: buttonSize, height: buttonSize)
                        Spacer()
                        Text(icon.name)
                        ZStack {
                            Button(action: {
                                disabledPurchaseButtons.insert(icon.id)
                                disabledPurchaseButtons = disabledPurchaseButtons
                                Task {
                                    do {
                                        try await model.purchaseProduct(id: icon.id)
                                    } catch {
                                        logger
                                            .info(
                                                "cosmetics: Purchase failed with error \(error)"
                                            )
                                    }
                                    disabledPurchaseButtons.remove(icon.id)
                                    disabledPurchaseButtons = disabledPurchaseButtons
                                }
                            }, label: {
                                Text(icon.price)
                            })
                            .padding([.leading], 10)
                            .disabled(disabledPurchaseButtons.contains(icon.id))
                            .opacity(disabledPurchaseButtons.contains(icon.id) ? 0.0 : 1.0)
                            if disabledPurchaseButtons.contains(icon.id) {
                                ProgressView().padding([.leading], 10)
                            }
                        }
                    }
                    .tag(icon.image())
                }
            }
        } header: {
            Text("Icons in store")
        }
    }
}

private struct CosmeticsSettingsMyIconsView: View {
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
        Section {
            Picker("", selection: $model.iconImage) {
                ForEach(model.myIcons) { icon in
                    HStack {
                        Text("")
                        Image(icon.imageNoBackground())
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: buttonSize, height: buttonSize)
                        Spacer()
                        Text(icon.name)
                    }
                    .tag(icon.image())
                }
            }
            .onChange(of: model.iconImage) { iconImage in
                model.database.iconImage = iconImage
                setAppIcon(iconImage: iconImage)
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } header: {
            Text("My icons")
        } footer: {
            Text("Displayed in main view and as app icon.")
        }
    }
}

struct CosmeticsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var disabledPurchaseButtons: Set<String> = []

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Support Moblin developers by buying icons.")
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                }
            }
            CosmeticsSettingsMyIconsView()
            if !model.iconsInStore.isEmpty {
                CosmeticsSettingsIconsInStoreView()
            } else {
                CosmeticsSettingsBoughtEverythingView()
            }
            CosmeticsSettingsRestoreView()
        }
        .navigationTitle("Cosmetics")
    }
}
