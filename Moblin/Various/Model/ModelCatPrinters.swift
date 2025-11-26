import CoreImage
import SwiftUI
import UIKit

private let eventTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy HH:mm:ss"
    return formatter
}()

enum CatPrinterEvent {
    case twitchFollow
    case twitchSubscribe
    case twitchSubscrptionGift
    case twitchResubscribe
    case twitchRaid
    case twitchCheer(amount: Int)
    case twitchReward
    case kickSubscription
    case kickGiftedSubscriptions
    case kickHost
    case kickReward
    case kickKicks(amount: Int)

    func platform() -> Platform {
        switch self {
        case .twitchFollow:
            return .twitch
        case .twitchSubscribe:
            return .twitch
        case .twitchSubscrptionGift:
            return .twitch
        case .twitchResubscribe:
            return .twitch
        case .twitchRaid:
            return .twitch
        case .twitchCheer:
            return .twitch
        case .twitchReward:
            return .twitch
        case .kickSubscription:
            return .kick
        case .kickGiftedSubscriptions:
            return .kick
        case .kickHost:
            return .kick
        case .kickReward:
            return .kick
        case .kickKicks:
            return .kick
        }
    }
}

extension Model {
    func printAllCatPrinters(image: CIImage, feedPaperDelay: Double? = nil) {
        for catPrinter in catPrinters.values {
            catPrinter.print(image: image, feedPaperDelay: feedPaperDelay)
        }
    }

    func printSnapshotCatPrinters(image: CIImage) {
        for catPrinter in catPrinters.values where
            getCatPrinterSettings(catPrinter: catPrinter)?.printSnapshots == true
        {
            catPrinter.print(image: image, feedPaperDelay: nil)
        }
    }

    func printEventCatPrinters(event: CatPrinterEvent, username: String, message: String) {
        Task { @MainActor in
            var image: CIImage?
            for catPrinter in catPrinters.values {
                guard let settings = getCatPrinterSettings(catPrinter: catPrinter) else {
                    continue
                }
                guard isCatPrinterEventEnabled(event: event, settings: settings) else {
                    continue
                }
                if image == nil {
                    image = await createEventImage(username: username,
                                                   message: message,
                                                   platform: event.platform())
                }
                if let image {
                    catPrinter.print(image: image, feedPaperDelay: nil)
                }
            }
        }
    }

    func catPrinterPrintTestImage(device: SettingsCatPrinter) {
        catPrinters[device.id]?.print(image: CIImage.black.cropped(to: .init(
            origin: .zero,
            size: .init(width: 100, height: 10)
        )))
    }

    func isCatPrinterEnabled(device: SettingsCatPrinter) -> Bool {
        device.enabled
    }

    func enableCatPrinter(device: SettingsCatPrinter) {
        if !catPrinters.keys.contains(device.id) {
            let catPrinter = CatPrinter()
            catPrinter.delegate = self
            catPrinters[device.id] = catPrinter
        }
        catPrinters[device.id]?.start(
            deviceId: device.bluetoothPeripheralId,
            meowSoundEnabled: device.faxMeowSound
        )
    }

    func catPrinterSetFaxMeowSound(device: SettingsCatPrinter) {
        catPrinters[device.id]?.setMeowSoundEnabled(meowSoundEnabled: device.faxMeowSound)
    }

    func disableCatPrinter(device: SettingsCatPrinter) {
        catPrinters[device.id]?.stop()
    }

    func getCatPrinterSettings(catPrinter: CatPrinter) -> SettingsCatPrinter? {
        database.catPrinters.devices.first(where: { catPrinters[$0.id] === catPrinter })
    }

    func setCurrentCatPrinter(device: SettingsCatPrinter) {
        currentCatPrinterSettings = device
        statusTopRight.catPrinterState = getCatPrinterState(device: device)
    }

    func getCatPrinterState(device: SettingsCatPrinter) -> CatPrinterState {
        catPrinters[device.id]?.getState() ?? .disconnected
    }

    func autoStartCatPrinters() {
        for device in database.catPrinters.devices where device.enabled {
            enableCatPrinter(device: device)
        }
    }

    func stopCatPrinters() {
        for catPrinter in catPrinters.values {
            catPrinter.stop()
        }
    }

    func isAnyConnectedCatPrinterPrintingChat() -> Bool {
        catPrinters.values.contains(where: {
            $0.getState() == .connected && getCatPrinterSettings(catPrinter: $0)?.printChat == true
        })
    }

    func isAnyCatPrinterConfigured() -> Bool {
        database.catPrinters.devices.contains(where: { $0.enabled })
    }

    func areAllCatPrintersConnected() -> Bool {
        !catPrinters.values.contains(where: {
            getCatPrinterSettings(catPrinter: $0)?.enabled == true && $0.getState() != .connected
        })
    }

    private func isCatPrinterEventEnabled(event: CatPrinterEvent, settings: SettingsCatPrinter) -> Bool {
        switch event {
        case .twitchFollow:
            return settings.printTwitch.follows
        case .twitchSubscribe:
            return settings.printTwitch.subscriptions
        case .twitchSubscrptionGift:
            return settings.printTwitch.giftSubscriptions
        case .twitchResubscribe:
            return settings.printTwitch.resubscriptions
        case .twitchRaid:
            return settings.printTwitch.raids
        case let .twitchCheer(amount):
            return settings.printTwitch.isBitsEnabled(amount: amount)
        case .twitchReward:
            return settings.printTwitch.rewards
        case .kickSubscription:
            return settings.printKick.subscriptions
        case .kickGiftedSubscriptions:
            return settings.printKick.giftedSubscriptions
        case .kickHost:
            return settings.printKick.hosts
        case .kickReward:
            return settings.printKick.rewards
        case let .kickKicks(amount):
            return settings.printKick.isKicksEnabled(amount: amount)
        }
    }

    @MainActor
    private func createEventImage(
        username: String,
        message: String,
        platform: Platform
    ) async -> CIImage? {
        let profileImage = await fetchProfilePicture(username: username, platform: platform)
        let eventCard = VStack(spacing: 16) {
            Text(platform.name())
                .font(.system(size: 36, weight: .bold))
            Image(uiImage: profileImage ?? UIImage(named: "AppIconNoBackground")!)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 120, height: 120)
                .clipShape(Circle())
            Text(username)
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(.black)
                .frame(height: 3)
                .padding(.horizontal, 20)
            Text(message)
                .font(.system(size: 28, weight: .regular))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Rectangle()
                .fill(.black)
                .frame(height: 3)
                .padding(.horizontal, 20)
            Text(eventTimestampFormatter.string(from: .now))
                .font(.system(size: 24, weight: .regular, design: .monospaced))
        }
        .foregroundStyle(.black)
        .padding(20)
        .frame(width: 384)
        .background(.white)
        let renderer = ImageRenderer(content: eventCard)
        guard let image = renderer.uiImage else {
            return nil
        }
        return CIImage(image: image)
    }

    private func fetchProfilePicture(username: String, platform: Platform) async -> UIImage? {
        switch platform {
        case .twitch:
            return await fetchTwitchProfilePicture(username: username)
        case .kick:
            return await fetchKickProfilePicture(username: username)
        default:
            return nil
        }
    }
}

extension Model: CatPrinterDelegate {
    func catPrinterState(_ catPrinter: CatPrinter, state: CatPrinterState) {
        DispatchQueue.main.async {
            guard let device = self.getCatPrinterSettings(catPrinter: catPrinter) else {
                return
            }
            if device === self.currentCatPrinterSettings {
                self.statusTopRight.catPrinterState = state
            }
        }
    }
}
