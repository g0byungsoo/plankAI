#if canImport(UIKit)
import SwiftUI
import AVFoundation

// MARK: - PhotoCaptureView
//
// Main camera UI for the food rail. Per v5 §Calorie scan flow Screen 1
// (locked):
//
//   - Scrapbook frame around viewfinder (NOT black camera UI). 24pt
//     corners + 1.5pt cocoa border + cocoa shadow.
//   - Top: cancel (top-left X) + flash toggle (top-right, stubbed
//     for W2-T2; wires in a later polish ticket).
//   - Cocoa pill shutter with "tap to scan" label (large, ≈80pt).
//   - 3-mode chip row at bottom: photo / quick add / i'm out.
//
// D54 (2026-06-05): pre-eat / just-ate mode toggle removed.
// Founder feedback: "after you eat food there is no food left to take
// a photo" — the pre-eat distinction makes no sense at the camera
// moment. Result card now has one unified layout; permission framing
// lives in Jeni's copy line instead of UI chrome.
//
// Capture flow on shutter tap:
//   1. Disable shutter (debounce)
//   2. FoodCameraManager.captureStill() → JPEG Data (1024px, q0.8, no EXIF)
//   3. FoodCaptureDispatcher.dispatch(.photo(data))
//   4. Until W2-T3 lands, dispatch throws .notImplemented — DEBUG
//      surfaces the ticket reference, Release shows generic copy
//
// Mode chips (photo / quick add / i'm out) update local UI state in
// W2-T2 but don't navigate yet — QuickAddView (W3-T3) and ImOutTonightView
// (W3-T4) replace this view's content when their tabs are selected.

@MainActor
public struct PhotoCaptureView: View {

    // MARK: - State

    @State private var camera = FoodCameraManager()
    @State private var dispatcher = FoodCaptureDispatcher()

    @State private var captureTab: CaptureTab = .photo
    @State private var isCapturing: Bool = false
    @State private var capturedResult: CapturedFood?
    @State private var errorMessage: String?

    public let onDismiss: () -> Void
    public let onCaptured: (CapturedFood) -> Void
    public let onQuickAddTapped: () -> Void
    public let onImOutTapped: () -> Void

    // MARK: - Init

    public init(
        onDismiss: @escaping () -> Void,
        onCaptured: @escaping (CapturedFood) -> Void,
        onQuickAddTapped: @escaping () -> Void = {},
        onImOutTapped: @escaping () -> Void = {}
    ) {
        self.onDismiss = onDismiss
        self.onCaptured = onCaptured
        self.onQuickAddTapped = onQuickAddTapped
        self.onImOutTapped = onImOutTapped
    }

    // MARK: - Body

    public var body: some View {
        ZStack {
            FoodTheme.bgPrimary
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer(minLength: FoodTheme.Space.md)
                viewfinder
                Spacer(minLength: FoodTheme.Space.md)
                shutter
                    .padding(.bottom, FoodTheme.Space.lg)
                modeChips
                    .padding(.bottom, FoodTheme.Space.md)
            }
            .padding(.horizontal, FoodTheme.Space.screenPadding)
        }
        .task {
            await bootCamera()
        }
        .onDisappear {
            camera.stopSession()
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                errorBanner(errorMessage)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder private var topBar: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("cancel")

            Spacer()

            // Flash toggle — stub for W2-T2; live wiring in polish pass.
            Button {
                // No-op for now.
            } label: {
                Image(systemName: "bolt.slash")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("flash")
            .opacity(0.5)  // visually subdued until wired
        }
        .padding(.top, FoodTheme.Space.sm)
    }

