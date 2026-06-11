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
    /// v1.0.9 D2 — subtle 6s scale 1.0 ↔ 1.02 breathe on the shutter
    /// when nothing's happening. Started in onAppear with a repeating
    /// withAnimation. Reduce-motion users get a static shutter.
    @State private var shutterBreathing: Bool = false
    /// v1.0.9 D2 — scanning pill breathing pulse (replaces dim-state chip).
    @State private var scanPillBreathing: Bool = false

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

    /// v1.0.9 D2 round 2 — sticker confetti decoration that pops in
    /// at the four corners around the carousel card when a result
    /// lands. The wedge: Cal AI's reveal is a calorie number ticking
    /// up. JeniFit's reveal is your plate becoming a scrapbook entry
    /// in real time. Settles to 0.4 opacity as background decoration.

    @State private var baseZoom: CGFloat = 1.0
    @State private var liveZoom: CGFloat = 1.0
    @State private var zoomIndicatorVisible: Bool = false
    @State private var zoomHideTask: Task<Void, Never>?

    /// v1.0.8 Phase P — share sheet flag for the result mode share
    /// button. Wraps the frozen photo in a SwiftUI ShareLink-like
    /// affordance; iOS handles the system share sheet from there.
    @State private var showShareSheet: Bool = false

    /// v1.0.8 Phase Q (2026-06-08) — eagerly-rendered 1080×1920
    /// shareable image (photo + nutrition card + JeniFit watermark).
    /// Generated via ImageRenderer the moment the result lands, so
    /// the ShareLink can hand iOS a ready-to-go Story-format PNG with
    /// zero rendering latency at tap time.
    @State private var shareableImage: UIImage?

    /// v1.0.8 Phase R.3 — pre-encoded PNG slides for the multi-slide
    /// share picker. One entry per carousel page. Rendering AND PNG
    /// encoding happen up-front so the system share sheet pops
    /// instantly when the user taps share. Founder feedback: "whenever
    /// i click share button there is a lag (loading) before it pops
    /// up" — the old DataRepresentation closure was encoding PNG at
    /// share-tap time (~150ms for 1080×1920). Now the Data is cached.
    @State private var shareableSlides: [SlideShareItem] = []

    /// v1.0.8 Phase R.3 — share picker sheet flag.
    @State private var showSharePicker: Bool = false

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
            // v1.1 capture spec (2026-06-11): the SURROUND goes cream —
            // the camera reads as a polaroid being composed on the
            // desk, continuous with the rest of the app (and with the
            // PolaroidHero morph that follows). The frame INTERIOR
            // stays dark (functional letterbox/exposure floor) — the
            // only intentional black left in the flow.
            FoodTheme.bgPrimary.ignoresSafeArea()

            // v1.0.9 D2 polish round 3 — invisible 1×1 ScanningOverlay
            // prewarm. See `prewarmingScanCanvas` doc comment. Compiles
            // the Canvas Metal pipeline during the first 200ms after
            // appear so the user's first real scan tap doesn't pay the
            // cold-start cost.
            ScanningOverlay(isActive: prewarmingScanCanvas)
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

                    Spacer(minLength: 0)

                    bottomToolbar
                        .padding(.horizontal, FoodTheme.Space.lg)
                        .padding(.bottom, 4)
                }
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
        }
        .onDisappear {
            camera.unfreezePreview()
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

            // Hot pink border — uniform at rest, shimmer revolves
            // during scan.
            RotatingScanBorder(
                isScanning: isCapturing && !reduceMotion,
                isError: errorMessage != nil,
                cornerRadius: 28,
                lineWidth: 5
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
            } else if let result = capturedResult {
                resultModeOverlay(result: result)
                    .padding(14)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
            } else {
                inFrameChrome
                    .padding(14)
            }

            // v1.0.9 D2 — cherries idle sticker. Now uses the real
            // bundled asset from PlankApp/Assets.xcassets/Stickers
            // (sticker_cherries.png) via Bundle.main, matching the
            // sticker-discipline pattern in NutritionCarousel's
            // JeniEvaluationCard.
            if !isCapturing && capturedResult == nil && !galleryPreviewMode {
                Image("sticker_cherries", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-8))
                    .padding(.top, 18)
                    .padding(.leading, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity.combined(with: .scale(scale: 0.7)))
            }

        }
        .contentShape(Rectangle())
        .gesture(pinchZoomGesture)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: capturedResult != nil)
        .onChange(of: capturedResult != nil) { _, hasResult in
            // v1.0.9 D2 round 3 — soft haptic only on result-land.
            // The four-sticker confetti was removed because it
            // overlapped the carousel result card without adding
            // value (founder feedback 2026-06-08: "sticker placement
            // doesn't look so great, it's overlapping with cards,
            // and doesn't add any value"). The result card already
            // carries its own coquette chrome (cherries top-right
            // via the share card path); a second decoration layer
            // muddied the read instead of celebrating the moment.
            // The soft haptic alone is enough of a "got it ♥" beat.
            if hasResult {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            }
        }
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

                if !reduceMotion {
                    ScanningOverlay(isActive: isCapturing)
                }
            } else if camera.permissionStatus == .authorized {
                FoodCameraPreviewView(
                    previewLayer: camera.previewLayer,
                    isFrozen: camera.isPreviewFrozen
                )

                if !reduceMotion {
                    ScanningOverlay(isActive: isCapturing)
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
            camera.freezePreview()
            camera.freezeInstantly()
            // v1.0.9 D2 polish — pre-warmed Taptic Engine. See
            // `shutterHaptic` doc comment. Re-prepare so the next tap
            // is also instant.
            shutterHaptic.impactOccurred()
            shutterHaptic.prepare()
            AudioServicesPlaySystemSound(1108)
            Task { await captureTapped() }
        } label: {
            // v1.0.9 D2 — shutter revolves as a UNIT per founder + UX
            // expert. The ring + disc + 📷 sticker rotate together as
            // one sticker-on-spinning-coin object (NOT a white arc
            // swirling around a static button — that's dropped).
            //
            // Motion language:
            //   - idle: subtle 6s breathe (scale 1.0 ↔ 1.02) for
            //     alive-ness without dizziness
            //   - scanning: full 3.0s/revolution rotation, CCW
            //     (opposite of border's CW shimmer → parallax)
            //   - 📷 keeps its -4° tilt INSIDE the spinning parent so
            //     it reads as a sticker stuck to a coin, not a logo
            //   - reduce-motion: no rotation, no breathe
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: !(isCapturing && !reduceMotion))) { timeline in
                let elapsed = timeline.date.timeIntervalSinceReferenceDate
                let phase = (elapsed.truncatingRemainder(dividingBy: 3.0)) / 3.0
                let scanAngle = -phase * 360.0  // CCW

                ZStack {
                    Circle()
                        .stroke(FoodTheme.cameraScanPink, lineWidth: 4)
                        .frame(width: 78, height: 78)

                    Circle()
                        .fill(isCapturing ? FoodTheme.cameraScanDisc : Color.white)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.25), radius: 6, x: 0, y: 2)
                        // v1.0.9 D2 polish round 2 — snap the disc
                        // colour. Was 0.3s easeInOut; the soft fade
                        // delayed the visible "I'm scanning" signal
                        // by ~150ms after tap (perceived lag). The
                        // simultaneous TimelineView rotation + ring
                        // pink + scanning pill all change in the
                        // same frame so the moment lands together.
                        .animation(.linear(duration: 0.08), value: isCapturing)

                    // v1.0.9 D2 — bundled camera lineart sticker
                    // (PlankApp/Assets.xcassets/Stickers/sticker_camera_lineart.png)
                    // replaces the 📷 emoji. Same -4° baked tilt so it
                    // reads as a sticker stuck to the spinning disc.
                    Image("sticker_camera_lineart", bundle: .main)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .rotationEffect(.degrees(-4))
                        .accessibilityHidden(true)
                }
                .rotationEffect(.degrees(isCapturing && !reduceMotion ? scanAngle : 0))
                .scaleEffect(shutterBreathing && !reduceMotion ? 1.02 : 1.0)
            }
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
        } else if let result = capturedResult {
            resultActions(result: result)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
        } else {
            HStack(spacing: 0) {
                galleryButton
                    .opacity(isCapturing ? 0.35 : 1)
                    .allowsHitTesting(!isCapturing)

                Spacer()

                // v1.0.9 D2 polish — during scan, swap the chip cluster
                // for a JeniFit "scanning ♥" pill (accent rose fill +
                // italic-Fraunces punch word). Previously the chips
                // dimmed to 0.5 opacity which read as flat grey;
                // founder feedback: "chip loading state — grey
                // background needs to be improved with colors and
                // within jenifit." The pill signals progress and
                // carries brand voice instead of disabled state.
                if isCapturing {
                    scanningPill
                        .transition(.opacity)
                } else {
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

    /// v1.0.9 D2 polish — replaces the dimmed mode-chip cluster while
    /// a scan is in flight. Accent rose fill + white italic-Fraunces
    /// "scanning" punch word + terminal heart. Subtle breathing pulse
    /// (1.4s, scale 1.0↔1.04) reads as "thinking" without spinner
    /// noise. Reduce-motion safe (no breathe).
    @ViewBuilder private var scanningPill: some View {
        HStack(spacing: 6) {
            (
                Text(Image(systemName: "sparkle"))
                + Text(" ")
                + Text("scanning").font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                + Text(" ♥")
            )
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            Capsule().fill(FoodTheme.accent)
        )
        .overlay(
            Capsule().stroke(Color.white.opacity(0.35), lineWidth: 1)
        )
        .shadow(
            color: FoodTheme.accent.opacity(0.35),
            radius: 8, x: 0, y: 2
        )
        .scaleEffect(scanPillBreathing && !reduceMotion ? 1.04 : 1.0)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                scanPillBreathing = true
            }
        }
        .onDisappear { scanPillBreathing = false }
        .accessibilityLabel("scanning")
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
                Text("ready to ") + Text("scan").font(.custom("Fraunces72pt-SemiBoldItalic", size: 14)) + Text(" this one ♥")
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

    // MARK: - Result mode overlay + actions

    /// v1.0.8 Phase P — floating nutrition card that lands over the
    /// frozen captured photo. Mirrors the reference layout: white
    /// rounded rectangle, soft shadow, meal label + dish name + macro
    /// row. Sits in the upper third of the camera frame.
    @ViewBuilder
    private func resultModeOverlay(result: CapturedFood) -> some View {
        // v1.0.8 Phase Q — card sits at ~22% from the top of the
        // camera frame, NOT at the very top. Founder direction:
        // "make it near the food." In a portrait food photo the food
        // typically lives in the center-to-lower portion of the frame;
        // dropping the card down ~20% puts it just above the food
        // instead of in dead headroom. Same vertical position the
        // shareable 9:16 render uses, so the in-camera preview
        // matches what gets exported.
        // v1.0.8 Phase S (2026-06-08) — X button now FLOATS via ZStack
        // overlay instead of taking a row in the VStack. Founder ask:
        // "more space towards top for slide 2 + X button can be
        // floating." Result: the carousel gets ~50pt more vertical
        // space because the X close no longer reserves a top row. The
        // X overlays the top-right of the camera frame, always
        // tappable, but doesn't push the carousel down.
        GeometryReader { geo in
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 0) {
                    Spacer().frame(height: 8)

                    NutritionCarousel(
                        result: result,
                        carouselHeight: max(380, geo.size.height - 24),
                        onCorrect: { corrected in
                            // v1.0.8 Phase U — tweak applied. Update
                            // capturedResult so all 3 slides + the
                            // shareable export pick up the new
                            // numbers, then re-render the shareables
                            // off the new data.
                            capturedResult = corrected
                            if let photo = galleryImage ?? camera.frozenFrame {
                                Task { @MainActor in
                                    try? await Task.sleep(nanoseconds: 100_000_000)
                                    shareableSlides = renderAllShareableSlides(
                                        result: corrected,
                                        photo: photo
                                    )
                                    shareableImage = shareableSlides.first?.uiImage
                                }
                            }
                        }
                    )

                    Spacer(minLength: 0)
                }

                glassButton(systemName: "xmark", action: {
                    camera.unfreezePreview()
                    onDismiss()
                })
                .accessibilityLabel("close")
            }
        }
    }

    /// Bottom toolbar variant for result mode: skip ↶ — log it — share ↑.
    @ViewBuilder
    private func resultActions(result: CapturedFood) -> some View {
        HStack(spacing: 12) {
            // Skip → back to live camera.
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                camera.unfreezePreview()
                withAnimation(.easeInOut(duration: 0.3)) {
                    capturedResult = nil
                    galleryImage = nil
                }
                shareableImage = nil
                shareableSlides = []
            } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.ultraThinMaterial, in: Circle())
                    .colorScheme(.dark)
            }
            .accessibilityLabel("retake")

            // Log it — primary CTA, hot pink. v1.0.8 Phase R.5 — use
            // galleryImage when present (gallery upload path), fall
            // back to frozenFrame for camera captures.
            // v1.1 module pass — the hot-magenta capsule violated the
            // locked 8-token palette; this joins the one-CTA system
            // (56pt cocoa capsule, DM Sans SemiBold 16).
            Button {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onCaptured(result, galleryImage ?? camera.frozenFrame)
            } label: {
                Text("log it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Capsule().fill(FoodTheme.textPrimary))
            }

            // Share — v1.0.8 Phase Q exports the composed 9:16
            // shareable (photo + nutrition card + JeniFit watermark)
            // rendered via ImageRenderer when the result landed. Falls
            // back to the raw photo if the render hasn't completed.
            shareButton
        }
    }

    /// v1.0.8 Phase R.3 — share button now opens a picker sheet
    /// where the user chooses which slides to share. Founder direction:
    /// "share button should give users what slides they want to share
    /// like [tiktok download picker] and share the slides picked."
    ///
    /// Sheet shows a thumbnail per pre-rendered slide with a checkmark
    /// per item, a "select all" toggle, and a hot-pink "Share" CTA. On
    /// tap, the selected slides are handed to UIActivityViewController
    /// for the system share sheet.
    ///
    /// Falls back to a no-op disabled state until the slides are
    /// rendered (~200-400ms after the result lands). Pre-encoded PNG
    /// Data means the actual system share opens instantly when the
    /// user picks share targets — no DataRepresentation encoding lag.
    @ViewBuilder private var shareButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showSharePicker = true
        } label: {
            shareIconLabel
        }
        .accessibilityLabel("share")
        .disabled(shareableSlides.isEmpty)
        .opacity(shareableSlides.isEmpty ? 0.5 : 1)
        .sheet(isPresented: $showSharePicker) {
            SharePickerSheet(
                slides: shareableSlides,
                onClose: { showSharePicker = false }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder private var shareIconLabel: some View {
        Image(systemName: "square.and.arrow.up")
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.white)
            .frame(width: 48, height: 48)
            .background(.ultraThinMaterial, in: Circle())
            .colorScheme(.dark)
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

    private func nutritionTotals(_ food: CapturedFood) -> (carbs: Int, protein: Int, fat: Int, kcal: Int) {
        let c = food.items.compactMap { $0.carbsG }.reduce(0, +)
        let p = food.items.compactMap { $0.proteinG }.reduce(0, +)
        let f = food.items.compactMap { $0.fatG }.reduce(0, +)
        let k = food.totalKcal ?? Double((food.kcalLow ?? 0) + (food.kcalHigh ?? 0)) / 2
        return (
            carbs:   Int(c.rounded()),
            protein: Int(p.rounded()),
            fat:     Int(f.rounded()),
            kcal:    Int(k.rounded())
        )
    }

    /// v1.0.8 Phase R.3 — render all 3 carousel slides as 1080×1920
    /// shareables and pre-encode each to PNG Data. Runs on the main
    /// actor (ImageRenderer requires it) but the PNG encoding step
    /// is cheap on M-series silicon (~30-60ms per slide).
    @MainActor
    private func renderAllShareableSlides(
        result: CapturedFood,
        photo: UIImage
    ) -> [SlideShareItem] {
        let totals = nutritionTotals(result)
        let dish = dishNameLabel(result)
        let meal = mealTypeLabel

        let slides: [(SlideKind, AnyView)] = [
            (.meal, AnyView(
                ShareableFoodImageView(
                    photo: photo,
                    mealLabel: meal,
                    dishName: dish,
                    totals: totals
                )
                .frame(width: 1080, height: 1920)
            )),
            (.packedDaily, AnyView(
                ShareablePackedDailyView(
                    photo: photo,
                    result: result,
                    kcalTarget: shareableKcalTarget,
                    proteinTarget: shareableProteinTarget
                )
                .frame(width: 1080, height: 1920)
            )),
            (.jeni, AnyView(
                ShareableJeniView(
                    photo: photo,
                    result: result
                )
                .frame(width: 1080, height: 1920)
            )),
        ]

        return slides.compactMap { kind, view in
            let renderer = ImageRenderer(content: view)
            renderer.scale = 1.0
            renderer.proposedSize = ProposedViewSize(width: 1080, height: 1920)
            guard let img = renderer.uiImage else { return nil }
            guard let data = img.pngData() else { return nil }
            return SlideShareItem(
                kind: kind,
                uiImage: img,
                pngData: data,
                suggestedName: kind.suggestedFileName
            )
        }
    }

    /// V1 share targets — match the in-camera carousel's `kcalTarget`
    /// fallback. Real values land via @AppStorage once shared with
    /// NutritionCarousel.
    private var shareableKcalTarget: Int {
        let stored = UserDefaults.standard.double(forKey: "foodDailyTarget")
        return stored > 0 ? Int(stored) : 1950
    }

    private var shareableProteinTarget: Int {
        Int((Double(shareableKcalTarget) * 0.25) / 4)
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
    /// moment ♥" framing leaves the instructional register (center
    /// your plate) for an identity register that holds across any
    /// composition. Italic-Fraunces 15pt + tracking(0.3) gives it
    /// the polaroid-handwriting feel.
    @ViewBuilder private var microcopyText: some View {
        (
            Text("your ")
                .font(.system(size: 15))
            + Text("moment")
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
            + Text(" ♥")
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
        // v1.0.9 D2 — dining-out chip removed. Founder: "you can say
        // whatever in quicklog. we can bring back dining out when
        // product is more matured." The quick-log text path handles
        // restaurant orders (user types "chipotle chicken bowl" or
        // "starbucks iced latte"), so the standalone restaurant-
        // range estimator is dormant.
        //
        // Code preserved: ImOutTonightView, FoodCapture.imOutTonight,
        // FoodCaptureDispatcher arm, CaptureTab.imOut — all stay in
        // place so re-enabling later is a one-chip-add, not a
        // re-implementation.
        // v1.1 capture spec — the breathwork-intro chip register on
        // cream (emoji dropped per the v4 kill-list).
        HStack(spacing: 6) {
            modeChip("snap", .photo)
            modeChip("quick log", .quickAdd)
        }
    }

    @ViewBuilder
    private func modeChip(_ label: String, _ tab: CaptureTab) -> some View {
        let isActive = captureTab == tab
        Button {
            captureTab = tab
            switch tab {
            case .photo:    break
            case .quickAdd: onQuickAddTapped()
            case .imOut:    onImOutTapped()
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

            // v1.0.8 Phase R.3 — render all 3 carousel slides as 9:16
            // shareables AND pre-encode each to PNG Data. The render +
            // encode happen on the main actor (ImageRenderer is
            // @MainActor); PNG encoding via UIImage.pngData() can run
            // in parallel on a detached task per slide.
            //
            // Founder fix: "share button has lag (loading) before pop
            // up" — was caused by DataRepresentation closure encoding
            // PNG at share-tap time. Now Data is cached so the system
            // share sheet opens instantly.
            if let photo = camera.frozenFrame {
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    shareableSlides = renderAllShareableSlides(
                        result: result,
                        photo: photo
                    )
                    // First slide also kept on `shareableImage` for the
                    // legacy single-share fallback path.
                    shareableImage = shareableSlides.first?.uiImage
                }
            }
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
            #if DEBUG
            print("[PhotoCaptureView] capture failed: \(captureError)")
            #endif
            // v1.0.8 Phase S — route rate-limit / budget-cap errors
            // to the dedicated terminalError overlay; everything else
            // goes through the transient error banner.
            if let term = TerminalError.from(captureError) {
                terminalError = term
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "terminal_error",
                    "case": term.id,
                ])
            } else {
                errorMessage = captureError.errorDescription
                    ?? "couldn't read your plate just now. try again?"
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "capture_error",
                    "case": String(describing: captureError),
                ])
            }
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
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
                    galleryImage = nil
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

            // v1.0.8 Phase R.5 — set capturedResult to trigger the
            // inline carousel + result actions, render shareables off
            // the gallery photo, but DO NOT call onCaptured here. User
            // taps "log it" to actually persist.
            capturedResult = result

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                shareableSlides = renderAllShareableSlides(
                    result: result,
                    photo: image
                )
                shareableImage = shareableSlides.first?.uiImage
            }
        } catch let captureError as FoodCaptureError {
            #if DEBUG
            print("[PhotoCaptureView] library capture failed: \(captureError)")
            #endif
            // v1.0.8 Phase S — route terminal errors to the dedicated
            // overlay; everything else through the transient banner.
            if let term = TerminalError.from(captureError) {
                terminalError = term
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "terminal_error",
                    "source": "library",
                    "case": term.id,
                ])
            } else {
                errorMessage = captureError.errorDescription
                    ?? "couldn't read your plate just now. try again?"
                FoodAnalytics.track(.scanFallbackFired, properties: [
                    "reason": "capture_error",
                    "source": "library",
                    "case": String(describing: captureError),
                ])
            }
            phaseTask?.cancel()
            FoodScanActivity.end(handle: activityHandle)
            withAnimation(.easeOut(duration: 0.25)) {
                galleryImage = nil
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
                galleryImage = nil
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

// MARK: - NutritionCardView
//
// v1.0.8 Phase Q (2026-06-08) — extracted from PhotoCaptureView so the
// same card is used in two render contexts:
//   - In-camera overlay (scale 1.0, ~340pt wide on iPhone)
//   - Shareable image composition (scale 2.4, ~720pt on 1080×1920 canvas)
//
// `scale` multiplies font sizes, padding, corner radius, and shadow so
// both versions render at identical visual proportions on their target
// canvas. Default 1.0 = the in-camera render.

struct NutritionCardView: View {
    let mealLabel: String
    let dishName: String
    let totals: (carbs: Int, protein: Int, fat: Int, kcal: Int)
    let scale: CGFloat

    init(
        mealLabel: String,
        dishName: String,
        totals: (carbs: Int, protein: Int, fat: Int, kcal: Int),
        scale: CGFloat = 1.0
    ) {
        self.mealLabel = mealLabel
        self.dishName = dishName
        self.totals = totals
        self.scale = scale
    }

    var body: some View {
        // v1.0.8 Phase U (2026-06-08) — JeniFit-themed beautification.
        // Italic-Fraunces on the meal label + dish name (the brand
        // voice signal). Cream bgElevated background instead of pure
        // white. Cherry sticker overhanging the top-right corner per
        // the scrapbook chrome family. 1.5pt accent-rose border for
        // soft definition without going neon.
        VStack(alignment: .leading, spacing: 10 * scale) {
            Text(mealLabel.lowercased())
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13 * scale))
                .foregroundStyle(FoodTheme.accent)

            Text(dishName)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 20 * scale))
                .foregroundStyle(FoodTheme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Rectangle()
                .fill(FoodTheme.accent.opacity(0.18))
                .frame(height: 1)
                .padding(.vertical, 2 * scale)

            HStack(spacing: 0) {
                macroColumn(value: "\(totals.carbs)g", label: "carbs")
                macroDivider
                macroColumn(value: "\(totals.protein)g", label: "protein")
                macroDivider
                macroColumn(value: "\(totals.fat)g", label: "fat")
                macroDivider
                kcalColumn(value: "\(totals.kcal)")
            }
        }
        .padding(.horizontal, 18 * scale)
        .padding(.vertical, 14 * scale)
        .background(FoodTheme.bgElevated)
        .colorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 18 * scale, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18 * scale, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.4), lineWidth: 1.5)
        )
        .shadow(
            color: FoodTheme.textPrimary.opacity(0.18),
            radius: 0,
            x: 3 * scale,
            y: 3 * scale
        )
        .overlay(alignment: .topTrailing) {
            // Cherries sticker — scrapbook chrome signature. Real
            // bundled asset (sticker_cherries.png from
            // PlankApp/Assets.xcassets/Stickers) to match the rest
            // of the v1.0.9 D2 theming pass.
            Image("sticker_cherries", bundle: .main)
                .resizable()
                .scaledToFit()
                .frame(width: 40 * scale, height: 40 * scale)
                .rotationEffect(.degrees(12))
                .offset(x: 8 * scale, y: -12 * scale)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private func macroColumn(value: String, label: String) -> some View {
        VStack(spacing: 2 * scale) {
            Text(value)
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(FoodTheme.textPrimary)
            Text(label)
                .font(.system(size: 11 * scale))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func kcalColumn(value: String) -> some View {
        VStack(spacing: 2 * scale) {
            Text(value)
                .font(.system(size: 17 * scale, weight: .semibold))
                .foregroundStyle(Color(red: 0.37, green: 0.45, blue: 0.27))
            Text("kcal")
                .font(.system(size: 11 * scale))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var macroDivider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.07))
            .frame(width: 1, height: 22 * scale)
    }
}

// MARK: - ShareableFoodImageView
//
// v1.0.8 Phase Q — the 9:16 Instagram-Story canvas the share button
// exports. Photo fills the 1080×1920 background; nutrition card lands
// at ~22% from the top (where food typically sits in a portrait food
// photo, per the founder's reference images); JeniFit watermark at
// the bottom for organic acquisition. Rendered via ImageRenderer at
// scale 1 so the math is exact: 1080×1920 px.

struct ShareableFoodImageView: View {
    let photo: UIImage
    let mealLabel: String
    let dishName: String
    let totals: (carbs: Int, protein: Int, fat: Int, kcal: Int)

    var body: some View {
        ZStack(alignment: .top) {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1080, height: 1920)
                .clipped()

            // Soft top gradient for card legibility on bright photos.
            LinearGradient(
                colors: [
                    Color.black.opacity(0.25),
                    Color.black.opacity(0.05),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .frame(width: 1080, height: 960)

            VStack(spacing: 0) {
                Spacer().frame(height: 1920 * 0.22)

                NutritionCardView(
                    mealLabel: mealLabel,
                    dishName: dishName,
                    totals: totals,
                    scale: 2.4
                )
                .padding(.horizontal, 100)

                Spacer()

                // JeniFit watermark, italic-Fraunces.
                Text("JeniFit")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 56))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 2)
                    .padding(.bottom, 80)
            }
            .frame(width: 1080, height: 1920)
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

// MARK: - SlideKind

enum SlideKind: String, Hashable, CaseIterable {
    case meal
    case packedDaily
    case jeni

    var label: String {
        switch self {
        case .meal:        return "meal"
        case .packedDaily: return "nutrition"
        case .jeni:        return "jeni"
        }
    }

    var suggestedFileName: String {
        switch self {
        case .meal:        return "jenifit-meal.png"
        case .packedDaily: return "jenifit-nutrition.png"
        case .jeni:        return "jenifit-jeni.png"
        }
    }
}

// MARK: - SlideShareItem

/// A pre-rendered carousel slide ready for the system share sheet.
/// Holds both the UIImage (for the preview thumbnail) and the encoded
/// PNG Data (so DataRepresentation returns instantly at share time —
/// no encoding lag).
struct SlideShareItem: Identifiable, Hashable {
    let kind: SlideKind
    let uiImage: UIImage
    let pngData: Data
    let suggestedName: String

    var id: SlideKind { kind }

    static func == (lhs: SlideShareItem, rhs: SlideShareItem) -> Bool {
        lhs.kind == rhs.kind
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(kind)
    }
}

// MARK: - ShareableFoodImage (Transferable)

/// Transferable wrapper that hands iOS pre-encoded PNG Data — zero
/// encoding work happens at share time. v1.0.8 Phase R.3.
struct ShareableFoodImage: Transferable {
    let pngData: Data
    let uiImage: UIImage
    let suggestedName: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
        .suggestedFileName { $0.suggestedName }
    }
}

// MARK: - ShareablePackedDailyView
//
// v1.0.8 Phase R.3 — 9:16 composition for slide 2. Photo background +
// 3 stacked nutrition cards (daily totals / lifestyle / nutrients) +
// JeniFit watermark. Scaled 2.4× to match the canvas size.

struct ShareablePackedDailyView: View {
    let photo: UIImage
    let result: CapturedFood
    let kcalTarget: Int
    let proteinTarget: Int

    var body: some View {
        ZStack(alignment: .top) {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1080, height: 1920)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.10),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .frame(width: 1080, height: 1080)

            VStack(spacing: 20) {
                Spacer().frame(height: 1920 * 0.05)

                // v1.0.8 Phase R.6 — all 3 cards composed on the
                // shareable, matching the in-camera slide 2 layout.
                // Scale dropped 2.4 → 1.9 to fit DailyTotals +
                // Lifestyle + Nutrients comfortably within the 1920pt
                // canvas height (3 cards × ~280pt scaled + gaps +
                // top/bottom spacers ≈ 1620pt, leaves room for the
                // JeniFit watermark + breathing room above/below).
                ShareDailyTotalsBlock(
                    result: result,
                    kcalTarget: kcalTarget,
                    proteinTarget: proteinTarget,
                    scale: 1.9
                )
                .padding(.horizontal, 80)

                ShareLifestyleBlock(result: result, scale: 1.9)
                    .padding(.horizontal, 80)

                ShareNutrientsBlock(result: result, scale: 1.9)
                    .padding(.horizontal, 80)

                Spacer()

                Text("JeniFit")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 56))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 2)
                    .padding(.bottom, 60)
            }
            .frame(width: 1080, height: 1920)
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

