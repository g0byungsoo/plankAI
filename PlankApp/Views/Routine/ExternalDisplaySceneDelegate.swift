import UIKit
import SwiftUI

/// Owns the `UIWindow` on the external display (Apple TV via AirPlay
/// Mirroring, HDMI dongle). Instantiated by iOS when the external-display
/// scene role is requested — configured in `Info.plist` under
/// `UIApplicationSceneManifest` →
/// `UIWindowSceneSessionRoleExternalDisplayNonInteractive`.
///
/// On connect: builds a hosting controller around `ExternalSessionRoot`,
/// which observes `SessionBridge.shared` and renders the cinema view as
/// long as a routine session is active on the phone. On disconnect:
/// tears the window down and flips the bridge so the phone's AirPlay
/// affordance updates.
@objc(ExternalDisplaySceneDelegate)
final class ExternalDisplaySceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        #if DEBUG
        print("[ExternalDisplay] willConnect — role=\(session.role.rawValue) screen=\(String(describing: (scene as? UIWindowScene)?.screen.bounds.size))")
        #endif
        guard let windowScene = scene as? UIWindowScene else {
            #if DEBUG
            print("[ExternalDisplay] scene is not UIWindowScene — bailing")
            #endif
            return
        }

        let host = UIHostingController(rootView: ExternalSessionRoot())
        host.view.backgroundColor = UIColor(Palette.bgPrimary)

        let w = UIWindow(windowScene: windowScene)
        w.rootViewController = host
        w.isHidden = false
        self.window = w

        Task { @MainActor in SessionBridge.shared.isMirroring = true }
        #if DEBUG
        print("[ExternalDisplay] window attached; bridge.vm is \(SessionBridge.shared.vm == nil ? "nil (idle view)" : "set (cinema view)")")
        #endif
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        #if DEBUG
        print("[ExternalDisplay] didDisconnect")
        #endif
        window?.isHidden = true
        window = nil
        Task { @MainActor in SessionBridge.shared.isMirroring = false }
    }
}
