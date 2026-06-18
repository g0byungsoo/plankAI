#if canImport(UIKit)
import Photos
import SwiftUI
import UIKit

// MARK: - ShareImageSaver
//
// v1.0.12 (2026-06-17) — explicit "save to Photos" path for share
// surfaces. Founder feedback: "we don't have a download option from
// the share button." iOS's UIActivityViewController surfaces a "Save
// Image" action by default, but it's buried under other apps and
// often missed; a dedicated save button next to the share button is
// the explicit affordance.
//
// Uses `.addOnly` photo library access — JeniFit never reads existing
// photos via this path, only adds the rendered share card. The
// `NSPhotoLibraryAddUsageDescription` string in Info.plist is shown
// the first time the user taps save.

@MainActor
public enum ShareImageSaver {

    public enum SaveResult: Sendable {
        /// Image was written to the user's Photos library.
        case saved
        /// User denied access via the system prompt, or has previously
        /// denied. Caller surfaces a recovery hint pointing at Settings.
        case denied
        /// Authorization fine, write failed — disk full, OS error, etc.
        case failed
    }

    /// Persists `image` to the user's Photos library. Returns the
    /// outcome so the caller can hide the share/save buttons or surface
    /// a toast as appropriate. Idempotent at the API level (each call
    /// adds a new asset; the caller is expected to guard against
    /// double-tap via UI state).
    public static func save(_ image: UIImage) async -> SaveResult {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            break
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard granted == .authorized || granted == .limited else {
                return .denied
            }
        case .denied, .restricted:
            return .denied
        @unknown default:
            return .denied
        }

        return await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, _ in
                continuation.resume(returning: success ? .saved : .failed)
            }
        }
    }
}

// MARK: - SaveToPhotosToast
//
// Small inline toast — flies up from the bottom of the share preview
// when the save lands. Auto-dismisses after ~1.6s so the founder /
// user can flick back to the picker without an explicit close tap.

public struct SaveToPhotosToast: View {

    public let result: ShareImageSaver.SaveResult

    public init(result: ShareImageSaver.SaveResult) {
        self.result = result
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
            Text(message)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(
            Capsule().fill(background)
        )
    }

    private var iconName: String {
        switch result {
        case .saved:  return "checkmark.circle.fill"
        case .denied: return "lock.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }

    private var message: String {
        switch result {
        case .saved:  return "saved to photos"
        case .denied: return "allow photos access in settings"
        case .failed: return "couldn't save — try again"
        }
    }

    private var background: Color {
        switch result {
        case .saved:  return Color(red: 0.20, green: 0.45, blue: 0.30).opacity(0.92)
        case .denied: return Color(red: 0.55, green: 0.30, blue: 0.30).opacity(0.92)
        case .failed: return Color(red: 0.55, green: 0.30, blue: 0.30).opacity(0.92)
        }
    }
}

#endif  // canImport(UIKit)
