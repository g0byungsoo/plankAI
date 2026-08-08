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
    /// v2.8 — account scoping for the "today's protein" context
    /// (the unscoped read summed every account on the device).
    public var userId: String = ""

    // MARK: - State

    @State private var camera = FoodCameraManager()
    @State private var dispatcher = FoodCaptureDispatcher()

    @State private var captureTab: CaptureTab = .photo
    @State private var isCapturing: Bool = false
    @State private var capturedResult: CapturedFood?
    @State private var errorMessage: String?

    /// 2026-06-23 — premium failure/retry state. A failed or timed-out
    /// scan routes HERE (a gentle cream card over the frozen photo with
    /// a clear "try again"), not to an indefinite spinner or a terse top
    /// banner. The frozen photo is kept so "try again" reuses the shot.
    @State private var scanFailure: ScanFailure?
    /// 2026-06-23 — flips true ~9s into a slow-but-not-failed scan to
    /// soften the in-flight copy ("still with you") before the hard
    /// deadline. Cancelled the moment the scan resolves.
    @State private var longScan: Bool = false
    /// Tracks the slow-scan nudge timer so it can be cancelled on resolve.
    @State private var longScanTask: Task<Void, Never>?
    /// v1.0.8 Phase H — gallery upload sheet state.
    @State private var showingLibraryPicker: Bool = false

    /// v1.0.8 Phase K — pinch-to-zoom state. `baseZoom` snapshots the
    /// zoom at the moment a pinch begins so `currentZoom = baseZoom *
    /// gestureScale` matches what the user expects (iPhone Camera
    /// semantics — pinch from current state, not from 1.0). The
    /// indicator pill auto-hides 800ms after the pinch releases.
    /// v1.0.9 D2 — subtle 6s scale 1.0 ↔ 1.02 breathe on the shutter
    /// when nothing's happening. Started in onAppear with a repeating
    /// withAnimation. Reduce-motion users get a static shutter.
    @State private var shutterBreathing: Bool = false

    /// v1.0.9 D2 polish round 3 (2026-06-08) — Canvas Metal-pipeline
    /// prewarm. Founder feedback: "the lag is happening in the first
    /// attempt and there is less lag from the second try." Classic
    /// cold-start signature.
    ///
    /// Root cause: `ScanningOverlay`'s `TimelineView { Canvas { ... } }`
    /// triggers a Metal shader compile + driver registration the first
    /// time `isActive` flips false → true. That's a one-time 40-80ms
    /// hit visible as "delay before scan line appears" on the first
    /// scan only. Subsequent scans run the cached pipeline and feel
    /// instant.
    ///
    /// Fix: mount an invisible 1×1 ScanningOverlay during the first
    /// 200ms after view appear, driven by this flag (starts true,
    /// flipped false after a brief warmup window inside .task). The
    /// 1×1 size makes the GPU work trivially cheap, but the Metal
    /// pipeline compile still happens — so the first real tap finds
    /// the pipeline already cached. User never sees the prewarm
    /// (opacity 0, 1×1, accessibility-hidden).
    @State private var prewarmingScanCanvas: Bool = true

    /// v1.0.9 D2 polish (2026-06-08) — pre-warmed Taptic Engine
    /// generator for the shutter tap. Founder feedback: "the lag is
    /// happening right after i click the scan button." Each time you
    /// instantiate UIImpactFeedbackGenerator and call .impactOccurred(),
    /// the Taptic Engine cold-starts (~30-50ms). Holding a single
    /// generator and calling .prepare() in onAppear keeps the engine
    /// warm so the impact fires on the very next runloop tick after
    /// tap. After firing we re-prepare so a follow-up scan is also
    /// instant. UIFeedbackGenerator is main-actor-bound, matching this
    /// view.
    @State private var shutterHaptic = UIImpactFeedbackGenerator(style: .medium)

    /// 2026-06-24 — gentle haptic that pulses while scanning, synced to
    /// the laser-sweep cadence (~2.2s). Founder: "while scanning can you
    /// do some haptic?" A soft "still reading" tap under the visual sweep.
    @State private var scanHaptic = UIImpactFeedbackGenerator(style: .soft)
    @State private var scanHapticTask: Task<Void, Never>?

    /// v1.2 — capture bloom flash. Flipped true synchronously in the
    /// shutter closure (same render as the freeze) and released ~80ms
    /// later with a 300ms ease-out, so the flash reads as the exposure
    /// moment, not a UI animation. Skipped under reduce-motion.
    @State private var captureFlash: Bool = false

    @State private var baseZoom: CGFloat = 1.0
    @State private var liveZoom: CGFloat = 1.0
    @State private var zoomIndicatorVisible: Bool = false
    @State private var zoomHideTask: Task<Void, Never>?

    /// v1.2 snap-food rebuild (2026-07-01) — result-stage state. When a
    /// scan lands, the letterboxed camera frame swaps for a full-bleed
    /// photo + the SnapResultView carousel. `photoSettled` drives the
    /// ken-burns settle (1.07 → 1.0) on arrival; `resultPage` is the
    /// carousel slide (0 plate · 1 note · 2 share composer) — host-owned
    /// so the floating chrome swaps with it; the rendered PNG hands
    /// off to the system share sheet.
    @State private var resultPage: Int = 0
    @State private var photoSettled: Bool = false
    @State private var showShareActivity: Bool = false
    @State private var shareRenderedImage: UIImage?

    /// v1.0.19 (2026-06-18) — drives the 540ms-delayed fade-in of
    /// the her75 "a moment..." italic Fraunces line in the cream
    /// space below the viewfinder during the vision API window.


    /// v1.0.8 Phase R.5 — gallery-upload photo. When the user picks
    /// from the photo library, this UIImage replaces the live preview
    /// as the camera content so the scan + result phase behave identical
    /// to the camera path. nil during live camera mode.
    @State private var galleryImage: UIImage?

    /// v1.0.8 Phase R.7 (2026-06-08) — gallery preview-confirm step.
    /// True while showing the picked photo with "use this photo" /
    /// "cancel" CTAs.
    @State private var galleryPreviewMode: Bool = false

    /// v1.0.8 Phase S (2026-06-08) — dedicated UI state for terminal
    /// errors (rate limit / budget cap). Triggers a prominent
    /// "you've hit your daily limit" overlay instead of the
    /// transient error banner. Founder ask: "we need to do better
    /// error handling too. like we can inform user about the daily
    /// limit when they hit this problem."
    @State private var terminalError: TerminalError?

    /// v1.0.8 Phase R.10 (2026-06-08) — PROOF-OF-LIFE confirm sheet.
    /// Founder repeatedly hits a "scan starts instantly + kicked back
    /// to home" pattern despite the inline preview chrome being in
    /// place. Suspicion: SwiftUI state-batching is somehow bypassing
    /// the inline preview state on their device.
    ///
    /// Switching to `.sheet(item:)` on this wrapper: SwiftUI cannot
    /// present a scan + dismiss the food rail without first
    /// dismissing the sheet, and the sheet only dismisses on explicit
    /// "use this photo" / "cancel" tap. Hard barrier — scan literally
    /// CANNOT fire until the user confirms.
    @State private var pendingGalleryImage: PendingGallery?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public let onDismiss: () -> Void
    public let onCaptured: (CapturedFood, UIImage?) -> Void

    /// v1.0.21 (2026-06-18) — fired the moment a scan result lands
    /// (before the user taps "log it"). Hosts wire this to drive
    /// the post-snap Lottie wow moment that lives at the
    /// CaptureFlowView layer (Lottie is a main-app dependency, not
    /// a PlankFood one). Defaults to a no-op so existing call sites
    /// don't change.
    public var onResultLanded: () -> Void = {}
    public let onQuickAddTapped: () -> Void
    public let onImOutTapped: () -> Void
    /// v1.2 — "again" mode chip. Host presents RecentMealsSheet (it
    /// owns the userId + persistence context this view doesn't have).
    public var onAgainTapped: () -> Void = {}

    // MARK: - Init

    public init(
        userId: String = "",
        onDismiss: @escaping () -> Void,
        onCaptured: @escaping (CapturedFood, UIImage?) -> Void,
        onQuickAddTapped: @escaping () -> Void = {},
        onImOutTapped: @escaping () -> Void = {},
        onResultLanded: @escaping () -> Void = {},
        onAgainTapped: @escaping () -> Void = {}
    ) {
        self.userId = userId
        self.onDismiss = onDismiss
        self.onCaptured = onCaptured
        self.onQuickAddTapped = onQuickAddTapped
        self.onImOutTapped = onImOutTapped
        self.onResultLanded = onResultLanded
        self.onAgainTapped = onAgainTapped
    }

    // MARK: - Body

    // MARK: - Scan deadline tuning
    //
    // The hard ceiling (backstop) + the reassurance nudge timing.
    // 2026-06-24 — raised to 90s after PostHog showed the 45s ceiling +
    // 30s URLSession were FAILING real scans with `-1001 request timed
    // out`: the currently-deployed EF is slow (cold start + sequential
    // Supabase limit queries + gpt-4o's 90s OpenAI abort), so a real scan
    // regularly needs 30-60s. The 30s/45s combo cut those off ("it used
    // to work"). Now the network timeout (80s) is the real bound and this
    // 90s watchdog sits just above it as the backstop. The literal
    // forever-hang is fixed at its source (the camera continuation), so a
    // generous network ceiling is safe. Nudge stays 15s for the slow tail.
    // Once the optimized EF is deployed (fast), drop these to ~30/35.
    // DEBUG can override via `--food-debug-deadline N` for fast sim QA.
    private static let scanLongHintSeconds: Double = 15
    private var scanDeadlineSeconds: Double {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "--food-debug-deadline"),
           i + 1 < args.count, let n = Double(args[i + 1]) {
            return n
        }
        #endif
        return 90
    }

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
            // v1.1 capture spec (2026-06-11): the SURROUND goes cream —
            // the camera reads as a polaroid being composed on the
            // desk, continuous with the rest of the app (and with the
            // PolaroidHero morph that follows). The frame INTERIOR
            // stays dark (functional letterbox/exposure floor) — the
            // only intentional black left in the flow.
            FoodTheme.bgPrimary.ignoresSafeArea()

            // v1.0.9 D2 polish round 3 — invisible 1×1 sweep prewarm.
            // See `prewarmingScanCanvas` doc comment. Compiles the
            // snapSweep Metal pipeline during the first 200ms after
            // appear so the user's first real scan tap doesn't pay the
            // cold-start cost.
            SnapSweepOverlay(isActive: prewarmingScanCanvas)
                .frame(width: 1, height: 1)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // v1.0.8 Phase R.12 (2026-06-08) — frame size is now EXPLICITLY
            // computed via GeometryReader, not derived from .aspectRatio.
            // The .aspectRatio approach was being bypassed (photo extended
            // beyond the inset bounds when galleryImage was set). Now we
            // compute exact pixel dimensions and force them with
            // .frame(width:height:) — no SwiftUI layout slack possible.
            //
            // Math:
            //   - Reserve ~100pt at the bottom for the toolbar + safe area
            //   - Available height = geo.height - 100pt
            //   - Available width  = geo.width  - 24pt (12pt left/right)
            //   - Frame is the LARGER 9:16 rect that fits in both
            //   - Photo gets .clipped() so it can't escape under any modifier
            // v1.2 snap-food rebuild — two stages. Capture keeps the
            // letterboxed polaroid frame; a landed result promotes the
            // photo to full bleed with the SnapResultView panel rising
            // over it. The cross-dissolve between stages reads seamless
            // because the photo CONTENT is identical pixels.
            if let result = capturedResult {
                resultStage(result)
                    .transition(.opacity)
            } else {
                GeometryReader { geo in
                    let availableHeight = max(0, geo.size.height - 100)
                    let availableWidth = max(0, geo.size.width - 24)
                    let widthFromHeight = availableHeight * 9.0 / 16.0
                    let frameWidth = min(availableWidth, widthFromHeight)
                    let frameHeight = frameWidth * 16.0 / 9.0

                    VStack(spacing: 14) {
                        cameraFrame
                            .frame(width: frameWidth, height: frameHeight)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity)

                        // v1.0.19 (2026-06-18) — her75 wait beat. During
                        // the vision API window the cream space below the
                        // viewfinder carries a single italic Fraunces line
                        // — the editorial-magazine pause between question
                        // and answer. Sits with the existing in-frame
                        // ScanLabelRotator (which gives more verbose
                        // info) so the cream surround has its own quieter
                        // tell of "we're working on it."
                        aMomentLine
                            .padding(.top, 12)

                        Spacer(minLength: 0)

                        bottomToolbar
                            .padding(.horizontal, FoodTheme.Space.lg)
                            .padding(.bottom, 4)
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.38), value: capturedResult != nil)
        // v1.2 — result-land beat lives at the stage-swap level now (the
        // camera frame unmounts on result, so it can't carry the observer).
        // Soft haptic + the host's Lottie hook, exactly once per landing.
        .onChange(of: capturedResult != nil) { _, hasResult in
            if hasResult {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                onResultLanded()
            } else {
                resultPage = 0
                photoSettled = false
            }
        }
        .task {
            await bootCamera()
            // v1.0.9 D2 polish round 3 — close the Canvas prewarm
            // window. By now SwiftUI has rendered ≥10 frames with
            // the invisible 1×1 ScanningOverlay active, so its Metal
            // pipeline + TimelineView driver are compiled and cached.
            // Flipping to false pauses the TimelineView (zero ongoing
            // cost). Wrapped in Task.sleep so the prewarm actually
            // gets multiple render frames even on fast cold-launch
            // before bootCamera resolves.
            try? await Task.sleep(nanoseconds: 200_000_000)
            prewarmingScanCanvas = false

            #if DEBUG
            // Simulator QA: auto-run a scan on a mock image so the
            // scanning state + the deadline/failure card can be verified
            // without a camera or any taps. Pair with --food-debug-hang /
            // --food-debug-empty / --food-debug-deadline N etc.
            // `--food-debug-gallery-confirm` instead presents the gallery
            // "use this photo?" sheet for screenshot capture.
            if ProcessInfo.processInfo.arguments.contains("--food-debug-gallery-confirm") {
                try? await Task.sleep(nanoseconds: 400_000_000)
                pendingGalleryImage = PendingGallery(image: Self.debugMockImage())
            } else if ProcessInfo.processInfo.arguments.contains("--food-debug-autostart") {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await libraryImagePicked(Self.debugMockImage())
            }
            #endif
        }
        .onDisappear {
            camera.unfreezePreview()
            camera.stopSession()
            stopScanHaptics()
        }
        // 2026-06-24 — gentle haptic pulse while scanning (founder ask).
        .onChange(of: isCapturing) { _, scanning in
            if scanning { startScanHaptics() } else { stopScanHaptics() }
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
                    // v1.0.8 Phase U.2 (2026-06-08) — bumped 350ms →
                    // 600ms to give first-launch PHPicker dismissal
                    // animation extra room. PHPicker no longer self-
                    // dismisses (see PhotoLibraryPicker.swift) so the
                    // dismiss is fully SwiftUI-driven; this delay
                    // covers the iOS sheet dismissal animation
                    // (~300ms typical, up to 500ms cold).
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 600_000_000)
                        pendingGalleryImage = PendingGallery(image: image)
                    }
                },
                onCancel: { showingLibraryPicker = false }
            )
        }
        .sheet(item: $pendingGalleryImage) { pending in
            GalleryConfirmSheet(
                image: pending.image,
                onConfirm: {
                    let img = pending.image
                    pendingGalleryImage = nil
                    Task { await libraryImagePicked(img) }
                },
                onCancel: {
                    pendingGalleryImage = nil
                }
            )
        }
        // (preferredColorScheme(.dark) removed with the cream surround —
        // status bar text reads cocoa-on-cream like every other screen.)
        .animation(.easeInOut(duration: 0.35), value: isCapturing)
        // v1.0.8 Phase S — terminal-error sheet. Rate limit / budget
        // cap → dedicated UI instead of vague banner.
        .sheet(item: $terminalError) { err in
            TerminalErrorSheet(error: err, onDismiss: {
                terminalError = nil
                camera.unfreezePreview()
                galleryImage = nil
            })
            .presentationDetents([.medium])
        }
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

            // Dusty-rose border — uniform at rest, a soft light travels
            // it during scan (no neon, no color hop). v1.2: 3pt → 2pt.
            // Against the cream surround the 3pt frame was the loudest
            // element on screen; 2pt keeps the scan-mode signal while
            // letting the plate be the subject (Chanel-counter weight).
            RotatingScanBorder(
                isScanning: isCapturing && !reduceMotion,
                cornerRadius: 28,
                lineWidth: 2
            )

            // v1.0.8 Phase P/R.7 — three in-frame states:
            //   1. preview-confirm (gallery photo just picked, awaiting
            //      "use this photo" tap)
            //   2. result (scan complete, carousel + log/skip/share)
            //   3. capture (live camera, X + flash + shutter)
            if galleryPreviewMode {
                galleryPreviewChrome
                    .padding(14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else if let failure = scanFailure {
                // Gentle failure/retry card over the kept (dimmed) photo.
                // Handles its own scrim + inset, so no outer padding.
                scanFailureOverlay(failure)
                    .transition(.opacity)
            } else {
                inFrameChrome
                    .padding(14)
            }

            // v1.2 — the idle cherries sticker was retired. Stickers are
            // reserved for the 3 earned moments (welcome / plan reveal /
            // graduation); an idle camera is not one, and the sticker was
            // one of three accents competing on this screen. The camera
            // now holds a single accent: the rose frame.
        }
        .contentShape(Rectangle())
        .gesture(pinchZoomGesture)
        .animation(.easeInOut(duration: 0.3), value: galleryPreviewMode)
    }

    // MARK: - Camera layer

    /// v1.0.8 Phase N — camera content inside the inset frame.
    /// Founder feedback on Phase M: "i don't know why it magnified
    /// the photo and layout after clicking scan. can you keep
    /// everything as same just revolving borderline + revolving
    /// camera button?"
    ///
    /// Root cause: the frozen-frame UIImage from VideoDataOutput's
    /// pixel buffer was displayed with `.aspectRatio(.fill)` while
    /// the AVCaptureVideoPreviewLayer rendered via Metal — small
    /// differences in their effective aspect handling produced a
    /// visible "zoom" on swap. Fix: drop the Image overlay entirely.
    /// The live preview keeps running during the scan, the scanning
    /// overlay draws on TOP of live video, and `camera.frozenFrame`
    /// is still captured under the hood for the downstream result-
    /// phase polaroid. The user sees zero geometry change after tap —
    /// only the border shimmer + revolving shutter signal that a
    /// scan is in flight.
    @ViewBuilder private var cameraLayer: some View {
        ZStack {
            Color.black

            // v1.0.8 Phase R.5 — gallery uploads display the picked
            // photo as the camera content (no live preview to freeze
            // for a library photo). Both camera path and gallery path
            // see the same scanning overlay + carousel result UI on
            // top — identical experience.
            if let galleryImage {
                // v1.0.8 Phase R.12 — hard frame + clipped + GeometryReader
                // so the photo can NEVER overflow the camera frame bounds.
                // .fill alone allows visible overflow if outer modifiers
                // don't clip; this enforces a strict bounding box.
                GeometryReader { inner in
                    Image(uiImage: galleryImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: inner.size.width, height: inner.size.height)
                        .clipped()
                }
            } else if camera.permissionStatus == .authorized {
                FoodCameraPreviewView(
                    previewLayer: camera.previewLayer,
                    isFrozen: camera.isPreviewFrozen
                )
            } else if camera.permissionStatus == .denied {
                permissionDeniedPlaceholder
            } else {
                ProgressView()
                    .tint(.white)
            }

            // v1.2 — the luxury reading-light, now a real Metal pass
            // (SnapShaders.metal): a diagonal warm band travels the
            // frame with a sparkle-grain field, additive over both the
            // live preview and gallery photos. The founder's "laser
            // scanning" ask, upgraded from the Canvas line.
            if isCapturing && !reduceMotion {
                // v22 — the light halved: on film the full band read
                // as glare, not intelligence. The rotator's words and
                // the landing chips carry "understanding"; the sweep
                // is texture now, not theater.
                SnapSweepOverlay(isActive: isCapturing)
                    .opacity(0.45)
                    .transition(.opacity)
            }

            // v1.2 — capture bloom. A ~300ms radial exposure flash at
            // the shutter moment (the photographic "the shot is taken"
            // beat), paired with a micro-settle on the frame content.
            // Reduce-motion users keep the haptic + freeze only.
            if captureFlash {
                RadialGradient(
                    colors: [Color.white.opacity(0.50), Color.white.opacity(0)],
                    center: .center, startRadius: 30, endRadius: 380
                )
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .scaleEffect(captureFlash ? 0.994 : 1.0)
        .animation(.spring(response: 0.34, dampingFraction: 0.75), value: captureFlash)
    }

    // MARK: - Wait line (her75 editorial pause)

    /// v1.0.19 (2026-06-18) — italic Fraunces "a moment..." line that
    /// fades in 540ms after the shutter tap and lives until either
    /// the result lands or the user cancels. Per the her75 designer's
    /// spec, this is "the editorial pause between question and
    /// answer" — patience as the brand voice. Reduce-motion skips
    /// straight to final opacity.
    @ViewBuilder private var aMomentLine: some View {
        // v22 ONE HAND — the italic "a moment..." died: the in-photo
        // rotator already carries the wait in plain words, and two
        // voices saying "wait" was the seam. This line now speaks
        // ONLY when the scan runs long, and speaks plainly.
        if isCapturing && capturedResult == nil && !galleryPreviewMode && longScan {
            Text("taking a little longer than usual")
                .font(.custom("DMSans-Regular", size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
                .transition(.opacity)
        }
    }

    // MARK: - Scan failure / retry card
    //
    // 2026-06-23 — the gentle failure state (design review §2). A dimmed
    // scrim over the KEPT frozen photo + a cream card with a clear "try
    // again" and two calm escapes. Never red, never a banner, never a
    // notification-error haptic. Lands with the same `.cardLand()`
    // entrance as the result card, so success + failure feel like
    // siblings.
    @ViewBuilder private func scanFailureOverlay(_ failure: ScanFailure) -> some View {
        ZStack {
            // Functional exposure-floor scrim, clipped to the frame.
            Color.black.opacity(0.28)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

            VStack(spacing: 0) {
                // SF glyph (controllable tint), reads "go again" with
                // zero warning semantics. -6° tilt for warmth.
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(FoodTheme.accent)
                    .rotationEffect(.degrees(-6))
                    .padding(.bottom, FoodTheme.Space.md)

                // Headline — italic Jeni-serif punch word.
                let parts = failure.headlineParts
                (
                    Text(parts.0).font(.custom("JeniHeroSerif-Regular", size: 26))
                    + Text(parts.1).font(.custom("JeniHeroSerif-Italic", size: 26))
                    + Text(parts.2).font(.custom("JeniHeroSerif-Regular", size: 26))
                )
                .foregroundStyle(FoodTheme.textPrimary)
                .multilineTextAlignment(.center)
                .padding(.bottom, FoodTheme.Space.sm)

                Text(failure.body)
                    .font(.custom("DMSans-Regular", size: 15))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.horizontal, 8)
                    .padding(.bottom, FoodTheme.Space.lg)

                // Primary — cocoa capsule (celebration pink would be the
                // wrong signal on a failure).
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    Task { await retryScan(failure) }
                } label: {
                    Text("try again")
                        .font(.custom("DMSans-SemiBold", size: 16))
                        .foregroundStyle(FoodTheme.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Capsule().fill(FoodTheme.textPrimary))
                }
                .buttonStyle(.plain)
                .padding(.bottom, FoodTheme.Space.md)

                // Calm escapes.
                HStack(spacing: 10) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismissScanFailure(clearPhoto: true)
                        showingLibraryPicker = true
                    } label: {
                        Text("use a photo")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundStyle(FoodTheme.textSecondary)
                    }
                    Text("·").foregroundStyle(FoodTheme.textSecondary.opacity(0.4))
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        dismissScanFailure(clearPhoto: true)
                        onQuickAddTapped()
                    } label: {
                        Text("type it instead")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundStyle(FoodTheme.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(FoodTheme.bgElevated)
                    .shadow(color: FoodTheme.textPrimary.opacity(0.12), radius: 18, x: 0, y: 6)
            )
            .padding(.horizontal, 14)
            .cardLand()
        }
        .accessibilityElement(children: .contain)
    }

    /// Clear the failure state; optionally drop the kept photo (the
    /// escapes that move away from this shot clear it; "try again" does not).
    private func dismissScanFailure(clearPhoto: Bool) {
        withAnimation(.easeOut(duration: 0.25)) {
            scanFailure = nil
            if clearPhoto {
                galleryImage = nil
                camera.clearFrozenFrame()
            }
        }
    }

    /// "try again". `.noFood` returns to the live camera so the user can
    /// reframe (re-running the same photo would just refail). `.general`
    /// / `.connection` reuse the captured shot (gallery image or frozen
    /// camera frame) so retry is one tap with no re-aim.
    private func retryScan(_ failure: ScanFailure) async {
        if failure == .noFood {
            dismissScanFailure(clearPhoto: true)
            return
        }
        let retryImage = galleryImage ?? camera.frozenFrame
        withAnimation(.easeOut(duration: 0.2)) { scanFailure = nil }
        if let retryImage {
            await libraryImagePicked(retryImage)
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
                // v1.0.8 Phase P — actual torch toggle (was a no-op
                // placeholder). Icon swaps to `bolt.fill` + the icon
                // tints to soft warm yellow when on so the state is
                // visible against any food background.
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    _ = camera.toggleTorch()
                } label: {
                    Image(systemName: camera.torchOn ? "bolt.fill" : "bolt.slash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(camera.torchOn ? Color(red: 1.0, green: 0.85, blue: 0.3) : .white)
                        .frame(width: 44, height: 44)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel(camera.torchOn ? "turn off flashlight" : "turn on flashlight")
                .opacity(camera.hasTorch ? 1 : 0.4)
                .disabled(!camera.hasTorch)

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
            // v1.0.9 D2 polish (2026-06-08) — hoist isCapturing = true
            // into the Button closure synchronously. Previously it lived
            // inside captureTapped() which runs on the next runloop hop
            // via Task { await ... }. That meant `freezePreview()`
            // (synchronous @Observable flip) landed in frame N but
            // `isCapturing` only landed in frame N+1 — the viewfinder
            // froze a frame BEFORE the scanning chrome (pill, ring
            // colour, scan-line overlay) appeared. Hoisting collapses
            // both into the same render so the user sees freeze +
            // scanning UI in a single visual beat.
            isCapturing = true
            errorMessage = nil
            scanFailure = nil
            camera.freezePreview()
            camera.freezeInstantly()
            // v1.0.9 D2 polish — pre-warmed Taptic Engine. See
            // `shutterHaptic` doc comment. Re-prepare so the next tap
            // is also instant.
            shutterHaptic.impactOccurred()
            shutterHaptic.prepare()
            AudioServicesPlaySystemSound(1108)
            // v1.2 — capture bloom fires on the same render as the
            // freeze so flash + stillness + haptic read as ONE event.
            if !reduceMotion {
                captureFlash = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                    withAnimation(.easeOut(duration: 0.30)) {
                        captureFlash = false
                    }
                }
            }
            Task { await captureTapped() }
        } label: {
            // 2026-06-23 (design review) — the shutter no longer SPINS
            // during scan. A revolving shutter read as a casino reel and
            // fought the border light for attention. Now it RECEDES: ring
            // + disc go dusty-rose, the camera sticker fades out, and the
            // whole control scales down a touch and settles. The "we're
            // reading" signal lives in the calm travelling border + the
            // in-frame label — not in a spinning button.
            //   - idle: subtle 6s breathe (scale 1.0 ↔ 1.02)
            //   - scanning: scale 0.94, rose ring + faint rose disc,
            //     sticker faded, no rotation
            //   - reduce-motion: no breathe (handled by shutterBreathing)
            // v1.2 — the shutter goes clean-lens: rose outer ring, white
            // disc, and a cocoa hairline inner ring where the camera
            // sticker used to sit. Reads as an optic, not a button with
            // a picture on it — one fewer illustration competing with
            // the plate.
            ZStack {
                Circle()
                    .stroke(FoodTheme.accent, lineWidth: 2.5)
                    .frame(width: 78, height: 78)

                Circle()
                    .fill(isCapturing ? FoodTheme.accent.opacity(0.16) : Color.white)
                    .frame(width: 64, height: 64)
                    .shadow(color: .black.opacity(0.20), radius: 6, x: 0, y: 2)
                    .animation(.linear(duration: 0.12), value: isCapturing)

                Circle()
                    .stroke(FoodTheme.textPrimary.opacity(isCapturing ? 0.0 : 0.10), lineWidth: 1)
                    .frame(width: 50, height: 50)
            }
            .scaleEffect(isCapturing ? 0.94 : (shutterBreathing && !reduceMotion ? 1.02 : 1.0))
            .animation(.spring(response: 0.45, dampingFraction: 0.86), value: isCapturing)
            .contentShape(Circle())
        }
        // v1.0.9 D2 polish round 2 — `.buttonStyle(.plain)` removes
        // the default Button press-dim animation (~100ms opacity
        // fade) that ran AHEAD of our state changes after tap. With
        // the system style, the user saw the shutter dim first and
        // the scanning chrome (ring colour swap, pill, scan line)
        // arrive a beat later — reading as "lag." With .plain, our
        // own scale/rotation/colour state changes are the only
        // visual response, all landing in the same render as the
        // freeze.
        .buttonStyle(.plain)
        .disabled(isCapturing || camera.permissionStatus != .authorized || !camera.isRunning)
        .accessibilityLabel(isCapturing ? "scanning" : "scan food")
        .onAppear {
            // v1.0.9 D2 polish — warm the Taptic Engine on view appear
            // so the first shutter tap fires the haptic without the
            // ~30-50ms cold-start hitch. Also warms the shutter sound.
            shutterHaptic.prepare()
            // Cold-priming AudioServices system sound — the OS lazily
            // loads the audio data on first call. A silent dry-run at
            // 0 volume isn't an option, but the first real-tap cost is
            // small and only happens once per process. Documented here
            // for posterity.

            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                shutterBreathing = true
            }
        }
    }

    // MARK: - Bottom toolbar (outside the frame)

    /// v1.0.8 Phase M — toolbar that sits in the black area below the
    /// camera frame. Mimics the reference layout: gallery icon left,
    /// mode chip row centered, 44pt clear balance spacer right.
    @ViewBuilder private var bottomToolbar: some View {
        if galleryPreviewMode {
            galleryPreviewActions
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            HStack(spacing: 0) {
                galleryButton
                    .opacity(isCapturing ? 0.35 : 1)
                    .allowsHitTesting(!isCapturing)

                Spacer()

                // 2026-06-23 (design review) — the redundant "scanning"
                // toolbar pill was cut. The in-frame label ("reading
                // every bite") + the cream "a moment..." line above the
                // toolbar already carry the scanning tell, so the toolbar
                // center stays empty + calm during a scan (restraint > a
                // third place that says "scanning").
                if !isCapturing {
                    modeChips
                        .transition(.opacity)
                }

                Spacer()

                Color.clear.frame(width: 44, height: 44)
            }
            // v1.0.9 D2 polish round 2 (2026-06-08) — snap the toolbar
            // swap. 0.22s easeInOut + scale on both branches added
            // perceptual lag: founder saw a soft fade before the
            // scanning chrome arrived. 0.10s straight opacity reads
            // as "instant change" without a jarring cut, and the
            // shutter's own ring/disc swap (now also snapped below)
            // covers the same frame so the moment lands together.
            .animation(.easeInOut(duration: 0.10), value: isCapturing)
            .transition(.opacity)
        }
    }

    // MARK: - Gallery preview chrome + actions

    /// v1.0.8 Phase R.7 — in-frame overlay shown after the user picks
    /// a photo, before the scan starts. X close (top-right) + a small
    /// "ready?" prompt floating mid-screen. The actual confirm CTAs
    /// live in the bottom toolbar (galleryPreviewActions).
    @ViewBuilder private var galleryPreviewChrome: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                glassButton(systemName: "xmark", action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        galleryPreviewMode = false
                        galleryImage = nil
                    }
                })
                .accessibilityLabel("cancel")
            }

            Spacer()

            // Small floating prompt — matches the in-camera microcopy
            // tone. Italic-Fraunces punch word per voice lock.
            (
                Text("ready to ") + Text("scan").font(.custom("Fraunces72pt-SemiBoldItalic", size: 14)) + Text(" this one")
            )
            .font(.system(size: 14))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .colorScheme(.dark)
            .padding(.bottom, 14)
        }
    }

    /// Bottom-toolbar variant for the preview-confirm step. "cancel"
    /// returns to camera; "use this photo" kicks off the scan via
    /// libraryImagePicked.
    @ViewBuilder private var galleryPreviewActions: some View {
        HStack(spacing: 12) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.3)) {
                    galleryPreviewMode = false
                    galleryImage = nil
                }
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .colorScheme(.dark)
            }
            .accessibilityLabel("cancel")

            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                guard let img = galleryImage else { return }
                galleryPreviewMode = false
                Task { await libraryImagePicked(img) }
            } label: {
                Text("use this photo")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule().fill(FoodTheme.textPrimary)
                    )
                    .shadow(color: FoodTheme.textPrimary.opacity(0.3),
                            radius: 8, x: 0, y: 2)
            }

            Color.clear.frame(width: 48, height: 48)
        }
    }

    // MARK: - Result stage (full-bleed photo + carousel)

    /// v1.2 snap-food rebuild — a landed scan promotes the photo to the
    /// whole screen and floats the SnapResultView carousel over it
    /// (plate panel · jeni note · on-photo share composer). The photo
    /// never moves; the slides carousel over it.
    @ViewBuilder
    private func resultStage(_ result: CapturedFood) -> some View {
        ZStack {
            resultPhotoBackdrop

            // Top scrim so the floating close/back chrome reads on any
            // plate. Fades to nothing by 20% down the screen.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(0.30), .clear],
                    startPoint: .top, endPoint: .bottom
                )
                .frame(height: 150)
                Spacer(minLength: 0)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // v22 THE UNDERSTANDING — hidden on the share slide so
            // the composer owns the photo.
            if resultPage < 2 {
                SnapUnderstandingChips(items: result.items)
                    .allowsHitTesting(false)
            }

            SnapResultView(
                userId: userId,
                food: result,
                mealLabel: mealTypeLabel,
                dishName: dishNameLabel(result),
                page: $resultPage,
                onLog: { edited in
                    capturedResult = edited
                    onCaptured(edited, galleryImage ?? camera.frozenFrame)
                },
                onRetake: retakeFromResult,
                onEdited: { edited in capturedResult = edited },
                refine: { request in
                    try await SnapRefine.run(request, dispatcher: dispatcher)
                }
            )

            // Floating chrome swaps with the carousel slide: close on
            // the panel slides, back + share-CTA on the composer slide.
            VStack {
                HStack {
                    if resultPage == 2 {
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.3)) { resultPage = 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                                .colorScheme(.dark)
                        }
                        .accessibilityLabel("back to result")

                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            renderAndShare(result)
                        } label: {
                            // v22 — the heart retired with the voice
                            // pass; the package had kept one.
                            Text("share it")
                                .font(.custom("DMSans-SemiBold", size: 15))
                                .foregroundStyle(FoodTheme.bgPrimary)
                                .padding(.horizontal, 20)
                                .frame(height: 44)
                                .background(Capsule().fill(FoodTheme.textPrimary))
                        }
                        .accessibilityLabel("share it")
                    } else {
                        Spacer()
                        glassButton(systemName: "xmark", action: {
                            camera.unfreezePreview()
                            onDismiss()
                        })
                        .accessibilityLabel("close")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                Spacer()
            }
            .animation(.easeOut(duration: 0.22), value: resultPage == 2)
        }
        .onAppear {
            photoSettled = false
            withAnimation(reduceMotion ? .none : .easeOut(duration: 1.1)) {
                photoSettled = true
            }
            #if DEBUG
            // Sim QA: jump the carousel to a slide for screenshot
            // capture (`--debug-share-mode` kept for older run scripts).
            if ProcessInfo.processInfo.arguments.contains("--debug-share-mode")
                || ProcessInfo.processInfo.arguments.contains("--debug-result-share") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeOut(duration: 0.3)) { resultPage = 2 }
                }
            } else if ProcessInfo.processInfo.arguments.contains("--debug-result-note") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation(.easeOut(duration: 0.3)) { resultPage = 1 }
                }
            }
            #endif
        }
        .sheet(isPresented: $showShareActivity) {
            if let img = shareRenderedImage {
                ShareActivityView(
                    items: [img],
                    onComplete: { showShareActivity = false }
                )
            }
        }
    }

    /// The captured photo, full bleed with a ken-burns settle on
    /// arrival (1.07 → 1.0 over 1.1s — the photo "breathes in" as the
    /// panel rises). Falls back to a warm cocoa gradient in the rare
    /// frame-race where no image exists yet.
    @ViewBuilder private var resultPhotoBackdrop: some View {
        GeometryReader { geo in
            Group {
                if let img = galleryImage ?? camera.frozenFrame {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    LinearGradient(
                        colors: [
                            Color(red: 0.32, green: 0.22, blue: 0.20),
                            Color(red: 0.18, green: 0.12, blue: 0.11),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .scaleEffect(photoSettled ? 1.0 : 1.07)
            .clipped()
        }
        .ignoresSafeArea()
    }

    /// Skip/retake from the result panel — back to the live camera.
    private func retakeFromResult() {
        camera.unfreezePreview()
        withAnimation(.easeInOut(duration: 0.3)) {
            capturedResult = nil
            galleryImage = nil
        }
        shareRenderedImage = nil
        resultPage = 0
    }

    private func shareTotals(_ food: CapturedFood) -> (carbs: Int, protein: Int, fat: Int, fiber: Int, kcal: Int) {
        (
            carbs: Int(food.items.compactMap { $0.carbsG }.reduce(0, +).rounded()),
            protein: Int(food.items.compactMap { $0.proteinG }.reduce(0, +).rounded()),
            fat: Int(food.items.compactMap { $0.fatG }.reduce(0, +).rounded()),
            fiber: Int(food.items.compactMap { $0.fiberG }.reduce(0, +).rounded()),
            kcal: Int((food.totalKcal ?? 0).rounded())
        )
    }

    /// Render the 1080×1920 export with the user's persisted font +
    /// alignment and hand it to the system share sheet. Rendering at
    /// tap time is ~40-80ms on modern silicon — imperceptible under
    /// the sheet-present animation.
    private func renderAndShare(_ result: CapturedFood) {
        guard let photo = galleryImage ?? camera.frozenFrame else { return }
        let font = SnapShareFont(
            rawValue: UserDefaults.standard.string(forKey: "snapShareFont") ?? ""
        ) ?? .editorial
        let trailing = UserDefaults.standard.bool(forKey: "snapShareTrailing")
        shareRenderedImage = SnapShareRenderer.render(
            photo: photo,
            dishName: dishNameLabel(result),
            itemNames: result.items.map { $0.name },
            totals: shareTotals(result),
            font: font,
            trailing: trailing
        )
        guard shareRenderedImage != nil else { return }
        showShareActivity = true
    }

    // MARK: - Result helpers

    private var mealTypeLabel: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Breakfast"
        case 11..<15: return "Lunch"
        case 15..<18: return "Snack"
        case 18..<22: return "Dinner"
        default:      return "Snack"
        }
    }

    private func dishNameLabel(_ food: CapturedFood) -> String {
        if food.items.isEmpty { return "your plate" }
        if food.items.count == 1 { return food.items[0].name }
        if food.items.count == 2 {
            return "\(food.items[0].name) + \(food.items[1].name)"
        }
        return food.items.prefix(2).map { $0.name }.joined(separator: " + ")
            + " +\(food.items.count - 2)"
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

    /// v1.0.9 D2 — microcopy refresh per UX expert pick. The "your
    /// moment" framing leaves the instructional register (center
    /// your plate) for an identity register that holds across any
    /// composition. Italic-Fraunces 15pt + tracking(0.3) gives it
    /// the polaroid-handwriting feel.
    @ViewBuilder private var microcopyText: some View {
        (
            Text("your ")
                .font(.system(size: 15))
            + Text("moment")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
            + Text("")
                .font(.system(size: 15))
        )
        .tracking(0.3)
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .colorScheme(.dark)
    }

    /// Library upload entry point. Tap → PHPicker. Picker hands
    /// back a UIImage which goes through the same saliency +
    /// resize + EF pipeline as a camera capture.
    // v1.1 capture spec — on-cream chrome rule: controls OUTSIDE the
    // viewfinder wear the app register (cocoa glyph on soft white),
    // not dark glass.
    @ViewBuilder private var galleryButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingLibraryPicker = true
        } label: {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Color.white.opacity(0.55)))
                .overlay(Circle().stroke(FoodTheme.textPrimary.opacity(0.10), lineWidth: 1))
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

    // v1.0.8 Phase N — iOS-segmented chip row mirroring the reference
    // layout: ONE outer translucent capsule containing N tabs.
    // Active tab gets a white inner capsule + cocoa text; inactive
    // tabs are bare text on the translucent backing. Founder feedback
    // on Phase M: 3 chips with their own individual capsules + an
    // outer wrap capsule were collapsing on width and rendering each
    // letter on its own line. This compresses cleanly even on the
    // smallest iPhone width.
    // v1.0.9 D2 — bottom toolbar refresh per UX expert. Each chip
    // carries an emoji sticker (camera / pencil / wine — i'm out
    // renamed to "dining out" covers brunch + lunch + dinner not
    // just nightlife). Active chip gets a 1pt rose border + hard
    // offset shadow at chip scale = micro-scrapbook chrome that
    // makes the toolbar feel JeniFit, not iOS-segmented-control.
    @ViewBuilder private var modeChips: some View {
        // v1.2 — three input modes, one hole to throw food at:
        //   snap     — the camera (this screen)
        //   describe — type it, same estimate pipeline (was "quick log";
        //              renamed to say what it does, not how it's stored)
        //   again    — one-tap relog of a recent plate (RecentMealsSheet)
        // Dining-out stays folded into describe per the D-series call
        // ("you can say whatever in quicklog"); ImOutTonightView + its
        // dispatcher arm remain dormant for a future re-enable.
        HStack(spacing: 6) {
            modeChip("snap", .photo)
            modeChip("describe", .quickAdd)
            modeChip("again", .again)
        }
    }

    @ViewBuilder
    private func modeChip(_ label: String, _ tab: CaptureTab) -> some View {
        let isActive = captureTab == tab
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            switch tab {
            case .photo:    captureTab = tab
            case .quickAdd: onQuickAddTapped()
            case .imOut:    onImOutTapped()
            case .again:    onAgainTapped()
            }
        } label: {
            Text(label)
                .font(.custom("DMSans-SemiBold", size: 14))
                .foregroundStyle(isActive ? FoodTheme.bgPrimary : FoodTheme.textPrimary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    Capsule().fill(isActive ? FoodTheme.textPrimary : Color.white.opacity(0.55))
                )
                .overlay(
                    Capsule().stroke(
                        FoodTheme.textPrimary.opacity(isActive ? 0 : 0.12),
                        lineWidth: 1
                    )
                )
                .animation(.spring(response: 0.45, dampingFraction: 0.82), value: isActive)
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
        // v1.0.9 D2 polish (2026-06-08) — `isCapturing = true` +
        // `errorMessage = nil` now happen synchronously in the
        // Button closure (same runloop tick as freezePreview). The
        // re-tap guard is no longer needed here because the shutter
        // Button's `.disabled(isCapturing || ...)` modifier already
        // prevents a second tap while a scan is in flight.
        defer { isCapturing = false }

        // v1.0.8 Phase J — haptic/sound/flash/freeze moved to the Button
        // closure to fire on the same synchronous runloop tick as the
        // tap. By the time this async function runs, the user already
        // sees the frozen frame + hears the shutter + feels the haptic.
        // All this function does now is the heavyweight async work.

        FoodAnalytics.track(.scanStarted)
        FoodAnalytics.firstScanStartedIfNeeded()

        let name = UserDefaults.standard.string(forKey: "userName") ?? ""

        // Live Activity bootstrap. FoodScanActivity.start is synchronous
        // (it just invokes a registered closure), so we call it directly.
        // 2026-06-23 — the old `await Task.detached { ... }.value` here
        // was a pointless hop that sat OUTSIDE the do/catch below and
        // could itself pin the scan if ActivityKit stalled. The visible
        // freeze already happened synchronously in the shutter Button
        // closure (freezePreview + freezeInstantly), so calling this
        // directly can't lag the capture; the real JPEG capture now runs
        // inside the deadline-guarded block below.
        let activityHandle: Any? = FoodScanActivity.start(displayName: name)

        // Soften the in-flight copy ~9s into a slow-but-not-failed scan.
        startLongScanNudge()

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
            // 2026-06-23 — capture + dispatch run UNDER A HARD DEADLINE
            // (`withScanDeadline`) so the scan can NEVER pin the spinner
            // forever. Each await inside was independently capable of
            // hanging with no floor: the AVFoundation capture
            // continuation, the EF network call, and the post-vision
            // nutrition lookup. The deadline guarantees this throws
            // ScanDeadlineExceeded by `scanDeadlineSeconds` no matter
            // what, routing to the gentle failure card.
            //
            // The silent auto-retry (dispatchPhotoWithRetry — up to 3
            // tries with backoff on transient blips) still runs WITHIN
            // the deadline budget, so cafe-wifi hiccups recover invisibly
            // while the whole chain stays bounded. captureStillAndFreeze
            // also publishes camera.frozenFrame for the result polaroid.
            let result = try await withScanDeadline(scanDeadlineSeconds) {
                let jpeg = try await camera.captureStillAndFreeze()
                return try await dispatchPhotoWithRetry(jpeg)
            }
            stopLongScanNudge()

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
                FoodAnalytics.track(.scanFallbackFired, properties: ["reason": "empty_items"])
                phaseTask?.cancel()
                FoodScanActivity.end(handle: activityHandle)
                // 2026-06-23 — route to the gentle failure card (Option B
                // copy: "one more look?") instead of the terse top banner.
                // KEEP the frozen photo so the card reads over the actual
                // shot; "try again" on .noFood clears it so the user can
                // reframe (re-running the same photo just refails).
                // recordCaptureFailed clears the 3s debounce so the
                // reframe re-tap is instant.
                camera.recordCaptureFailed()
                withAnimation(.easeOut(duration: 0.3)) { scanFailure = .noFood }
                return
            }

            FoodAnalytics.track(.scanCompleted, properties: [
                "items_count": result.items.count,
                "has_restaurant_range": result.kcalLow != nil,
            ])
            FoodAnalytics.firstScanCompletedIfNeeded()

            // End the Live Activity with a brief "ready" beat
            // before tearing down so the system pill registers the
            // success state visibly. Detached so it doesn't block
            // the main-thread transition into the result phase.
            phaseTask?.cancel()
            Task.detached {
                await FoodScanActivity.update(handle: activityHandle, phase: "ready")
                try? await Task.sleep(nanoseconds: 700_000_000)
                await FoodScanActivity.end(handle: activityHandle)
            }

            // v1.0.8 Phase P (2026-06-08) — RESULT IS SHOWN INLINE.
            // Founder direction: "don't change the design framework
            // and captured screen. just [these cards] on the same
            // captured photo screen + log/skip/share buttons."
            //
            // capturedResult drives the inline overlay (nutrition card
            // on top of the frozen photo) + the result-mode bottom
            // toolbar. onCaptured is deferred until the user explicitly
            // taps "log it" — at which point CaptureFlowView persists
            // and dismisses. The user can also tap "skip" to clear
            // capturedResult and return to live-preview camera mode,
            // or tap the share button to export the card+photo.
            capturedResult = result
        } catch CameraError.captureTooSoon {
            // v1.0.7 — silently ignore back-to-back shutter taps within
            // the 3s debounce window. No banner, no failure card.
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) { camera.clearFrozenFrame() }
            return
        } catch is ScanDeadlineExceeded {
            // 2026-06-23 — the hard deadline fired: the scan took too long
            // (slow network/EF) or a non-network await hung. Gentle card,
            // photo KEPT so "try again" is one tap.
            #if DEBUG
            print("[PhotoCaptureView] scan hit hard deadline (\(scanDeadlineSeconds)s)")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            FoodAnalytics.track(.scanFallbackFired, properties: ["reason": "hard_deadline"])
            camera.recordCaptureFailed()
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .connection }
        } catch is CancellationError {
            // The deadline's best-effort cancel surfaced as a
            // cancellation rather than ScanDeadlineExceeded — same UX.
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            camera.recordCaptureFailed()
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .connection }
        } catch FoodCaptureError.notImplemented(let ticket, let message, _) {
            // Config error (vision service not wired). DEBUG logs the
            // ticket; the user sees the gentle card.
            #if DEBUG
            print("[PhotoCaptureView] not implemented [\(ticket)] \(message)")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            camera.recordCaptureFailed()
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .general }
        } catch let captureError as FoodCaptureError {
            #if DEBUG
            print("[PhotoCaptureView] capture failed: \(captureError)")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            // Rate-limit / budget-cap keep their dedicated sheet (it
            // carries the server's reset-time copy); every other failure
            // routes to the gentle card with the photo kept for retry.
            if let term = TerminalError.from(captureError) {
                terminalError = term
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "terminal_error", "case": term.id,
                ])
                withAnimation(.easeOut(duration: 0.25)) { camera.clearFrozenFrame() }
            } else {
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "capture_error",
                    "case": String(describing: captureError),
                ])
                camera.recordCaptureFailed()
                withAnimation(.easeOut(duration: 0.3)) { scanFailure = .from(captureError) }
            }
        } catch {
            let ns = error as NSError
            #if DEBUG
            print("[PhotoCaptureView] capture failed (unknown): \(error)")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "capture_error", "ns_error_code": ns.code,
            ])
            camera.recordCaptureFailed()
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .from(error) }
        }
    }

    // MARK: - Slow-scan nudge

    /// Start the slow-scan reassurance timer. ~9s into a scan that hasn't
    /// resolved, flips `longScan` so the in-flight copy softens ("a
    /// little longer than usual..."). The longer it takes, the calmer the
    /// tell — never an alarm. Cancelled the moment the scan resolves.
    private func startLongScanNudge() {
        longScanTask?.cancel()
        longScan = false
        longScanTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(Self.scanLongHintSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.4)) { longScan = true }
        }
    }

    private func stopLongScanNudge() {
        longScanTask?.cancel()
        longScanTask = nil
        longScan = false
    }

    // MARK: - Scan haptics

    /// Soft haptic pulse while scanning, synced to the snapSweep light
    /// cadence (2.6s) at gentle intensity — the pulse lands as the band
    /// crosses mid-frame. The first pulse waits one cadence so it
    /// doesn't double up with the shutter tap's own haptic. Cancelled
    /// the moment the scan resolves (or the view disappears).
    private func startScanHaptics() {
        scanHapticTask?.cancel()
        scanHaptic.prepare()
        scanHapticTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_600_000_000)
                guard !Task.isCancelled else { return }
                scanHaptic.impactOccurred(intensity: 0.6)
                scanHaptic.prepare()
            }
        }
    }

    private func stopScanHaptics() {
        scanHapticTask?.cancel()
        scanHapticTask = nil
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

        // v1.0.8 Phase R.5 — gallery upload now mirrors the camera
        // flow exactly. Founder bug: "when i upload a photo using
        // upload photo option, it doesn't show me the post-capture
        // screen or scanning process and instantly adds some calories
        // and kicks me back home."
        //
        // Three fixes wrapped in here:
        //   1. galleryImage = image — replaces the live preview with
        //      the picked photo, so the user sees what they uploaded.
        //   2. isCapturing = true — triggers the border shimmer +
        //      revolving shutter arc + scanning overlay, identical to
        //      the camera capture visual.
        //   3. capturedResult = result is set BUT onCaptured is NOT
        //      called — the user reviews the result inline, exactly
        //      like the camera path. Tapping "log it" fires the
        //      onCaptured callback; "skip" clears everything and
        //      returns to live camera.
        galleryImage = image
        isCapturing = true
        errorMessage = nil
        scanFailure = nil
        defer { isCapturing = false }

        FoodAnalytics.track(.scanStarted)
        FoodAnalytics.firstScanStartedIfNeeded()

        let name = UserDefaults.standard.string(forKey: "userName") ?? ""
        // Synchronous start (see captureTapped) — no unguarded await.
        let activityHandle: Any? = FoodScanActivity.start(displayName: name)
        startLongScanNudge()
        let phaseTask: Task<Void, Never>? = activityHandle == nil ? nil : Task.detached {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "matching")
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            await FoodScanActivity.update(handle: activityHandle, phase: "tallying")
        }

        do {
            // Same hard-deadline guard as the camera path — the gallery
            // scan can never pin the spinner forever either.
            let result = try await withScanDeadline(scanDeadlineSeconds) {
                let jpeg = try await camera.processUIImageForScan(image)
                return try await dispatchPhotoWithRetry(jpeg)
            }
            stopLongScanNudge()

            let noFood = result.items.isEmpty
                && (result.kcalLow == nil || result.kcalLow == 0)
            if noFood {
                FoodAnalytics.track(.scanFallbackFired, properties: ["reason": "empty_items", "source": "library"])
                phaseTask?.cancel()
                FoodScanActivity.end(handle: activityHandle)
                // Keep the gallery photo behind the gentle card.
                withAnimation(.easeOut(duration: 0.3)) { scanFailure = .noFood }
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

            // v1.0.8 Phase R.5 — set capturedResult to trigger the
            // inline result stage, but DO NOT call onCaptured here.
            // User taps "log it" to actually persist.
            capturedResult = result
        } catch is ScanDeadlineExceeded {
            #if DEBUG
            print("[PhotoCaptureView] library scan hit hard deadline")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            FoodAnalytics.track(.scanFallbackFired, properties: ["reason": "hard_deadline", "source": "library"])
            // Keep galleryImage so "try again" reuses the picked photo.
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .connection }
        } catch is CancellationError {
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .connection }
        } catch let captureError as FoodCaptureError {
            #if DEBUG
            print("[PhotoCaptureView] library capture failed: \(captureError)")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            if let term = TerminalError.from(captureError) {
                terminalError = term
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "terminal_error", "source": "library", "case": term.id,
                ])
                withAnimation(.easeOut(duration: 0.25)) {
                    galleryImage = nil
                    camera.clearFrozenFrame()
                }
            } else {
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "capture_error", "source": "library",
                    "case": String(describing: captureError),
                ])
                // Keep galleryImage behind the card for one-tap retry.
                withAnimation(.easeOut(duration: 0.3)) { scanFailure = .from(captureError) }
            }
        } catch {
            let ns = error as NSError
            #if DEBUG
            print("[PhotoCaptureView] library capture failed (unknown): \(error)")
            #endif
            stopLongScanNudge()
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "capture_error", "source": "library", "ns_error_code": ns.code,
            ])
            withAnimation(.easeOut(duration: 0.3)) { scanFailure = .from(error) }
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
        // App v2 — merged dietary hint (onboarding answers + in-app
        // Food Settings edits) via the one resolver, so a settings
        // change actually reaches recognition.
        dispatcher.dietaryProfile = DietaryProfileResolver.current()
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
    /// Permanent: rate limits, budget caps, invalid input, auth, AND
    /// URLSession timeouts (NSURLErrorTimedOut). A timeout means the
    /// EF / vision model is genuinely slow this minute; auto-retrying
    /// just stacks another 180s wait on top of the first one. 540s of
    /// silent spinning is the worst trial-killer in the food rail —
    /// surface the error fast and let the user manually re-tap once
    /// they understand the scan didn't go through.
    private static func isTransient(_ error: Error) -> Bool {
        guard let cap = error as? FoodCaptureError,
              case .pipeline(let underlying) = cap,
              let vision = underlying as? VisionError else {
            return false
        }
        switch vision {
        case .networkError(let underlying):
            let ns = underlying as NSError
            return ns.code != NSURLErrorTimedOut
        case .parseError:
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
    case again
}

// MARK: - ScanFailure
//
// 2026-06-23 — a scan that failed or timed out. Drives the gentle cream
// failure/retry card (never a red banner, never a frozen spinner). Copy
// is voice-locked: lowercase, one italic-Fraunces punch word, hearts as
// terminal punctuation only, no "error/failed/wrong", no em-dash. The
// reassurance is load-bearing — failure should feel like "the photo
// didn't come through," never "you did something wrong."
//
//   .connection / .general → retry reuses the captured photo
//   .noFood                → retry returns to live camera to reframe
//                            (re-running the same photo would refail)
enum ScanFailure: Equatable {
    case general
    case connection
    case noFood

    /// Headline as (plain, italic-punch, plain) so the card can render
    /// the punch word in italic Jeni serif.
    var headlineParts: (String, String, String) {
        switch self {
        case .general, .connection: return ("let's try that ", "again", "")
        case .noFood:               return ("one ", "more", " look?")
        }
    }

    var body: String {
        // U+FE0E pins the heart to TEXT presentation — without it the
        // glyph falls through DMSans to Apple Color Emoji and renders
        // as a red emoji heart on the cream card (baseline audit bug).
        switch self {
        case .general:
            return "that one didn't come through. happens sometimes. your photo's still here \u{2665}\u{FE0E}"
        case .connection:
            return "looks like the connection blinked. we'll try again whenever you're ready \u{2665}\u{FE0E}"
        case .noFood:
            return "we couldn't quite read this plate. a little more light or a closer angle usually does it \u{2665}\u{FE0E}"
        }
    }

    /// Map a thrown scan error to the right failure flavor.
    static func from(_ error: Error) -> ScanFailure {
        if error is ScanDeadlineExceeded { return .connection }
        // Unwrap FoodCaptureError.pipeline(VisionError) and CameraError
        // to tell a connection blip apart from a generic miss.
        if let capture = error as? FoodCaptureError,
           case .pipeline(let underlying) = capture {
            if let vision = underlying as? VisionError {
                switch vision {
                case .networkError, .upstreamFailure: return .connection
                default: return .general
                }
            }
        }
        let ns = error as NSError
        if ns.domain == NSURLErrorDomain { return .connection }
        return .general
    }
}

#if DEBUG
extension PhotoCaptureView {
    /// A warm faux-food image so the simulator QA autostart has
    /// something to "scan" (the debug fault short-circuits before any
    /// real analysis, so the content only needs to look plausible
    /// behind the scanning + failure chrome).
    static func debugMockImage() -> UIImage {
        let size = CGSize(width: 1080, height: 1920)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let bg = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.86, green: 0.55, blue: 0.30, alpha: 1).cgColor,
                    UIColor(red: 0.70, green: 0.28, blue: 0.18, alpha: 1).cgColor,
                ] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(bg, start: .zero,
                                 end: CGPoint(x: size.width, y: size.height), options: [])
            c.setFillColor(UIColor(white: 0.98, alpha: 1).cgColor)
            c.fillEllipse(in: CGRect(x: 120, y: 660, width: 840, height: 840))
            c.setFillColor(UIColor(red: 0.80, green: 0.52, blue: 0.26, alpha: 1).cgColor)
            for (x, y) in [(280, 880), (560, 820), (430, 1080), (640, 1120)] {
                c.fillEllipse(in: CGRect(x: x, y: y, width: 230, height: 200))
            }
        }
    }
}
#endif

