import SwiftUI

private struct StoreSettingsRestoreView: View {
    @EnvironmentObject var model: Model

    var body: some View {
        Section {
            TextButtonView("Restore purchases") {
                Task {
                    await model.updateProductFromAppStore()
                }
            }
        }
    }
}

private struct StoreSettingsBoughtEverythingView: View {
    var body: some View {
        Section {
            Text("You already bought everything! ❤️")
        } header: {
            Text("Icons to buy")
        } footer: {
            Text("Many thanks from the Moblin developers!")
        }
    }
}

private struct StoreSettingsIconsToBuyView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var store: Store
    @State var disabledPurchaseButtons: Set<String> = []

    var body: some View {
        Section {
            List {
                ForEach(store.iconsInStore) { icon in
                    HStack {
                        Text("")
                        Image(icon.imageNoBackground())
                            .interpolation(.high)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: controlBarButtonSize, height: controlBarButtonSize)
                        Spacer()
                        Text(icon.name)
                        ZStack {
                            Button {
                                disabledPurchaseButtons.insert(icon.id)
                                disabledPurchaseButtons = disabledPurchaseButtons
                                Task {
                                    do {
                                        try await model.purchaseProduct(id: icon.id)
                                    } catch {
                                        logger.info("store: Purchase failed with error \(error)")
                                    }
                                    disabledPurchaseButtons.remove(icon.id)
                                    disabledPurchaseButtons = disabledPurchaseButtons
                                }
                            } label: {
                                Text(icon.price)
                            }
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
            Text("Icons to buy")
        }
    }
}

private struct StoreSettingsMyIconsView: View {
    @EnvironmentObject var model: Model
    @ObservedObject var store: Store

    private func setAppIcon(iconImage: String) {
        var iconImage: String? = iconImage
        if iconImage == "AppIcon" {
            iconImage = nil
        }
        UIApplication.shared.setAlternateIconName(iconImage) { error in
            if let error {
                logger.info("Failed to change app icon with error \(error)")
            }
        }
    }

    var body: some View {
        Section {
            Picker("", selection: $store.iconImage) {
                ForEach(store.myIcons) { icon in
                    HStack {
                        Text("")
                        Image(icon.imageNoBackground())
                            .interpolation(.high)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: controlBarButtonSize, height: controlBarButtonSize)
                        Spacer()
                        Text(icon.name)
                    }
                    .tag(icon.image())
                }
            }
            .onChange(of: store.iconImage) { iconImage in
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

struct StoreSettingsView: View {
    @ObservedObject var store: Store
    @State var disabledPurchaseButtons: Set<String> = []

    var body: some View {
        Form {
            Section {
                Text("Support Moblin developers by buying icons. ❤️")
            }
            if !store.iconsInStore.isEmpty {
                StoreSettingsIconsToBuyView(store: store)
            } else {
                StoreSettingsBoughtEverythingView()
            }
            StoreSettingsMyIconsView(store: store)
            StoreSettingsRestoreView()
        }
        .navigationTitle("Store")
    }
}
