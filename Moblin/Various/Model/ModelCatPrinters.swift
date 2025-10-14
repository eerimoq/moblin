import CoreImage
import SwiftUI
import UIKit

private let eventTimestampFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy HH:mm:ss"
    return formatter
}()

private struct CatPrinterKickUser: Codable {
    let profile_pic: String?
}

private struct CatPrinterKickUserResponse: Codable {
    let user: CatPrinterKickUser?
}

private let jsonDecoder = JSONDecoder()

extension Model {
    func printAllCatPrinters(image: CIImage, feedPaperDelay: Double? = nil) {
        for catPrinter in catPrinters.values {
            catPrinter.print(image: image, feedPaperDelay: feedPaperDelay)
        }
    }

    func printEventCatPrinters(
        _ username: String,
        _ eventText: String,
        _ platform: String,
        _ eventType: CatPrinterEventType
    ) {
        printEventCatPrinters(username: username, eventText: eventText, platform: platform, eventType: eventType)
    }

    func printEventCatPrinters(username: String, eventText: String, platform: String, eventType: CatPrinterEventType) {
        for catPrinter in catPrinters.values {
            guard let settings = getCatPrinterSettings(catPrinter: catPrinter),
                  settings.printEvents,
                  settings.isEventTypeEnabled(eventType)
            else {
                continue
            }
            Task {
                if let image = await createEventImage(username: username, eventText: eventText, platform: platform) {
                    catPrinter.print(image: image, feedPaperDelay: nil)
                }
            }
        }
    }

    private func createEventImage(
        username: String,
        eventText: String,
        platform: String
    ) async -> CIImage? {
        let profileImage = await fetchProfilePicture(username: username, platform: platform)
        return await MainActor.run {
            let eventCard = VStack(spacing: 16) {
                Text(platform.uppercased())
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.black)

                if let profileImage = profileImage {
                    Image(uiImage: profileImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else if let appIcon = UIImage(named: "AppIconNoBackground") {
                    Image(uiImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                        Text(String(username.prefix(1).uppercased()))
                            .font(.system(size: 60, weight: .bold))
                            .foregroundColor(.white)
                    }
                }

                Text(username)
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal, 20)

                Text(eventText)
                    .font(.system(size: 28, weight: .regular))
                    .foregroundColor(.black)
                    .lineLimit(nil)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
                    .padding(.horizontal, 20)

                Text(eventTimestampFormatter.string(from: Date()))
                    .font(.system(size: 24, weight: .regular, design: .monospaced))
                    .foregroundColor(.black)
            }
            .padding(20)
            .frame(width: 384)
            .background(Color.white)

            let renderer = ImageRenderer(content: eventCard)
            guard let image = renderer.uiImage else {
                return nil
            }
            guard let ciImage = CIImage(image: image) else {
                return nil
            }
            return ciImage
        }
    }

    private func fetchProfilePicture(username: String, platform: String) async -> UIImage? {
        switch platform.lowercased() {
        case "twitch":
            return await fetchTwitchProfilePicture(username: username)
        case "kick":
            return await fetchKickProfilePicture(username: username)
        default:
            return nil
        }
    }

    private func fetchTwitchProfilePicture(username: String) async -> UIImage? {
        guard let url = URL(string: "https://decapi.me/twitch/avatar/\(username)") else {
            return nil
        }
        let request = URLRequest(url: url, timeoutInterval: 10)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let imageUrlString = String(data: data, encoding: .utf8),
              let profileUrl = URL(string: imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines))
        else {
            return nil
        }
        let imageRequest = URLRequest(url: profileUrl, timeoutInterval: 10)
        guard let (imageData, _) = try? await URLSession.shared.data(for: imageRequest) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    private func fetchKickProfilePicture(username: String) async -> UIImage? {
        if let image = await fetchKickProfilePictureWithUsername(username) {
            return image
        }
        if username.contains("_") {
            let normalizedUsername = username.replacingOccurrences(of: "_", with: "-")
            return await fetchKickProfilePictureWithUsername(normalizedUsername)
        }
        return nil
    }

    private func fetchKickProfilePictureWithUsername(_ username: String) async -> UIImage? {
        guard let url = URL(string: "https://kick.com/api/v1/channels/\(username)") else {
            return nil
        }
        let request = URLRequest(url: url, timeoutInterval: 10)
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let userResponse = try? jsonDecoder.decode(CatPrinterKickUserResponse.self, from: data),
              let profilePicUrl = userResponse.user?.profile_pic,
              let imageUrl = URL(string: profilePicUrl)
        else {
            return nil
        }
        let imageRequest = URLRequest(url: imageUrl, timeoutInterval: 10)
        guard let (imageData, _) = try? await URLSession.shared.data(for: imageRequest) else {
            return nil
        }
        return UIImage(data: imageData)
    }

    func printSnapshotCatPrinters(image: CIImage) {
        for catPrinter in catPrinters.values where
            getCatPrinterSettings(catPrinter: catPrinter)?.printSnapshots == true
        {
            catPrinter.print(image: image, feedPaperDelay: nil)
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