// MARK: - TerminalError

/// v1.0.8 Phase S — terminal errors that warrant a dedicated UI
/// state instead of the transient error banner. Founder ask: "we
/// need to do better error handling too. like we can inform user
/// about the daily limit when they hit this problem."
///
/// Both cases reset at midnight (UTC). The copy from the EF already
/// carries the relevant detail (count + reset time); we extract it
/// and render in a clear dismissable overlay.
enum TerminalError: Identifiable, Equatable {
    case rateLimited(copy: String)
    case budgetCapped(copy: String)

    var id: String {
        switch self {
        case .rateLimited: return "rate_limited"
        case .budgetCapped: return "budget_capped"
        }
    }

    var copy: String {
        switch self {
        case .rateLimited(let copy): return copy
        case .budgetCapped(let copy): return copy
        }
    }

    var title: String {
        switch self {
        case .rateLimited: return "all caught up"
        case .budgetCapped: return "we're full for now"
        }
    }

    /// Extract a TerminalError from a thrown capture error if it's
    /// one of the rate-limit / budget-cap cases; nil otherwise.
    static func from(_ error: Error) -> TerminalError? {
        guard let cap = error as? FoodCaptureError,
              case .pipeline(let underlying) = cap,
              let vision = underlying as? VisionError else {
            return nil
        }
        switch vision {
        case .rateLimited(let copy): return .rateLimited(copy: copy)
        case .budgetCapped(let copy): return .budgetCapped(copy: copy)
        default: return nil
        }
    }
}

