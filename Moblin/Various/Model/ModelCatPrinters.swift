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

private actor ProfileImageCache {
    private var cache: [String: (image: UIImage, timestamp: Date)] = [:]
    private let maxAge: TimeInterval = 3600

    func get(_ key: String) -> UIImage? {
        guard let entry = cache[key] else { return nil }
        if Date().timeIntervalSince(entry.timestamp) > maxAge {
            cache.removeValue(forKey: key)
            return nil
        }
        return entry.image
    }

    func set(_ key: String, image: UIImage) {
        cache[key] = (image, Date())
    }

    func clear() {
        cache.removeAll()
    }
}

private let profileImageCache = ProfileImageCache()
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
            createEventImageWithPlatform(
                username: username,
                eventText: eventText,
                platform: platform,
                profileImage: profileImage
            )
        }
    }

    private func fetchProfilePicture(username: String, platform: String) async -> UIImage? {
        let cacheKey = "\(platform):\(username)"
        if let cachedImage = await profileImageCache.get(cacheKey) {
            return cachedImage
        }
        let image: UIImage?
        switch platform.lowercased() {
        case "twitch":
            image = await fetchTwitchProfilePicture(username: username)
        case "kick":
            image = await fetchKickProfilePicture(username: username)
        default:
            image = nil
        }
        if let image = image {
            await profileImageCache.set(cacheKey, image: image)
        }
        return image
    }

    private func fetchTwitchProfilePicture(username: String) async -> UIImage? {
        guard let url = URL(string: "https://decapi.me/twitch/avatar/\(username)") else {
            return nil
        }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let imageUrlString = String(data: data, encoding: .utf8),
                  let profileUrl = URL(string: imageUrlString.trimmingCharacters(in: .whitespacesAndNewlines))
            else {
                return nil
            }
            var imageRequest = URLRequest(url: profileUrl, timeoutInterval: 10)
            imageRequest.cachePolicy = .returnCacheDataElseLoad
            let (imageData, _) = try await URLSession.shared.data(for: imageRequest)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    private func fetchKickProfilePicture(username: String) async -> UIImage? {
        guard let url = URL(string: "https://kick.com/api/v1/channels/\(username)") else {
            return nil
        }
        do {
            var request = URLRequest(url: url, timeoutInterval: 10)
            request.cachePolicy = .returnCacheDataElseLoad
            let (data, _) = try await URLSession.shared.data(for: request)
            let userResponse = try jsonDecoder.decode(CatPrinterKickUserResponse.self, from: data)
            guard let profilePicUrl = userResponse.user?.profile_pic,
                  let imageUrl = URL(string: profilePicUrl)
            else {
                return nil
            }
            var imageRequest = URLRequest(url: imageUrl, timeoutInterval: 10)
            imageRequest.cachePolicy = .returnCacheDataElseLoad
            let (imageData, _) = try await URLSession.shared.data(for: imageRequest)
            return UIImage(data: imageData)
        } catch {
            return nil
        }
    }

    private func drawDivider(at y: CGFloat, padding: CGFloat, width: CGFloat) {
        let dividerPath = UIBezierPath()
        dividerPath.move(to: CGPoint(x: padding, y: y))
        dividerPath.addLine(to: CGPoint(x: width - padding, y: y))
        UIColor.black.setStroke()
        dividerPath.lineWidth = 3
        dividerPath.stroke()
    }

    private func drawCircularImage(_ image: UIImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        let circlePath = UIBezierPath(ovalIn: rect)
        circlePath.addClip()
        image.draw(in: rect)
        context.restoreGState()
    }

    private func createAttributedString(_ text: String, font: UIFont, color: UIColor = .black) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: color,
        ])
    }

    private func createEventImageWithPlatform(
        username: String,
        eventText: String,
        platform: String,
        profileImage: UIImage?
    ) -> CIImage? {
        let width: CGFloat = 384
        let padding: CGFloat = 20
        let lineSpacing: CGFloat = 8
        var currentY: CGFloat = padding
        let platformString = createAttributedString(
            platform.uppercased(),
            font: .systemFont(ofSize: 36, weight: .bold)
        )
        let platformSize = platformString.size()
        currentY += platformSize.height + lineSpacing * 2
        let avatarSize: CGFloat = 120
        currentY += avatarSize + lineSpacing * 3
        let usernameString = createAttributedString(username, font: .systemFont(ofSize: 40, weight: .bold))
        let usernameSize = usernameString.boundingRect(
            with: CGSize(width: width - 2 * padding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).size
        currentY += usernameSize.height + lineSpacing * 2
        currentY += 2 + lineSpacing * 2
        let contentString = createAttributedString(eventText, font: .systemFont(ofSize: 28, weight: .regular))
        let contentSize = contentString.boundingRect(
            with: CGSize(width: width - 2 * padding, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            context: nil
        ).size
        currentY += contentSize.height + lineSpacing * 2
        currentY += 2 + lineSpacing * 2
        let timestamp = eventTimestampFormatter.string(from: Date())
        let timestampString = createAttributedString(
            timestamp,
            font: .monospacedSystemFont(ofSize: 24, weight: .regular)
        )
        let timestampSize = timestampString.size()
        currentY += timestampSize.height + padding
        let rect = CGRect(origin: .zero, size: CGSize(width: width, height: currentY))
        UIGraphicsBeginImageContextWithOptions(rect.size, false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else {
            UIGraphicsEndImageContext()
            return nil
        }
        UIColor.white.setFill()
        context.fill(rect)
        currentY = padding
        let platformX = (width - platformSize.width) / 2
        platformString.draw(at: CGPoint(x: platformX, y: currentY))
        currentY += platformSize.height + lineSpacing * 2
        let avatarX = (width - avatarSize) / 2
        let avatarRect = CGRect(x: avatarX, y: currentY, width: avatarSize, height: avatarSize)
        if let profileImage = profileImage {
            drawCircularImage(profileImage, in: avatarRect, context: context)
        } else if let appIcon = UIImage(named: "AppIconNoBackground") {
            drawCircularImage(appIcon, in: avatarRect, context: context)
        } else {
            let circlePath = UIBezierPath(ovalIn: avatarRect)
            UIColor.lightGray.setFill()
            circlePath.fill()
            let initial = String(username.prefix(1).uppercased())
            let initialString = createAttributedString(
                initial,
                font: .systemFont(ofSize: 60, weight: .bold),
                color: .white
            )
            let initialSize = initialString.size()
            let initialX = avatarX + (avatarSize - initialSize.width) / 2
            let initialY = currentY + (avatarSize - initialSize.height) / 2
            initialString.draw(at: CGPoint(x: initialX, y: initialY))
        }
        currentY += avatarSize + lineSpacing * 2
        let usernameX = (width - usernameSize.width) / 2
        usernameString.draw(at: CGPoint(x: usernameX, y: currentY))
        currentY += usernameSize.height + lineSpacing * 2
        drawDivider(at: currentY, padding: padding, width: width)
        currentY += 2 + lineSpacing * 2
        let contentX = (width - contentSize.width) / 2
        contentString.draw(in: CGRect(x: contentX, y: currentY, width: contentSize.width, height: contentSize.height))
        currentY += contentSize.height + lineSpacing * 2
        drawDivider(at: currentY, padding: padding, width: width)
        currentY += 2 + lineSpacing * 2
        let timestampX = (width - timestampSize.width) / 2
        timestampString.draw(at: CGPoint(x: timestampX, y: currentY))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgImage = image?.cgImage else {
            return nil
        }
        return CIImage(cgImage: cgImage)
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
