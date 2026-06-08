#if canImport(UIKit)
import SwiftUI
import AVFoundation
import AudioToolbox

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let onDismiss: () -> Void
    public let onCaptured: (CapturedFood, UIImage?) -> Void
    public let onQuickAddTapped: () -> Void
    public let onImOutTapped: () -> Void

    // MARK: - Init

    public init(
        onDismiss: @escaping () -> Void,
        onCaptured: @escaping (CapturedFood, UIImage?) -> Void,
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
                Spacer(minLength: FoodTheme.Space.sm)
                // v1.0.7 — italic-Fraunces label rotator under the
                // viewfinder during the scan. The user reads
                // "*reading* your plate" → "*finding* ingredients" →
                // "*tallying* portions" in sync with the scanline
                // sweep above. Static empty slot when idle so layout
                // doesn't shift on first capture.
                ZStack {
                    if isCapturing && !reduceMotion {
                        ScanLabelRotator(isActive: isCapturing)
                    }
                }
                .frame(height: 22)
                .padding(.bottom, FoodTheme.Space.sm)
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
        // v1.0.7 — full-screen FoodProcessingView removed. The scan
        // now runs INSIDE the viewfinder on top of the frozen still
        // (ScanningOverlay) with an italic-Fraunces label rotator
        // below. Apple 5.1.2(i) AI-transparency disclosure stays on
        // the FoodAIConsentSheet (one-time, before first scan); the
        // ongoing per-scan transparency lives in the label rotator
        // reading "*reading* your plate / *finding* ingredients /
        // *tallying* portions" — same legibility, no spatial-context
        // loss.
        .animation(.easeInOut(duration: 0.2), value: isCapturing)
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
        // 2026-06-06 layout fix: GeometryReader pins the inner content
        // (preview layer + frozen Image + ScanningOverlay) to the
        // viewfinder's actual bounds. Without this, the Image's
        // intrinsic photo dimensions propagate up the layout pass and
        // the surrounding VStack reshuffles when frozenFrame appears,
        // visibly growing the box mid-scan.
        GeometryReader { geo in
            ZStack {
                if camera.permissionStatus == .authorized {
                    FoodCameraPreviewView(previewLayer: camera.previewLayer)
                        .frame(width: geo.size.width, height: geo.size.height)

                    // v1.0.7 in-viewfinder scan magic. The decoded photo
                    // paints on top of the still-running preview layer
                    // (no preview stop, no flicker). The breathing-
                    // aperture scale (1.0 → 1.012) per the iOS Swift
                    // brief makes the plate feel "alive" instead of
                    // frozen — almost subliminal.
                    if let frame = camera.frozenFrame {
                        Image(uiImage: frame)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .scaleEffect(isCapturing && !reduceMotion ? 1.012 : 1.0)
                            .animation(
                                .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                                value: isCapturing
                            )
                            .transition(.opacity.animation(.linear(duration: 0.08)))

                        if !reduceMotion {
                            ScanningOverlay(isActive: isCapturing)
                                .frame(width: geo.size.width, height: geo.size.height)
                        }
                    }
                } else if camera.permissionStatus == .denied {
                    permissionDeniedPlaceholder
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView()
                        .tint(FoodTheme.accent)
                        .frame(width: geo.size.width, height: geo.size.height)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
            .overlay(
                // Scrapbook frame chrome — 1.5pt cocoa border per v5
                // lock. During the scan, the stroke pulses 1.5 → 2.0pt
                // on the same 1.6s breathing token as the aperture
                // scale so the chrome feels alive in sync with the
                // photo. Subliminal — under 0.5pt swing.
                RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                    .stroke(
                        FoodTheme.textPrimary,
                        lineWidth: (isCapturing && !reduceMotion) ? 2.0 : FoodTheme.Stroke.scrapbook
                    )
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: isCapturing
                    )
            )
            .shadow(color: FoodTheme.textPrimary.opacity(0.25), radius: 0, x: 3, y: 3)
        }
        .frame(maxWidth: .infinity, minHeight: 320, maxHeight: .infinity)
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

    /// Constrained, tap-to-dismiss error card. Replaces the v1
    /// Capsule banner which expanded into a giant cocoa blob when the
    /// DEBUG message was long (full URLSession error dump). Now caps
    /// at 3 visible lines with a "tap to dismiss" affordance; long
    /// DEBUG content scrolls inside.
    @ViewBuilder
    private func errorBanner(_ message: String) -> some View {
        Button {
            withAnimation(.easeOut(duration: 0.22)) {
                errorMessage = nil
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(FoodTheme.bgPrimary.opacity(0.9))
                ScrollView {
                    Text(message)
                        .font(.system(size: 12))
                        .foregroundStyle(FoodTheme.bgPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: 72)
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(FoodTheme.bgPrimary.opacity(0.7))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(FoodTheme.textPrimary)
            )
            .shadow(color: FoodTheme.textPrimary.opacity(0.3), radius: 0, x: 3, y: 3)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, FoodTheme.Space.md)
        .padding(.top, 60)
        .transition(.move(edge: .top).combined(with: .opacity))
        .accessibilityLabel("error: \(message). tap to dismiss.")
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

        // v1.0.8 Phase A (2026-06-07) — fire haptic + system shutter
        // sound BEFORE any await. SwiftUI Button actions fire on tap-up,
        // so the user has just lifted their finger; the perceived
        // "instant capture" relies on these two signals landing within
        // ~16ms of the up-touch. Apple's system shutter sound (1108)
        // is what iPhone Camera uses — same audio fingerprint the
        // cohort already pattern-matches as "got the shot."
        //
        // Without this, the resize/encode + AVFoundation callback chain
        // could feel like a 2-3s lag before any feedback landed,
        // forcing users to keep holding the phone steady.
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        AudioServicesPlaySystemSound(1108)

        FoodAnalytics.track(.scanStarted)
        FoodAnalytics.firstScanStartedIfNeeded()

        // v1.0.7 Phase F — Dynamic Island Live Activity. Starts on
        // scan begin, runs through phase rotations driven by a
        // detached Task, ends on success or failure. Uses opaque
        // Any? handle so PlankFood stays ActivityKit-blind; the main
        // app's closure (registered in PlankAIApp.swift) holds the
        // real Activity instance.
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let activityHandle = FoodScanActivity.start(displayName: name)
        let phaseTask: Task<Void, Never>? = activityHandle == nil ? nil : Task.detached {
            try? await Task.sleep(nanoseconds: 700_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "matching")
            try? await Task.sleep(nanoseconds: 700_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "tallying")
        }

        do {
            // v1.0.7 in-viewfinder magic — captureStillAndFreeze
            // publishes the decoded photo into camera.frozenFrame so
            // the SwiftUI overlay can paint it inside the viewfinder
            // while the ScanningOverlay animates on top. No
            // FoodProcessingView takeover, no preview restart.
            let jpeg = try await camera.captureStillAndFreeze()
            let result = try await dispatcher.dispatch(.photo(jpeg))

            // Empty-identification guard: LLM returned 200 but with no
            // items AND no restaurant-range fallback. Common causes: no
            // food in frame, severe blur, dark scene. Stay on camera
            // with a friendly retry banner rather than advancing to a
            // phantom result card (founder bug 2026-06-05 — user saw
            // a card with only "log it" + "actually skip" because every
            // content branch was `if let item = food.items.first` and
            // items was empty).
            // v1.0.7 direct-kcal rewrite (2026-06-07): the new EF
            // schema returns total_kcal_low / total_kcal_high as
            // required Int fields, so empty-items scans now arrive
            // with kcalLow = 0.0 instead of nil. The previous
            // `kcalLow == nil` predicate stopped firing for that case
            // and the empty result card rendered instead of the
            // friendly "no food in frame" banner. Loosen to also
            // match kcalLow == 0, which is the actual signature of a
            // non-food image under the direct-kcal schema. The
            // restaurant-range path always sets non-zero kcalLow so
            // it stays unaffected.
            let noFood = result.items.isEmpty
                && (result.kcalLow == nil || result.kcalLow == 0)
            if noFood {
                errorMessage = "didn't see food in that one. try a closer angle or more light?"
                FoodAnalytics.track(.scanFallbackFired, properties: ["reason": "empty_items"])
                phaseTask?.cancel()
                FoodScanActivity.end(handle: activityHandle)
                // 2026-06-06 — release the frozen photo so the live
                // preview comes back. Without this the still keeps
                // covering the camera and the user can't reframe
                // until they tap shutter again (which captures the
                // SAME bad photo).
                withAnimation(.easeOut(duration: 0.25)) {
                    camera.clearFrozenFrame()
                }
                // v1.0.8 — clear the debounce so the user can re-tap
                // immediately after reframing. Without this, the 3s
                // post-completion debounce kept the shutter disabled
                // and the founder's "tap → no food → reframe → tap"
                // loop required a 3-second wait between attempts.
                camera.recordCaptureFailed()
                return
            }

            FoodAnalytics.track(.scanCompleted, properties: [
                "items_count": result.items.count,
                "has_restaurant_range": result.kcalLow != nil,
            ])
            FoodAnalytics.firstScanCompletedIfNeeded()

            // End the Live Activity with a brief "ready ♥" beat
            // before tearing down so the system pill registers the
            // success state visibly. Detached so it doesn't block
            // the main-thread transition into the result phase.
            phaseTask?.cancel()
            Task.detached {
                await FoodScanActivity.update(handle: activityHandle, phase: "ready")
                try? await Task.sleep(nanoseconds: 700_000_000)
                await FoodScanActivity.end(handle: activityHandle)
            }

            capturedResult = result
            // v1.0.7 — pass the frozen photo to the result phase so it
            // can scaffold the photo as a Polaroid hero with
            // matchedGeometryEffect from the viewfinder bounds.
            onCaptured(result, camera.frozenFrame)
        } catch CameraError.captureTooSoon {
            // v1.0.7 — silently ignore back-to-back shutter taps
            // within the 3s debounce window. No banner, no telemetry
            // event (would spam PostHog). The user's next intentional
            // tap will work normally.
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) {
                camera.clearFrozenFrame()
            }
            return
        } catch FoodCaptureError.notImplemented(let ticket, let message, _) {
            // Expected until W2-T3 wires FoodVisionService. Surface the
            // ticket in DEBUG so it's obvious during sprint runs; show
            // a graceful "give us a few hours" in Release.
            #if DEBUG
            errorMessage = "[\(ticket)] \(message)"
            #else
            errorMessage = "give us a few hours — we're catching our breath."
            #endif
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) {
                camera.clearFrozenFrame()
            }
            // v1.0.8 — clear debounce so retry isn't blocked.
            camera.recordCaptureFailed()
        } catch let captureError as FoodCaptureError {
            // v1.0.7 (2026-06-07) — pipeline / invalidInput paths.
            // FoodCaptureError.errorDescription unwraps to the
            // VisionError.userFacingCopy when present, so a 502 from
            // the food-vision EF or a timeout from URLSession both
            // surface as voice-locked friendly copy instead of the
            // raw "PlankFood.FoodCaptureError error 2" leak the
            // founder saw on a non-food image scan.
            #if DEBUG
            print("[PhotoCaptureView] capture failed: \(captureError)")
            #endif
            errorMessage = captureError.errorDescription
                ?? "couldn't read your plate just now. try again?"
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "capture_error",
                "case": String(describing: captureError),
            ])
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            // v1.0.8 — restore live preview + clear debounce so the
            // next intentional tap on cafe wifi blips goes through
            // immediately. Founder's iced-latte 4-attempt loop was
            // mostly bottlenecked by this 3s wait.
            withAnimation(.easeOut(duration: 0.25)) {
                camera.clearFrozenFrame()
            }
            camera.recordCaptureFailed()
        } catch {
            // Truly unexpected (non-FoodCaptureError, non-CameraError).
            // Use the system localizedDescription — both VisionError
            // and FoodCaptureError now conform to LocalizedError so
            // this only fires for genuinely unknown error types.
            let ns = error as NSError
            #if DEBUG
            print("[PhotoCaptureView] capture failed (unknown): \(error)")
            #endif
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "couldn't read your plate just now. try again?"
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "capture_error",
                "ns_error_code": ns.code,
            ])
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) {
                camera.clearFrozenFrame()
            }
            camera.recordCaptureFailed()
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
