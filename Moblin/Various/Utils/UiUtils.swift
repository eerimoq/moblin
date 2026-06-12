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

@MainActor
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
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }
}

@MainActor
func isPhone() -> Bool {
    UIDevice.current.userInterfaceIdiom == .phone
}

@MainActor
func isPad() -> Bool {
    UIDevice.current.userInterfaceIdiom == .pad
}

func isMac() -> Bool {
    ProcessInfo().isMacCatalystApp
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

@MainActor
func getWindow() -> UIWindow? {
    guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
        return nil
    }
    return scene.windows.first
}

@MainActor
func getRootViewController() -> UIViewController? {
    getWindow()?.rootViewController
}

@MainActor
func screenScale() -> CGFloat {
    if isMac() {
        2
    } else {
        UIScreen().scale
    }
}

func makeOffsets<T: Identifiable>(_ items: [T], _ id: T.ID) -> IndexSet? {
    if let index = items.firstIndex(where: { $0.id == id }) {
        IndexSet(integer: index)
    } else {
        nil
    }
}

func updateDockIcon(isLive: Bool) {
    #if targetEnvironment(macCatalyst)
    print("DEBUG: updateDockIcon called, isLive: \(isLive)")
    logger.info("updateDockIcon: called with isLive = \(isLive)")
    if NSClassFromString("NSApplication") == nil {
        let appKitBundle = Bundle(path: "/System/Library/Frameworks/AppKit.framework")
        appKitBundle?.load()
    }
    guard let nsAppClass = NSClassFromString("NSApplication") as? NSObject.Type,
          let sharedApp = nsAppClass.value(forKey: "sharedApplication") as? NSObject,
          let nsImageClass = NSClassFromString("NSImage") as AnyObject?,
          let nsImageViewClass = NSClassFromString("NSImageView") as AnyObject?,
          let dockTile = sharedApp.value(forKey: "dockTile") as? NSObject
    else {
        logger.info("updateDockIcon: failed to resolve AppKit classes or dockTile")
        return
    }
    
    let displaySel = NSSelectorFromString("display")
    
    if isLive {
        if let liveIconUrl = Bundle.main.url(forResource: "LiveIcon", withExtension: "png") {
            let nsUrl = liveIconUrl as NSURL
            print("DEBUG: updateDockIcon - live icon url resolved to \(nsUrl)")
            logger.info("updateDockIcon: live icon url resolved to \(nsUrl)")
            let allocSel = NSSelectorFromString("alloc")
            let initUrlSel = NSSelectorFromString("initWithContentsOfURL:")
            if let nsImageAlloc = nsImageClass.perform(allocSel)?.takeUnretainedValue(),
               let nsImage = nsImageAlloc.perform(initUrlSel, with: nsUrl)?.takeUnretainedValue(),
               let nsImageViewAlloc = nsImageViewClass.perform(allocSel)?.takeUnretainedValue(),
               let nsImageView = nsImageViewAlloc.perform(NSSelectorFromString("init"))?.takeUnretainedValue() {
                
                print("DEBUG: updateDockIcon - successfully loaded LiveIcon and setting dockTile.contentView")
                logger.info("updateDockIcon: successfully loaded LiveIcon and setting dockTile.contentView")
                
                nsImageView.setValue(nsImage, forKey: "image")
                dockTile.setValue(nsImageView, forKey: "contentView")
                _ = dockTile.perform(displaySel)
            } else {
                print("DEBUG: updateDockIcon - failed to instantiate NSImage or NSImageView!")
                logger.info("updateDockIcon: failed to instantiate NSImage or NSImageView")
            }
        } else {
            print("DEBUG: updateDockIcon - LiveIcon.png not found in bundle resources!")
            logger.info("updateDockIcon: LiveIcon.png not found in bundle resources")
        }
    } else {
        logger.info("updateDockIcon: resetting dockTile.contentView to nil")
        dockTile.setValue(nil, forKey: "contentView")
        _ = dockTile.perform(displaySel)
    }
    #endif
}