// MARK: - ShareActivityView (UIActivityViewController bridge)

/// SwiftUI wrapper around UIActivityViewController for sharing
/// multiple items. ShareLink's `items:` initializer is fine for static
/// arrays but the multi-select picker needs to hand a dynamic, user-
/// chosen array to the system share sheet; UIActivityViewController is
/// the simplest path.

struct ShareActivityView: UIViewControllerRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in
            DispatchQueue.main.async { onComplete() }
        }
        return vc
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - TerminalErrorSheet
//
// v1.0.8 Phase S — clean, JeniFit-voiced UI for rate limit + budget
// cap errors. Replaces the generic "couldn't reach us" banner with
// an explicit "you've hit your daily limit, resets at midnight"
// message. Founder: "we need to do better error handling too. like
// we can inform user about the daily limit when they hit this
// problem."

struct TerminalErrorSheet: View {
    let error: TerminalError
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Spacer()

            // Icon — soft sparkle for "you're done for today" vibe,
            // not warning iconography.
            Image(systemName: "sparkles")
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(FoodTheme.accent)

            // Italic-Fraunces headline per brand voice signal.
            Text(error.title)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
                .foregroundStyle(FoodTheme.textPrimary)

            // Server-provided copy with the scan count + reset time.
            Text(error.copy)
                .font(.system(size: 15))
                .foregroundStyle(FoodTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()

            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            }) {
                Text("got it")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        Capsule().fill(FoodTheme.textPrimary)
                    )
                    .shadow(color: FoodTheme.textPrimary
                                .opacity(0.3),
                            radius: 8, x: 0, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(FoodTheme.bgElevated)
        .colorScheme(.light)
    }
}

