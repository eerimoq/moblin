import AVKit
import SwiftUI

extension UIImage {
    func resize(height: CGFloat) -> UIImage {
        let size = CGSize(width: size.width * (height / size.height), height: height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }

        return image.withRenderingMode(renderingMode)
    }
}

func getOrientation() -> UIDeviceOrientation {
    let orientation = UIDevice.current.orientation
    if orientation != .unknown {
        return orientation
    }
    let interfaceOrientation = UIApplication.shared.connectedScenes
        .first(where: { $0 is UIWindowScene })
        .flatMap { $0 as? UIWindowScene }?.interfaceOrientation
    switch interfaceOrientation {
    case .landscapeLeft:
        return .landscapeRight
    case .landscapeRight:
        return .landscapeLeft
    default:
        return .unknown
    }
}

extension UIDevice {
    static func vibrate() {
        return AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

func isPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

func isPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func isMac() -> Bool {
    return ProcessInfo().isMacCatalystApp
}

extension ImageRenderer {
    @MainActor
    func ciImage() -> CIImage? {
        guard let image = cgImage else {
            return nil
        }
        return CIImage(cgImage: image)
    }
}

func getWindow() -> UIWindow? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
        return nil
    }
    return scene.windows.first
}

func getRootViewController() -> UIViewController? {
    return getWindow()?.rootViewController
}