    @ViewBuilder private var viewfinder: some View {
        ZStack {
            if camera.permissionStatus == .authorized {
                FoodCameraPreviewView(previewLayer: camera.previewLayer)
            } else if camera.permissionStatus == .denied {
                permissionDeniedPlaceholder
            } else {
                ProgressView()
                    .tint(FoodTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
        .overlay(
            // Scrapbook frame chrome — 1.5pt cocoa border per v5 lock.
            RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                .stroke(FoodTheme.textPrimary, lineWidth: FoodTheme.Stroke.scrapbook)
        )
        .shadow(color: FoodTheme.textPrimary.opacity(0.25), radius: 0, x: 3, y: 3)
    }

    @ViewBuilder private var permissionDeniedPlaceholder: some View {
        VStack(spacing: FoodTheme.Space.sm) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(FoodTheme.textSecondary)
            Text("camera access turned off")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("enable in Settings → JeniFit")
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(FoodTheme.bgElevated)
    }

    @ViewBuilder private var shutter: some View {
        Button {
            Task { await captureTapped() }
        } label: {
            HStack(spacing: FoodTheme.Space.sm) {
                if isCapturing {
                    ProgressView()
                        .tint(FoodTheme.bgPrimary)
                } else {
                    Circle()
                        .fill(FoodTheme.bgPrimary)
                        .frame(width: 18, height: 18)
                }
                Text(isCapturing ? "scanning…" : "tap to scan")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
            .background(
                Capsule().fill(FoodTheme.textPrimary)
            )
        }
        .disabled(isCapturing || camera.permissionStatus != .authorized || !camera.isRunning)
        .accessibilityLabel("scan food")
    }

    @ViewBuilder private var modeChips: some View {
        HStack(spacing: FoodTheme.Space.sm) {
            modeChip("📷", "photo", .photo)
            modeChip("🌸", "quick add", .quickAdd)
            modeChip("🍽", "i'm out", .imOut)
        }
    }

    @ViewBuilder
    private func modeChip(_ icon: String, _ label: String, _ tab: CaptureTab) -> some View {
        Button {
            captureTab = tab
            // 2026-06-05: chips now route to peer phases via callbacks.
            // CaptureFlowView swaps the active view; photo remains the
            // default (this view) and re-selecting it is a no-op.
            switch tab {
            case .photo:    break
            case .quickAdd: onQuickAddTapped()
            case .imOut:    onImOutTapped()
            }
        } label: {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.system(size: 16))
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(captureTab == tab ? FoodTheme.textPrimary : FoodTheme.textSecondary)
            }
            .padding(.horizontal, FoodTheme.Space.md)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(
                    captureTab == tab ? FoodTheme.accentSubtle : FoodTheme.bgElevated
                )
            )
        }
    }

    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(FoodTheme.bgPrimary)
            .padding(.horizontal, FoodTheme.Space.md)
            .padding(.vertical, FoodTheme.Space.sm)
            .background(
                Capsule().fill(FoodTheme.textPrimary)
            )
            .padding(.top, 60)
            .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - Actions

    private func bootCamera() async {
        let status = await camera.requestPermission()
        if status == .authorized {
            camera.startSession()
        }
    }

    private func captureTapped() async {
        guard !isCapturing else { return }
        isCapturing = true
        errorMessage = nil
        defer { isCapturing = false }

        do {
            let jpeg = try await camera.captureStill()
            let result = try await dispatcher.dispatch(.photo(jpeg))

            // Empty-identification guard: LLM returned 200 but with no
            // items AND no restaurant-range fallback. Common causes: no
            // food in frame, severe blur, dark scene. Stay on camera
            // with a friendly retry banner rather than advancing to a
            // phantom result card (founder bug 2026-06-05 — user saw
            // a card with only "log it" + "actually skip" because every
            // content branch was `if let item = food.items.first` and
            // items was empty).
            if result.items.isEmpty && result.kcalLow == nil {
                errorMessage = "couldn't see any food. try a brighter or closer angle?"
                return
            }

            capturedResult = result
            onCaptured(result)
        } catch FoodCaptureError.notImplemented(let ticket, let message, _) {
            // Expected until W2-T3 wires FoodVisionService. Surface the
            // ticket in DEBUG so it's obvious during sprint runs; show
            // a graceful "give us a few hours" in Release.
            #if DEBUG
            errorMessage = "[\(ticket)] \(message)"
            #else
            errorMessage = "give us a few hours — we're catching our breath."
            #endif
            withAnimation {
                // Trigger transition; errorMessage non-nil renders the banner.
            }
        } catch {
            #if DEBUG
            errorMessage = "capture failed: \(error)"
            #else
            errorMessage = "couldn't read your plate just now. try again?"
            #endif
        }
    }
}

// MARK: - CaptureTab

private enum CaptureTab: Hashable {
    case photo
    case quickAdd
    case imOut
}

#endif  // canImport(UIKit)