// MARK: - ShareableJeniView
//
// v1.0.8 Phase R.3 — 9:16 composition for slide 3. Photo background +
// Jeni's evaluation card centered + JeniFit watermark.

struct ShareableJeniView: View {
    let photo: UIImage
    let result: CapturedFood

    var body: some View {
        ZStack(alignment: .top) {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 1080, height: 1920)
                .clipped()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.32),
                    Color.black.opacity(0.05),
                    Color.clear,
                ],
                startPoint: .top,
                endPoint: .center
            )
            .frame(width: 1080, height: 1080)

            VStack {
                Spacer().frame(height: 1920 * 0.16)

                ShareJeniBlock(result: result, scale: 2.4)
                    .padding(.horizontal, 100)

                Spacer()

                Text("JeniFit")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 56))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.5), radius: 8, x: 0, y: 2)
                    .padding(.bottom, 80)
            }
            .frame(width: 1080, height: 1920)
        }
        .frame(width: 1080, height: 1920)
        .clipped()
    }
}

// MARK: - SharePickerSheet
//
// v1.0.8 Phase R.3 — bottom sheet that mirrors TikTok's "Select photos
// to download" picker. Horizontal thumbnail row of carousel slides
// (one per pre-rendered SlideShareItem), each with a hot-pink checkmark
// in the top-right corner. "Select all" toggle on the left, "Share"
// CTA on the right. All slides selected by default.
//
// Tapping "Share" presents UIActivityViewController via a UIKit bridge
// (SwiftUI ShareLink doesn't accept dynamic per-item selection from a
// closure cleanly).

