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
    /// v1.0.8 Phase H — gallery upload sheet state.
    @State private var showingLibraryPicker: Bool = false

    /// v1.0.8 Phase K — pinch-to-zoom state. `baseZoom` snapshots the
    /// zoom at the moment a pinch begins so `currentZoom = baseZoom *
    /// gestureScale` matches what the user expects (iPhone Camera
    /// semantics — pinch from current state, not from 1.0). The
    /// indicator pill auto-hides 800ms after the pinch releases.
    @State private var baseZoom: CGFloat = 1.0
    @State private var liveZoom: CGFloat = 1.0
    @State private var zoomIndicatorVisible: Bool = false
    @State private var zoomHideTask: Task<Void, Never>?

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
        // v1.0.8 Phase M (2026-06-08) — INSET CAMERA FRAME refactor.
        // Founder feedback after Phase L review: border was broken
        // (only top + bottom edges visible in full-bleed mode), and
        // founder wants the reference-app layout — camera in an inset
        // rounded rectangle with a hot pink border, big circle shutter
        // floating inside the frame, mode pills as a bottom toolbar
        // outside the frame.
        //
        // Layout structure:
        //   - Color.black backdrop (status bar + home indicator)
        //   - VStack:
        //       cameraFrame (RoundedRectangle 28pt corners, inset 12pt
        //         from horizontal edges, hot pink border, contains
        //         camera/frozen/scanning + X close + flash + big
        //         circle shutter)
        //       bottomToolbar (gallery icon left, mode chip row
        //         centered, 44pt balance spacer right)
        //
        // Border is now bounded BY the inset RoundedRectangle's frame,
        // so it can't get clipped or rendered weirdly — strokeBorder
        // draws cleanly inside a known rect.
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                cameraFrame
                    .padding(.horizontal, 12)
                    .padding(.top, 4)

                bottomToolbar
                    .padding(.horizontal, FoodTheme.Space.lg)
                    .padding(.bottom, 4)
            }
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
                    .padding(.horizontal, FoodTheme.Space.md)
                    .padding(.top, FoodTheme.Space.md)
            }
        }
        .sheet(isPresented: $showingLibraryPicker) {
            PhotoLibraryPicker(
                onPicked: { image in
                    showingLibraryPicker = false
                    Task { await libraryImagePicked(image) }
                },
                onCancel: { showingLibraryPicker = false }
            )
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: isCapturing)
    }

    // MARK: - Camera frame (inset rounded rect)

    /// v1.0.8 Phase M — the camera viewport itself. Camera content is
    /// clipped to a RoundedRectangle, the hot pink border draws on top
    /// at the same corner radius, and in-frame chrome (X, flash, big
    /// shutter) sits over the camera content with padded insets.
    @ViewBuilder private var cameraFrame: some View {
        ZStack {
            // Camera + frozen + scanning, clipped to rounded frame.
            cameraLayer
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            // Hot pink border — uniform at rest, shimmer revolves
            // during scan.
            RotatingScanBorder(
                isScanning: isCapturing && !reduceMotion,
                isError: errorMessage != nil,
                cornerRadius: 28,
                lineWidth: 5
            )

            // In-frame floating chrome: X (top-right), flash (bottom-
            // left), big circle shutter (bottom-center).
            inFrameChrome
                .padding(14)
        }
        .contentShape(Rectangle())
        .gesture(pinchZoomGesture)
    }

    // MARK: - Camera layer

    /// v1.0.8 Phase M — camera content inside the inset frame. Drops
    /// the previous `.ignoresSafeArea()`; the parent cameraFrame now
    /// handles bounds via VStack layout + horizontal padding.
    @ViewBuilder private var cameraLayer: some View {
        ZStack {
            Color.black

            if camera.permissionStatus == .authorized {
                FoodCameraPreviewView(previewLayer: camera.previewLayer)

                if let frame = camera.frozenFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fill)

                    if !reduceMotion {
                        ScanningOverlay(isActive: isCapturing)
                    }
                }
            } else if camera.permissionStatus == .denied {
                permissionDeniedPlaceholder
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
    }

    // MARK: - In-frame chrome (X / flash / big shutter)

    /// v1.0.8 Phase M — chrome that floats over the camera content
    /// inside the inset frame, mimicking the reference layout:
    ///   - X close (top-right corner)
    ///   - Zoom indicator (mid-screen during pinch, auto-hides)
    ///   - Microcopy / scan label (above shutter, crossfades)
    ///   - Flash icon (bottom-left)
    ///   - Big circle shutter (bottom-center)
    ///   - 44pt balance spacer (bottom-right)
    @ViewBuilder private var inFrameChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                glassButton(systemName: "xmark", action: onDismiss)
                    .accessibilityLabel("cancel")
            }

            Spacer()

            zoomIndicator
                .padding(.bottom, 6)

            // Microcopy ↔ scan label crossfade. Both views are always
            // mounted; opacity drives visibility so the change is a
            // smooth fade, not a hard view swap.
            ZStack {
                microcopyText
                    .opacity(isCapturing ? 0 : 1)
                ScanLabelRotator(isActive: isCapturing)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .colorScheme(.dark)
                    .opacity(isCapturing && !reduceMotion ? 1 : 0)
            }
            .frame(height: 36)
            .padding(.bottom, 14)

            HStack(alignment: .center, spacing: 0) {
                glassButton(systemName: "bolt.slash", action: { /* flash wiring later */ })
                    .accessibilityLabel("flash")
                    .opacity(0.55)

                Spacer()

                bigShutterButton

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
        }
    }

    // MARK: - Big circle shutter

    /// v1.0.8 Phase M — iOS-Camera-style big circle shutter. Hot pink
    /// outer ring, white inner disc with a soft drop shadow. During
    /// scan, the inner disc transitions to a hot pink spinner via
    /// contentTransition so the state change is a crossfade rather
    /// than a hard swap.
    @ViewBuilder private var bigShutterButton: some View {
        Button {
            guard !isCapturing else { return }
            // v1.0.8 Phase J — synchronous capture beats in the Button
            // closure so the freeze + haptic + sound land within the
            // same runloop tick as the tap.
            camera.freezeInstantly()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            AudioServicesPlaySystemSound(1108)
            Task { await captureTapped() }
        } label: {
            ZStack {
                // Outer ring: hot pink stroke.
                Circle()
                    .stroke(Color(red: 1.0, green: 0.075, blue: 0.94), lineWidth: 4)
                    .frame(width: 78, height: 78)
                // Inner disc: white when idle, shrinks slightly during
                // scan to communicate the disabled state without a
                // hard chrome change.
                Circle()
                    .fill(Color.white)
                    .frame(
                        width: isCapturing ? 56 : 64,
                        height: isCapturing ? 56 : 64
                    )
                    .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                    .animation(.easeInOut(duration: 0.3), value: isCapturing)
                if isCapturing {
                    ProgressView()
                        .tint(Color(red: 1.0, green: 0.075, blue: 0.94))
                        .transition(.opacity)
                }
            }
            .contentShape(Circle())
        }
        .disabled(isCapturing || camera.permissionStatus != .authorized || !camera.isRunning)
        .accessibilityLabel(isCapturing ? "scanning" : "scan food")
    }

    // MARK: - Bottom toolbar (outside the frame)

    /// v1.0.8 Phase M — toolbar that sits in the black area below the
    /// camera frame. Mimics the reference layout: gallery icon left,
    /// mode chip row centered, 44pt clear balance spacer right.
    @ViewBuilder private var bottomToolbar: some View {
        HStack(spacing: 0) {
            galleryButton

            Spacer()

            modeChips
                .padding(.horizontal, FoodTheme.Space.md)
                .padding(.vertical, FoodTheme.Space.sm)
                .background(.ultraThinMaterial, in: Capsule())
                .colorScheme(.dark)
                .opacity(isCapturing ? 0.5 : 1)

            Spacer()

            Color.clear.frame(width: 44, height: 44)
        }
    }

    @ViewBuilder
    private func glassButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
    }

    /// Microcopy line above the shutter when idle. "*center* your
    /// plate ♥" — italic-Fraunces on the punch word, heart as terminal
    /// punctuation per voice locks. Glass blur backing keeps it
    /// legible over any food.
    @ViewBuilder private var microcopyText: some View {
        (
            Text("")
            + Text("center")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
            + Text(" your plate ♥")
                .font(.system(size: 14))
        )
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .colorScheme(.dark)
    }

    /// Library upload entry point. Tap → PHPicker. Picker hands
    /// back a UIImage which goes through the same saliency +
    /// resize + EF pipeline as a camera capture.
    @ViewBuilder private var galleryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingLibraryPicker = true
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel("upload photo")
        .disabled(isCapturing)
    }

    // MARK: - Subviews

    /// Full-bleed permission-denied state. White copy on dark
    /// camera background.
    @ViewBuilder private var permissionDeniedPlaceholder: some View {
        VStack(spacing: FoodTheme.Space.sm) {
            Image(systemName: "camera.fill")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.7))
            Text("camera access turned off")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
            Text("enable in Settings → JeniFit")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Zoom

    /// v1.0.8 Phase K (2026-06-08) — iPhone-Camera-style pinch zoom.
    /// `baseZoom` snapshots the live zoom when the pinch begins so the
    /// scaling math is `base * gesture`, not `1.0 * gesture` — this
    /// matches what users expect from any modern camera app (pinch
    /// from where you are, not from default). On release, baseZoom
    /// catches up to wherever liveZoom ended.
    ///
    /// Pinch is disabled while a scan is in flight (the frozen frame
    /// is showing; zooming the live camera underneath would do
    /// nothing visible until the scan completes and the live preview
    /// returns).
    private var pinchZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { scale in
                guard !isCapturing else { return }
                let target = baseZoom * scale
                let clamped = max(1.0, min(target, camera.maxZoom))
                camera.setZoom(clamped)
                liveZoom = clamped
                if !zoomIndicatorVisible {
                    withAnimation(.easeOut(duration: 0.18)) {
                        zoomIndicatorVisible = true
                    }
                }
                zoomHideTask?.cancel()
            }
            .onEnded { _ in
                baseZoom = liveZoom
                zoomHideTask?.cancel()
                zoomHideTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    if Task.isCancelled { return }
                    withAnimation(.easeInOut(duration: 0.35)) {
                        zoomIndicatorVisible = false
                    }
                }
            }
    }

    /// Floating zoom indicator pill — appears on pinch, auto-hides
    /// after release. iPhone Camera shows "1.5×" mid-screen during a
    /// pinch; we use the same affordance, glass-blur backing so it
    /// reads on any food background.
    @ViewBuilder private var zoomIndicator: some View {
        if zoomIndicatorVisible {
            Text(String(format: "%.1f×", liveZoom))
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .colorScheme(.dark)
                .transition(.opacity)
        }
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

        // v1.0.8 Phase J — haptic/sound/flash/freeze moved to the Button
        // closure to fire on the same synchronous runloop tick as the
        // tap. By the time this async function runs, the user already
        // sees the frozen frame + hears the shutter + feels the haptic.
        // All this function does now is the heavyweight async work.

        FoodAnalytics.track(.scanStarted)
        FoodAnalytics.firstScanStartedIfNeeded()

        // v1.0.8 Phase G (2026-06-08) — Live Activity creation
        // moved OFF the critical path. FoodScanActivity.start runs
        // synchronously on the main actor and ActivityKit's first-
        // call cold-start can take 100-300ms on a real device.
        // Previously that ran BETWEEN the haptic and the camera
        // capture call — exactly the "lag after I tap scan" the
        // founder reported (2026-06-08).
        //
        // New pattern: kick off the capture IMMEDIATELY via async
        // let, and create the Live Activity in parallel on a
        // detached Task. The phase-rotation task awaits the handle
        // so it still fires correctly when the activity is up; the
        // capture path doesn't wait on the activity at all.
        let name = UserDefaults.standard.string(forKey: "userName") ?? ""

        // Capture runs in parallel with Live Activity setup. The
        // preview-layer snapshot inside captureStillAndFreeze() lands
        // on the main actor within ~15ms of tap (synchronous render)
        // BEFORE the async chain awaits anything else — so the user
        // sees the viewfinder freeze even while ActivityKit is still
        // bootstrapping in the background.
        async let pendingJpeg: Data = camera.captureStillAndFreeze()

        // Live Activity bootstrap on a detached Task. Its first-call
        // cold-start (100-300ms on iPhone 13 Pro Max for the founder)
        // no longer blocks the camera capture path.
        let activityHandle: Any? = await Task.detached {
            await FoodScanActivity.start(displayName: name)
        }.value

        // Phase-rotation timer. Pacing rebalanced 2026-06-07: "looking"
        // (0-4s) → "matching" (4-10s) → "tallying" (10s+). On a fast
        // scan the success path advances to "ready" before either tick
        // (catch-block-side update).
        let phaseTask: Task<Void, Never>? = activityHandle == nil ? nil : Task.detached {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "matching")
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "tallying")
        }

        do {
            // v1.0.7 in-viewfinder magic — captureStillAndFreeze
            // publishes the decoded photo into camera.frozenFrame so
            // the SwiftUI overlay can paint it inside the viewfinder
            // while the ScanningOverlay animates on top. No
            // FoodProcessingView takeover, no preview restart.
            //
            // v1.0.8 Phase G — the actual JPEG came from the parallel
            // capture started above, so this await just collects its
            // result instead of starting fresh work.
            let jpeg = try await pendingJpeg
            // v1.0.8 Phase B — silent auto-retry on transient errors.
            // The dispatch helper handles up to 2 retries with 0.5s
            // / 1s backoff on .networkError, .upstreamFailure(5xx),
            // and .parseError. Permanent errors (rate-limited,
            // invalid request, budget cap) throw immediately. The
            // user sees a single "scanning…" state for the whole
            // retry chain instead of seeing a flash of "couldn't
            // reach us" between attempts. Founder's iced-latte
            // 4-attempt loop was almost entirely transient errors
            // (cafe wifi blips + EF cold-starts) — this turns that
            // into a single perceived scan.
            let result = try await dispatchPhotoWithRetry(jpeg)

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

    /// v1.0.8 Phase H — gallery upload handler. PHPicker returns a
    /// UIImage; we run it through `FoodCameraManager.processUIImageForScan`
    /// (same saliency + resize + JPEG-encode pipeline as a camera
    /// capture) and dispatch to the same EF endpoint. Result lands
    /// in the same polaroid develop-in flow with the user's picked
    /// image as the hero.
    ///
    /// Duplicates some scaffolding from captureTapped (Live Activity,
    /// retry helper, error handling) but the two paths are
    /// intentionally distinct so the camera path stays optimized for
    /// instant snap while the upload path skips the camera-specific
    /// parts (haptic, shutter sound, debounce timestamp).
    private func libraryImagePicked(_ image: UIImage) async {
        guard !isCapturing else { return }
        isCapturing = true
        errorMessage = nil
        defer { isCapturing = false }

        FoodAnalytics.track(.scanStarted)
        FoodAnalytics.firstScanStartedIfNeeded()

        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        let activityHandle: Any? = await Task.detached {
            await FoodScanActivity.start(displayName: name)
        }.value
        let phaseTask: Task<Void, Never>? = activityHandle == nil ? nil : Task.detached {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "matching")
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "tallying")
        }

        do {
            let jpeg = try await camera.processUIImageForScan(image)
            let result = try await dispatchPhotoWithRetry(jpeg)

            let noFood = result.items.isEmpty
                && (result.kcalLow == nil || result.kcalLow == 0)
            if noFood {
                errorMessage = "didn't see food in that one. try a closer angle or more light?"
                FoodAnalytics.track(.scanFallbackFired, properties: ["reason": "empty_items", "source": "library"])
                phaseTask?.cancel()
                FoodScanActivity.end(handle: activityHandle)
                withAnimation(.easeOut(duration: 0.25)) {
                    camera.clearFrozenFrame()
                }
                return
            }

            FoodAnalytics.track(.scanCompleted, properties: [
                "items_count": result.items.count,
                "has_restaurant_range": result.kcalLow != nil,
                "source": "library",
            ])
            FoodAnalytics.firstScanCompletedIfNeeded()

            phaseTask?.cancel()
            Task.detached {
                await FoodScanActivity.update(handle: activityHandle, phase: "ready")
                try? await Task.sleep(nanoseconds: 700_000_000)
                await FoodScanActivity.end(handle: activityHandle)
            }

            capturedResult = result
            onCaptured(result, camera.frozenFrame)
        } catch let captureError as FoodCaptureError {
            #if DEBUG
            print("[PhotoCaptureView] library capture failed: \(captureError)")
            #endif
            errorMessage = captureError.errorDescription
                ?? "couldn't read your plate just now. try again?"
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "capture_error",
                "source": "library",
                "case": String(describing: captureError),
            ])
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) {
                camera.clearFrozenFrame()
            }
        } catch {
            #if DEBUG
            print("[PhotoCaptureView] library capture failed (unknown): \(error)")
            #endif
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "couldn't read your plate just now. try again?"
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "capture_error",
                "source": "library",
            ])
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) {
                camera.clearFrozenFrame()
            }
        }
    }

    // MARK: - Retry

    /// v1.0.8 Phase B — silent auto-retry wrapper around the dispatcher.
    /// Tries up to 3 times (initial + 2 retries), with 0s / 0.5s / 1s
    /// pre-attempt sleep. Only transient errors trigger a retry;
    /// permanent errors (rate limit, invalid request, budget cap,
    /// not authenticated) throw on the first failure so the user
    /// isn't kept waiting on something that won't succeed.
    ///
    /// The retries are SILENT — no banner, no haptic, no analytics
    /// "error" event per attempt. A single `scan_retry_attempted`
    /// telemetry event fires per retry so PostHog can show how often
    /// the retry layer saves a scan. The result-or-throw outcome
    /// reaches captureTapped's catch arms unchanged from the user's
    /// perspective.
    private func dispatchPhotoWithRetry(_ jpeg: Data) async throws -> CapturedFood {
        let backoffsNs: [UInt64] = [0, 500_000_000, 1_000_000_000]
        var lastError: Error?
        for (attempt, backoff) in backoffsNs.enumerated() {
            if backoff > 0 {
                try? await Task.sleep(nanoseconds: backoff)
            }
            do {
                return try await dispatcher.dispatch(.photo(jpeg))
            } catch {
                lastError = error
                guard Self.isTransient(error) else {
                    throw error
                }
                #if DEBUG
                print("[PhotoCaptureView] transient retry \(attempt + 1)/\(backoffsNs.count - 1): \(error)")
                #endif
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "transient_retry",
                    "attempt": attempt + 1,
                    "case": String(describing: error),
                ])
            }
        }
        throw lastError ?? FoodCaptureError.invalidInput(reason: "exhausted retries")
    }

    /// Classifies a dispatcher error as transient (retryable) vs
    /// permanent. Transient: network blips, server 5xx, parse errors
    /// (sometimes a partial response that succeeds on second attempt).
    /// Permanent: rate limits, budget caps, invalid input, auth.
    private static func isTransient(_ error: Error) -> Bool {
        guard let cap = error as? FoodCaptureError,
              case .pipeline(let underlying) = cap,
              let vision = underlying as? VisionError else {
            return false
        }
        switch vision {
        case .networkError, .parseError:
            return true
        case .upstreamFailure(let status, _, _):
            return (500...599).contains(status)
        case .rateLimited, .budgetCapped, .invalidRequest, .notAuthenticated:
            return false
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