// MARK: - PendingGallery + GalleryConfirmSheet
//
// v1.0.8 Phase R.10 — hard-barrier preview-confirm step for gallery
// uploads. .sheet(item:) requires the user to explicitly tap a button
// to dismiss; there's no way for SwiftUI state batching, Task timing,
// or any other side effect to "skip" this step.

struct PendingGallery: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct GalleryConfirmSheet: View {
    let image: UIImage
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                (Text("use this ")
                    .font(.custom("Fraunces72pt-Regular", size: 22))
                + Text("photo")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                + Text("?")
                    .font(.custom("Fraunces72pt-Regular", size: 22)))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .accessibilityLabel("close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 6)

            // 2026-06-24 — polaroid treatment (founder: "too plain + too
            // much empty space"). Warm white frame + soft shadow + a slight
            // scrapbook tilt (the food rail's polaroid register), replacing
            // the stark 3pt black border. The sheet is sized to content
            // (fraction detent) so there's no big empty gap.
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 300)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .padding(10)
                .padding(.bottom, 16)        // taller bottom edge = polaroid
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.white)
                )
                .rotationEffect(.degrees(-1.5))
                .shadow(color: Color.black.opacity(0.14), radius: 16, x: 0, y: 6)
                .padding(.horizontal, 30)
                .padding(.top, 4)

            (Text("we'll read what's on your ")
                .font(.custom("DMSans-Regular", size: 14))
            + Text("plate")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
            + Text("")
                .font(.custom("DMSans-Regular", size: 14)))
                .foregroundStyle(FoodTheme.textSecondary)

            Spacer(minLength: 6)

            HStack(spacing: 12) {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onCancel()
                } label: {
                    Text("cancel")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule().fill(Color.black.opacity(0.06))
                        )
                }

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    onConfirm()
                } label: {
                    (Text("scan this")
                        .font(.system(size: 16, weight: .semibold))
                    + Text("")
                        .font(.system(size: 14)))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule().fill(FoodTheme.textPrimary)
                        )
                        .shadow(color: FoodTheme.textPrimary
                                    .opacity(0.3),
                                radius: 8, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 22)
        }
        .background(FoodTheme.bgPrimary)
        .colorScheme(.light)
        .presentationDetents([.fraction(0.66)])
        .presentationDragIndicator(.visible)
    }
}

#endif  // canImport(UIKit)
