import StoreKit

let plainIcon = Icon(name: "Plain", id: "AppIcon", price: "")

private let globalMyIcons = [
    plainIcon,
    Icon(name: "San Diego", id: "AppIconSanDiego", price: "$"),
]

private let iconsProductIds = [
    "AppIconKing",
    "AppIconQueen",
    "AppIconLooking",
    "AppIconPixels",
    "AppIconHeart",
    "AppIconPink",
    "AppIconHappy",
    "AppIconMillionaire",
    "AppIconBillionaire",
    "AppIconTrillionaire",
    "AppIconTetris",
    "AppIconTub",
    "AppIconGoblin",
    "AppIconGoblina",
    "AppIconIreland",
    "AppIconPeru",
]

struct Icon: Identifiable {
    var name: String
    var id: String
    var price: String

    func imageNoBackground() -> String {
        "\(id)NoBackground"
    }

    func image() -> String {
        id
    }
}

extension Model {
    @MainActor
    func getProductsFromAppStore() async {
        do {
            let products = try await Product.products(for: iconsProductIds)
            for product in products {
                self.products[product.id] = product
            }
            logger.debug("store: Got \(products.count) product(s) from App Store")
        } catch {
            logger.info("store: Failed to get products from App Store: \(error)")
        }
    }

    func listenForAppStoreTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                guard let transaction = self.checkVerified(result: result) else {
                    logger.info("store: Updated transaction failed verification")
                    continue
                }
                await self.updateProductFromAppStore()
                await transaction.finish()
            }
        }
    }

    private func checkVerified(result: VerificationResult<StoreKit.Transaction>) -> StoreKit.Transaction? {
        switch result {
        case .unverified:
            nil
        case let .verified(safe):
            safe
        }
    }

    @MainActor
    func updateProductFromAppStore() async {
        logger.debug("store: Update my products from App Store")
        let myProductIds = await getMyProductIds()
        updateIcons(myProductIds: myProductIds)
    }

    private func getMyProductIds() async -> [String] {
        var myProductIds: [String] = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = checkVerified(result: result) else {
                logger.info("store: Verification failed for my product")
                continue
            }
            myProductIds.append(transaction.productID)
        }
        return myProductIds
    }

    private func updateIcons(myProductIds: [String]) {
        var myIcons: [Icon] = []
        store.hasBoughtSomething = false
        var iconsInStore: [Icon] = []
        for productId in iconsProductIds {
            guard let product = products[productId] else {
                logger.info("store: Icon product \(productId) not found")
                continue
            }
            if myProductIds.contains(productId) {
                myIcons.append(Icon(
                    name: product.displayName,
                    id: product.id,
                    price: product.displayPrice
                ))
                store.hasBoughtSomething = true
            } else {
                iconsInStore.append(Icon(
                    name: product.displayName,
                    id: product.id,
                    price: product.displayPrice
                ))
            }
        }
        store.myIcons = myIcons + globalMyIcons
        store.iconsInStore = iconsInStore
    }

    private func findProduct(id: String) -> Product? {
        products[id]
    }

    func purchaseProduct(id: String) async throws {
        guard let product = findProduct(id: id) else {
            throw "Product not found"
        }
        let result = try await product.purchase()

        switch result {
        case let .success(result):
            logger.info("store: Purchase successful")
            guard let transaction = checkVerified(result: result) else {
                throw "Purchase failed verification"
            }
            await updateProductFromAppStore()
            await transaction.finish()
        case .userCancelled, .pending:
            logger.info("store: Purchase not done yet")
        default:
            logger.info("store: What happened when buying? \(result)")
        }
    }

    private func isInMyIcons(id: String) -> Bool {
        store.myIcons.contains(where: { $0.id == id })
    }

    func updateIconImageFromDatabase() {
        if !isInMyIcons(id: database.iconImage) {
            database.iconImage = plainIcon.id
        }
        store.iconImage = database.iconImage
    }
}
