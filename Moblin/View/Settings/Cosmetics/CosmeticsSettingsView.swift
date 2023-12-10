import SwiftUI

struct CosmeticsSettingsView: View {
    @EnvironmentObject var model: Model
    @State var disabledPurchaseButtons: Set<String> = []

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
                                .frame(width: buttonSize, height: buttonSize)
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
                    ForEach(model.iconsSubscriptions) { subscription in
                        HStack {
                            Text(subscription.name)
                            Spacer()
                            if subscription.subscribed {
                                Text("Subscribed")
                            } else {
                                ZStack {
                                    Button(action: {
                                        disabledPurchaseButtons.insert(subscription.id)
                                        disabledPurchaseButtons = disabledPurchaseButtons
                                        Task {
                                            do {
                                                try await model.purchaseProduct(id: subscription.id)
                                            } catch {
                                                logger
                                                    .info(
                                                        "cosmetics: Purchase failed with error \(error)"
                                                    )
                                            }
                                            disabledPurchaseButtons.remove(subscription.id)
                                            disabledPurchaseButtons = disabledPurchaseButtons
                                        }
                                    }, label: {
                                        Text(subscription.price)
                                    })
                                    .padding([.leading], 10)
                                    .disabled(disabledPurchaseButtons.contains(subscription.id))
                                    .opacity(disabledPurchaseButtons.contains(subscription.id) ? 0.0 : 1.0)
                                    if disabledPurchaseButtons.contains(subscription.id) {
                                        ProgressView().padding([.leading], 10)
                                    }
                                }
                            }
                        }
                        .tag(subscription.id)
                    }
                }
            } header: {
                Text("Subscriptions")
            } footer: {
                Text("Including all icons added in the future.")
            }
            if model.iconsInStore.count > 0 {
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
                } footer: {
                    Text("Support Moblin developers by buying icons.")
                }
            } else {
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
            Section {
                List {
                    ForEach(model.iconsNotYetInStore) { icon in
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
            } header: {
                Text("Icons not yet in store")
            }
        }
        .navigationTitle("Cosmetics")
        .toolbar {
            SettingsToolbar()
        }
    }
}