struct SharePickerSheet: View {
    let slides: [SlideShareItem]
    let onClose: () -> Void

    @State private var selectedKinds: Set<SlideKind>
    @State private var presentingActivity: Bool = false

    init(slides: [SlideShareItem], onClose: @escaping () -> Void) {
        self.slides = slides
        self.onClose = onClose
        // Default: all selected.
        _selectedKinds = State(initialValue: Set(slides.map { $0.kind }))
    }

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("share to social")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(FoodTheme.textPrimary)
                Spacer()
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.05), in: Circle())
                }
                .accessibilityLabel("close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(slides) { slide in
                        thumbnail(for: slide)
                    }
                }
                .padding(.horizontal, 20)
            }
            .frame(height: 230)

            Spacer()

            HStack {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if selectedKinds.count == slides.count {
                        selectedKinds.removeAll()
                    } else {
                        selectedKinds = Set(slides.map { $0.kind })
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: selectedKinds.count == slides.count
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.system(size: 18))
                            .foregroundStyle(selectedKinds.count == slides.count
                                             ? FoodTheme.textPrimary
                                             : FoodTheme.textSecondary)
                        Text("select all")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(FoodTheme.textPrimary)
                    }
                }

                Spacer()

                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    presentingActivity = true
                } label: {
                    Text("share")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(
                            Capsule().fill(
                                selectedKinds.isEmpty
                                ? Color.gray.opacity(0.4)
                                : FoodTheme.textPrimary
                            )
                        )
                        .shadow(color: FoodTheme.textPrimary
                                    .opacity(selectedKinds.isEmpty ? 0 : 0.3),
                                radius: 8, x: 0, y: 2)
                }
                .disabled(selectedKinds.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(FoodTheme.bgElevated)
        .colorScheme(.light)
        .sheet(isPresented: $presentingActivity) {
            ShareActivityView(
                items: selectedSlides.map { $0.uiImage as Any },
                onComplete: {
                    presentingActivity = false
                    onClose()
                }
            )
        }
    }

    private var selectedSlides: [SlideShareItem] {
        slides.filter { selectedKinds.contains($0.kind) }
    }

    @ViewBuilder
    private func thumbnail(for slide: SlideShareItem) -> some View {
        let isSelected = selectedKinds.contains(slide.kind)
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if isSelected {
                selectedKinds.remove(slide.kind)
            } else {
                selectedKinds.insert(slide.kind)
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                Image(uiImage: slide.uiImage)
                    .resizable()
                    .aspectRatio(9.0 / 16.0, contentMode: .fit)
                    .frame(width: 120, height: 213)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(isSelected
                                    ? FoodTheme.textPrimary
                                    : Color.black.opacity(0.08),
                                    lineWidth: isSelected ? 3 : 1)
                    )

                ZStack {
                    Circle()
                        .fill(isSelected
                              ? FoodTheme.textPrimary
                              : Color.white)
                        .overlay(
                            Circle().stroke(Color.black.opacity(0.06), lineWidth: 1)
                        )
                        .frame(width: 26, height: 26)
                        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 1)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(8)
            }
        }
        .buttonStyle(.plain)
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
                Text("got it ♥")
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
        VStack(spacing: 18) {
            HStack {
                Text("use this photo?")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
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
            .padding(.top, 8)

            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 340)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            FoodTheme.textPrimary,
                            lineWidth: 3
                        )
                )
                .padding(.horizontal, 20)
                .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: 4)

            Spacer()

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
                    Text("scan this")
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(FoodTheme.bgElevated)
        .colorScheme(.light)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

#endif  // canImport(UIKit)
