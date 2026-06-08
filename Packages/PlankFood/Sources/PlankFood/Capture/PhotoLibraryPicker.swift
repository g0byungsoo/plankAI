#if canImport(UIKit)
import SwiftUI
import PhotosUI

// MARK: - PhotoLibraryPicker
//
// v1.0.8 Phase H (2026-06-08) — SwiftUI wrapper around
// PHPickerViewController. Founder request via wife's target-audience
// feedback: "A user may take a food photo earlier and want to log it
// later." Cohort psychology: women already curate their food photos
// in the camera roll (Instagram funnel). Forcing them to RE-shoot at
// log time is friction we don't need.
//
// Why PHPicker (vs UIImagePickerController):
//   - PHPicker is the modern iOS 14+ API
//   - No camera roll access permission required (system-mediated)
//   - Better preview UI, video filtering, multi-select option
//   - Sandboxed — JeniFit never sees the user's whole library
//
// Returns the selected UIImage via the onPicked callback. Caller
// is responsible for downstream resize + saliency + JPEG encode
// (PhotoCaptureView already has that path via the existing
// FoodCameraManager helpers; the picker just produces the source
// UIImage that those helpers consume).

struct PhotoLibraryPicker: UIViewControllerRepresentable {
    let onPicked: (UIImage) -> Void
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        // .compatible asks PHPicker to convert to JPEG/PNG so we
        // don't have to deal with HEIC decode paths downstream.
        // .current would preserve the original format.
        config.preferredAssetRepresentationMode = .compatible
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPicked: onPicked, onCancel: onCancel)
    }

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPicked: (UIImage) -> Void
        let onCancel: () -> Void

        init(onPicked: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) {
            self.onPicked = onPicked
            self.onCancel = onCancel
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            // Dismiss the picker immediately; image load happens off
            // the main thread but the UI returns to the camera view
            // in parallel.
            picker.dismiss(animated: true)

            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else {
                onCancel()
                return
            }

            provider.loadObject(ofClass: UIImage.self) { [onPicked, onCancel] object, error in
                if let image = object as? UIImage {
                    DispatchQueue.main.async { onPicked(image) }
                } else {
                    #if DEBUG
                    print("[PhotoLibraryPicker] loadObject failed: \(error?.localizedDescription ?? "unknown")")
                    #endif
                    DispatchQueue.main.async { onCancel() }
                }
            }
        }
    }
}

#endif  // canImport(UIKit)
