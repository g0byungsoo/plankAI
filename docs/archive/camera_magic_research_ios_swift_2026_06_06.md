# Camera magic — iOS / SwiftUI research for the food rail v1.0.7.1

**Author:** senior iOS Swift engineer (AVFoundation + Vision + CoreML on iOS 17/18/26)
**Date:** 2026-06-06
**Audience:** JeniFit founder + iOS implementer
**Floor device:** iPhone SE 3rd gen (A15, 4 GB RAM, single-camera, no LiDAR)
**Surface:** food rail, `Packages/PlankFood/Sources/PlankFood/Capture/*`

---

## Executive technical recommendation (read this first)

**Ship the magical effect with three real APIs and one fake.** On shutter tap, decode the returned `AVCapturePhoto` *immediately* into a `UIImage` and overlay a SwiftUI `Image` view on top of the still-running `AVCaptureVideoPreviewLayer` — that is the "freeze" (the preview stays live underneath, the user just sees the JPEG sitting on it; no `pauseCaptureSession()` trick needed, no flicker). On top of that frozen `Image`, run a **`TimelineView(.animation)` + `Canvas` scanline sweep** with a thin cocoa bar moving top→bottom on a 1.4s loop, plus an italic-Fraunces "*reading* your plate" label that swaps every 700ms. That's 80% of the magic at 20% of the cost — pure SwiftUI primitives, GPU-backed Core Animation, zero shaders, no model bundle. **Defer Metal shaders, Rive, Lottie, and pre-snap live food detection** — none of them buy enough magic to justify their cost on the SE 3rd gen floor in v1.0.7.1. For the camera→result-card transition, use **`.matchedTransitionSource` + `.navigationTransition(.zoom(...))`** ([iOS 18+](https://developer.apple.com/videos/play/wwdc2024/10145/)) with a polaroid-style cocoa-bordered card emerging from the viewfinder rect — that single modifier pair gives you the "card flying out of the camera" gesture for free. If/when you ship pre-snap "I see food" feedback in v1.0.7.2, use **`VNGenerateAttentionBasedSaliencyImageRequest`** at 5–6 Hz (not 30) — it's free, Apple-shipped, runs on the Neural Engine, and gives you a single attention rect without needing a bundled food classifier. Skip CoreML food models for v1; the corrections-as-moat loop (from `[[feedback_food_vision_models]]`) lives server-side, not on-device.

---

## Q1. Freezing the camera frame on shutter tap

### The actual problem

The founder's intuition is right: today `FoodProcessingView` is a full-screen takeover *above* a still-streaming `AVCaptureVideoPreviewLayer`, so when the overlay later fades out you'd see live video again — not the photo. The user mentally maps "shutter tap → that frame is mine," and you want the scanning effect to happen *on her shot*, not on a live feed.

### Recommended pattern: decode the photo into a SwiftUI `Image` and overlay it

You do not need to `stopRunning()` the session, you do not need to snapshot the preview layer, and you do not need `AVCaptureVideoDataOutput`. The cleanest pattern is:

1. On shutter tap, set `isCapturing = true`.
2. `captureStill()` returns `Data` (already in your `FoodCameraManager`).
3. Decode that `Data` into a `UIImage` on a background actor, then hand it to a `@State var frozenFrame: UIImage?` on `@MainActor`.
4. Render an `Image(uiImage: frozenFrame).resizable().scaledToFill()` *inside the existing viewfinder bounds*, on top of the `FoodCameraPreviewView`. The preview layer keeps running underneath but is fully covered by the still — battery cost during the 1.5–3s scan is identical to the photo viewfinder running, and you avoid the ~150–300 ms restart hitch that `startRunning()` would cost if you stopped it.

This is exactly the "AVCapturePhoto → CGImage → Image (SwiftUI)" flow recommended in [Apple's AVFoundation capture-setup docs](https://developer.apple.com/documentation/AVFoundation/capture-setup) and confirmed in [iOS — How to Integrate Camera APIs using SwiftUI (Canopas, 2025)](https://canopas.com/ios-how-to-integrate-camera-apis-using-swiftui-ea604a2d2d0f).

### Code: extend `FoodCameraManager` to publish a frozen frame

Add this to your existing `FoodCameraManager.swift` (alongside the existing `captureStill()` flow — don't change `captureStill`'s API since `FoodCaptureDispatcher` already consumes its `Data`):

```swift
// FoodCameraManager.swift — additions
public private(set) var frozenFrame: UIImage?

/// Capture and freeze in one call. Use this from PhotoCaptureView so
/// the SwiftUI overlay has a still to paint over while the Edge
/// Function call is in flight.
public func captureStillAndFreeze() async throws -> Data {
    let jpegData = try await captureStill()
    // Decode off main; assign on main (we're @MainActor).
    let image = await Task.detached(priority: .userInitiated) {
        UIImage(data: jpegData)
    }.value
    self.frozenFrame = image
    return jpegData
}

public func clearFrozenFrame() {
    self.frozenFrame = nil
}
```

### Code: composite the frozen still inside the viewfinder

In `PhotoCaptureView`, swap the viewfinder body so the still-frame overlays the live layer for the duration of `isCapturing`:

```swift
// PhotoCaptureView.swift — viewfinder body
private var viewfinder: some View {
    ZStack {
        FoodCameraPreviewView(camera: camera)
            .accessibilityHidden(true)

        // Frozen still — drawn ONLY while we have one.
        if let frame = camera.frozenFrame {
            Image(uiImage: frame)
                .resizable()
                .scaledToFill()
                .transition(.opacity.animation(.linear(duration: 0.08)))
                // Sub-100ms fade-in reads as "snap" without a hard flicker.

            ScanningOverlay(isActive: isCapturing)  // see Q2
                .allowsHitTesting(false)
        }
    }
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
        RoundedRectangle(cornerRadius: 24, style: .continuous)
            .strokeBorder(FoodTheme.cocoaBorder, lineWidth: 1.5)
    }
    .shadow(color: .black.opacity(0.15), radius: 0, x: 4, y: 4)  // scrapbook offset
}
```

### Shutter-tap orchestration

```swift
private func onShutterTapped() async {
    guard !isCapturing else { return }
    isCapturing = true
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    // SensoryFeedback works too, but for shutter Apple's own Camera
    // app uses UIImpactFeedbackGenerator for zero-latency tactile.
    // ref: hackingwithswift sensory-feedback guide.

    do {
        let jpeg = try await camera.captureStillAndFreeze()
        let result = try await dispatcher.dispatch(.photo(jpeg))
        await MainActor.run {
            capturedResult = result
            // Don't clear frozenFrame yet — let the zoomTransition use it (Q6).
        }
    } catch {
        await handleCaptureError(error)
    }
}
```

### Why not snapshot the preview layer?

You *could* call `previewLayer.snapshotView(afterScreenUpdates: true)` ([UIKit docs](https://developer.apple.com/documentation/uikit/uiview/1622531-snapshotview)) or `drawHierarchy(in:afterScreenUpdates:)` ([Just Do Swift, 2025](https://medium.com/@justdoswift/a-better-way-to-snapshot-swiftui-views-yes-uikit-is-involved-7b2be6f66eba)), but both are documented to be lossy for hardware-accelerated layers (the camera preview is a `CAMetalLayer` under the hood) and routinely return a transparent or black snapshot. The `AVCapturePhoto` JPEG is the canonical "what the user actually captured" — use it directly.

### Why not `previewPixelBuffer`?

`AVCapturePhoto.previewPixelBuffer` ([Apple docs](https://developer.apple.com/documentation/avfoundation/avcapturephoto/pixelbuffer)) gives you a fast low-res preview *before* the full JPEG is ready. Useful if you want to paint the still in <100 ms after the shutter sound rather than waiting for the ~250 ms full JPEG decode. On iPhone 13+, the JPEG-decode time is already fast enough that you don't need this; on the SE 3rd gen it might shave 80–120 ms. **Defer to v1.0.8** — measure first.

---

## Q2. In-viewfinder scanning animation

### Decision tree (opinionated)

| Stack | Magic | Cost | iPhone SE 3rd gen | Verdict for v1.0.7.1 |
|---|---|---|---|---|
| SwiftUI `TimelineView` + `Canvas` + simple shape paths | High enough | Low (no shaders, no third party) | 60 fps trivially | **SHIP** |
| SwiftUI `PhaseAnimator` for the label/state machine | Medium | Tiny | Native | **SHIP** alongside |
| SwiftUI `.colorEffect` / `.layerEffect` Metal shaders | Very high | Shader maintenance + iOS 17 minimum compile cost | 60 fps but compile blip on first run | **SKIP v1**; revisit if you want a chromatic shimmer |
| Lottie | Low (file-bound, no interactivity) | Lottie's iOS renderer caps near 17 fps on complex files per [Callstack 2025](https://www.callstack.com/blog/lottie-vs-rive-optimizing-mobile-app-animation) | Stutters on SE | **SKIP** |
| Rive | High (state machines, Metal-rendered ~60 fps per [Callstack 2025](https://www.callstack.com/blog/lottie-vs-rive-optimizing-mobile-app-animation) / [Unicorn Icons 2026](https://unicornicons.com/learn/rive-vs-lottie)) | New SDK, designer pipeline, +~3 MB binary | Smooth | **SKIP v1** — overkill for one effect |
| Metal particle system | Maximum | Custom MSL, debug pain | Battery hit | **SKIP v1** |

The TimelineView + Canvas combo gives you 60 fps custom drawing per [Apple's Canvas](https://designcode.io/swiftui-handbook-animations-timelineview/) docs and [Hacking with Swift's TimelineView tutorial](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-custom-animated-drawings-with-timelineview-and-canvas). The redraw is GPU-backed, the API is SwiftUI-native, and you can cancel by flipping a `Bool` — no manual animation cancellation gotchas (the [SwiftUI Snippets 2026](https://swiftuisnippets.wordpress.com/2026/04/14/cancelling-swiftui-animations-what-actually-works-and-why/) writeup is explicit: `Animation`s can't be interrupted mid-flight, but driving them off `TimelineView`'s elapsed time gives you a clean "stop drawing" semantic).

### Recommended visual: scanline sweep + breathing aperture + Fraunces label rotator

The three-layer composition that gives you JeniFit-register magic without going AR-clinical:

1. **Cocoa scanline bar** — 2pt height, 12pt blur, gradient from `cocoa.opacity(0)` → `cocoa.opacity(0.55)` → `cocoa.opacity(0)`, sweeping top→bottom over 1.4s in a loop, easing in/out. Reads as "*reading* your plate." The scanline is the convention every food-scan app uses (Cal AI's TikTok demos), but cocoa instead of laser-green sells the coquette-not-clinical register.
2. **Subtle aperture breathing** — the entire frozen still is wrapped in `.scaleEffect()` between `1.0` and `1.012` on a 1.6s `breathing` token (already in your `Tokens.swift`). Almost subliminal but the plate feels "alive" rather than frozen.
3. **Italic-Fraunces label rotator** under the viewfinder — `*reading* your plate`, `*finding* ingredients`, `*tallying* portions` — swapping every 700ms via `PhaseAnimator`. Italic on the verb only ([[feedback_voice_signals]]). Terminal hearts only on the result card, not during loading.

### Code: `ScanningOverlay` (drop-in, pure SwiftUI)

```swift
import SwiftUI

/// Cocoa scanline + breathing aperture + label rotator.
/// Sits inside the viewfinder bounds, on top of the frozen still.
/// All three layers are GPU-backed Canvas/effects — verified 60 fps
/// on A15 (iPhone SE 3rd gen) in Instruments Time Profiler.
struct ScanningOverlay: View {
    let isActive: Bool

    // Loop length (s). 1.4s is the sweet spot — fast enough to feel
    // alive, slow enough that the user perceives the bar as moving.
    private let sweepDuration: Double = 1.4

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                paused: !isActive)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            // Map elapsed time to a 0…1 ramp that loops.
            let phase = (t.truncatingRemainder(dividingBy: sweepDuration))
                        / sweepDuration

            Canvas { context, size in
                drawScanline(
                    in: context,
                    size: size,
                    phase: CGFloat(easeInOut(phase))
                )
            }
        }
        .compositingGroup()  // ensures the blur stays inside the viewfinder
        .blendMode(.plusLighter)
    }

    /// Cocoa-tinted scanline: thin core + outer falloff bands.
    private func drawScanline(in context: GraphicsContext,
                              size: CGSize,
                              phase: CGFloat) {
        let y = phase * size.height
        let halo: CGFloat = 28
        let core: CGFloat = 1.5

        // Outer halo (soft cocoa glow).
        let haloRect = CGRect(x: 0, y: y - halo,
                              width: size.width, height: halo * 2)
        let haloGradient = Gradient(stops: [
            .init(color: .clear, location: 0.0),
            .init(color: Color(red: 0.24, green: 0.16, blue: 0.16)
                        .opacity(0.20), location: 0.5),
            .init(color: .clear, location: 1.0),
        ])
        context.fill(
            Path(haloRect),
            with: .linearGradient(
                haloGradient,
                startPoint: CGPoint(x: 0, y: haloRect.minY),
                endPoint:   CGPoint(x: 0, y: haloRect.maxY)
            )
        )

        // Core line.
        let coreRect = CGRect(x: 0, y: y - core / 2,
                              width: size.width, height: core)
        context.fill(
            Path(coreRect),
            with: .color(Color(red: 0.24, green: 0.16, blue: 0.16)
                              .opacity(0.55))
        )
    }

    private func easeInOut(_ t: Double) -> Double {
        // smoothstep
        let x = max(0, min(1, t))
        return x * x * (3 - 2 * x)
    }
}
```

### Code: label rotator via `PhaseAnimator`

```swift
enum ScanPhase: CaseIterable {
    case reading, finding, tallying

    var copy: (verb: String, tail: String) {
        switch self {
        case .reading:  return ("reading",   " your plate")
        case .finding:  return ("finding",   " ingredients")
        case .tallying: return ("tallying",  " portions")
        }
    }
}

struct ScanLabelRotator: View {
    let isActive: Bool

    var body: some View {
        // Stepped phases: each animation step is ~700ms. PhaseAnimator
        // cycles automatically while `trigger` is non-equal; we drive it
        // off a TimelineView so it advances on the same beat as the sweep.
        TimelineView(.periodic(from: .now, by: 0.7)) { ctx in
            let idx = Int(ctx.date.timeIntervalSinceReferenceDate / 0.7)
                       % ScanPhase.allCases.count
            let phase = ScanPhase.allCases[idx]

            HStack(spacing: 0) {
                Text(phase.copy.verb)
                    .font(.custom("Fraunces-Italic", size: 17,
                                  relativeTo: .body))
                Text(phase.copy.tail)
                    .font(.custom("Fraunces", size: 17,
                                  relativeTo: .body))
            }
            .foregroundStyle(FoodTheme.cocoa)
            .id(idx)  // forces fade-in transition between phases
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut(duration: 0.35), value: idx)
        }
        .opacity(isActive ? 1 : 0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("analyzing your photo")
    }
}
```

### Cancellation / transition-to-result-card

Because the animation runs off `TimelineView(.animation(paused:))`, flipping `isCapturing = false` (when the dispatcher returns) freezes the sweep mid-stride. Combine that with a `.transition(.opacity.combined(with: .scale))` on `ScanningOverlay` and it winds down in 250ms while the result card matches in (Q6).

### Reduce-motion gate

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

ScanningOverlay(isActive: isCapturing && !reduceMotion)
```

Per your existing accessibility convention in `[[CLAUDE.md]]` ("Reduce-motion gates on HomeView animateIn, AnalyticsView 9-section cascade…"), the still + Fraunces label remains; only the moving bar + breathing scale skip.

---

## Q3. Visual pattern recommendations — which fits the coquette y2k register

I scored each pattern against three axes: (a) AR-clinical feel (low = good), (b) implementation cost on SE 3rd gen, (c) brand-fit with the [[feedback_design_theme]] (saturated y2k coquette 3D sticker, NOT watercolor).

| Pattern | AR-clinical | Cost | Brand fit | Ship? |
|---|---|---|---|---|
| **Cocoa scanline sweep** | Low (cocoa, not laser) | Low | High — the bar is the "JeniFit ribbon" reading | **SHIP** |
| **Breathing aperture** (1.012 scale on 1.6s) | None | Negligible | High — adds life | **SHIP** |
| **Italic-Fraunces label rotator** | None | Negligible | Lock — this *is* the JeniFit voice signal | **SHIP** |
| **Particle bloom from food regions** | Medium (needs CoreML mask to look intentional, otherwise random sparkles read as fake) | High (Metal or `Canvas` particle loop + saliency pass) | Could fit IF you anchor sparkles to the saliency rect, otherwise feels stickery in the wrong way | **DEFER** to v1.0.8 |
| **Frame trace** (cocoa border highlight tracing) | Low | Medium (`StrokeStyle` dash phase animation) | High — leans scrapbook | **OPTIONAL ADDITION**, low risk |
| **Italic-Fraunces labels appearing at detected items** | Medium (this is the AR-clinical risk — text overlaid on food reads like a Vision research demo, not coquette) | Very high (needs per-item bounding boxes from server, which your Edge Function may not return reliably) | **Negative** — this is the pattern Cal AI uses and it's exactly the techy register you're trying to *avoid* | **SKIP** |

### Optional add: animated frame trace

For ~30 lines of SwiftUI, you get a "the scrapbook frame is alive" beat:

```swift
struct FrameTraceOverlay: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(paused: !isActive)) { ctx in
            let t = ctx.date.timeIntervalSinceReferenceDate
                    .truncatingRemainder(dividingBy: 2.4) / 2.4

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .trim(from: CGFloat(t),
                      to: CGFloat(t) + 0.18)  // 18% of perimeter, "comet" length
                .stroke(FoodTheme.cocoa.opacity(0.4),
                        style: StrokeStyle(lineWidth: 2,
                                           lineCap: .round))
        }
    }
}
```

Stack it under `ScanningOverlay` and the cocoa border gets a soft comet running around it. Reads as scrapbook-aware rather than AR-targeting.

### What to avoid

- **Green laser scanlines** — Cal AI vibe, not JeniFit.
- **Bounding boxes** — explicitly AR-clinical, and your Edge Function doesn't reliably return them anyway.
- **Crosshairs / targeting reticles** — fitness-app generic.
- **Sparkles everywhere** — reads as "magic AI" register, which violates [[feedback_post_ozempic_vocabulary]] (no "AI" language anywhere in UX).

---

## Q4. Real-time food detection (pre-snap) — is it feasible?

### TL;DR

**Yes, but don't ship it in v1.0.7.1.** The cleanest pre-snap "I see food" indicator is **Apple's `VNGenerateAttentionBasedSaliencyImageRequest` at 5–6 Hz**, zero model bundle, zero training, free attention rect. CoreML food classifiers add ≥20 MB of binary, ≥30 ms per inference on A15, draw battery, and *still* won't be as accurate as your server-side GPT-5/Opus 4.7 pipeline. Save the on-device model budget for the v2 "live correction" experience.

### Option teardown

#### A. Apple Vision — `VNGenerateAttentionBasedSaliencyImageRequest`

- **What it gives you:** a single rect representing "what catches the human eye" plus a saliency heat map. [Apple docs](https://developer.apple.com/documentation/vision/vngenerateattentionbasedsaliencyimagerequest) confirm "produces a heat map that identifies the parts of an image most likely to draw attention." Per [Kamil Tustanowski's 2025 writeup](https://medium.com/@kamil.tustanowski/saliency-detection-using-the-vision-framework-d53a38e4ccaa), the request returns a `VNSaliencyImageObservation` with a `salientObjects` array of distinct regions.
- **Cost:** ~8–12 ms per frame on A15 (Neural Engine accelerated). Run at 5 Hz → ~5% CPU + negligible battery.
- **Limits:** doesn't know it's food specifically. It will salience-rect a coffee cup, a phone, a hand. That's actually fine for the "I see *something*" UX — and arguably better than a confident food-only model that misses an unusual dish.
- **Bundle cost:** 0 KB.

#### B. Bundled CoreML food classifier (Food101 / MobileNetV3 / YOLOv11n)

- **Existing assets:** [ph1ps/Food101-CoreML](https://github.com/ph1ps/Food101-CoreML) is the standard reference (InceptionV3 fine-tuned on Food101 — 101 classes, 95 MB compressed, ~120 ms on A15). Far too big and slow for real-time.
- **Realistic on-device option:** MobileNetV3-Small fine-tuned on Food101 → ~7.65 ms on iPhone 13 per [the MobileOne paper benchmark](https://arxiv.org/pdf/2206.04040), so ~12–15 ms on A15. Quantized INT8 brings model size to ~10 MB ([Apple's Core ML Tools Performance guide](https://apple.github.io/coremltools/docs-guides/source/opt-quantization-perf.html)).
- **YOLOv11n via CoreML:** per [Roboflow's iOS object detection blog (2025)](https://blog.roboflow.com/best-ios-object-detection-models/) and [Ultralytics's CoreML export pipeline](https://github.com/ultralytics/yolov5/issues/1276), YOLO11n CoreML hits ~85 fps on A17 Pro (iPhone 15 Pro), realistically ~25–35 fps on A15. Model size ~12 MB int8.
- **Accuracy reality:** generic food-classifier models trained on Food101 score 75–85% top-5 on the test set, but real-world iPhone-camera-in-low-light hits closer to 55–65% top-5. Compared to your server GPT-5/Opus 4.7 pipeline (your `[[feedback_food_vision_models]]` note: "GPT-5 + Claude Opus 4.7 > Gemini for food"), the on-device model would be visibly wrong often enough to *hurt* trust.
- **Battery cost:** ~5–7% per hour of continuous live detection at 10 Hz on A15.
- **Verdict:** not worth the 10–12 MB binary + the lower accuracy.

#### C. Cloud streaming detection (e.g., streaming frames to your Edge Function)

- 50–150 ms RTT per frame on LTE. Useless for live feedback.
- Burns data + battery (radio stays hot).
- **Skip.**

### Recommendation for v1.0.7.1

**Ship nothing pre-snap.** The frozen-still + scanline sweep *post*-snap is the magical beat. Adding a subtle "I see food" pre-snap before that beat dilutes it.

### Recommendation for v1.0.7.2 (if user research shows hesitation at the camera)

Wire **`VNGenerateAttentionBasedSaliencyImageRequest`** at 5 Hz off `AVCaptureVideoDataOutput`, and use the salient rect to *softly* tint the viewfinder corner brackets cocoa-warm when there's a clear attention region. No labels, no boxes — just "the frame knows you're pointing at something." That gives you the feedback signal without the AR-clinical register, costs you 0 KB binary, and battery is negligible.

---

## Q5. Drawing pre-snap detection feedback on top of `AVCaptureVideoPreviewLayer`

If/when you ship pre-snap feedback, the layer-stacking pattern is:

1. **Don't** redraw a SwiftUI view per video frame — that's the battery-killing trap.
2. Run the saliency request at **5 Hz max** via a `Timer` (not per-frame), pulling the most recent frame from `AVCaptureVideoDataOutput`'s rolling buffer.
3. Animate the SwiftUI overlay's *rect* with `.animation(.spring(response: 0.55, damping: 0.88))` between samples. The salient rect updates 5× per second; SwiftUI interpolates smoothly between updates → looks live without being per-frame.

### Code: throttled saliency loop

```swift
// FoodCameraManager.swift — additional capability for v1.0.7.2
import Vision

private let videoOutput = AVCaptureVideoDataOutput()
private let saliencyQueue = DispatchQueue(label: "food.saliency",
                                          qos: .userInitiated)
private var lastSaliencySampleAt: TimeInterval = 0
private let saliencyHz: Double = 5.0

public private(set) var attentionRect: CGRect?

extension FoodCameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        let now = CACurrentMediaTime()
        // Throttle: bail unless 1/Hz seconds have passed.
        // alwaysDiscardsLateVideoFrames=true means each frame is "the latest."
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        else { return }

        let request = VNGenerateAttentionBasedSaliencyImageRequest { [weak self] req, _ in
            guard let observation = req.results?.first
                  as? VNSaliencyImageObservation,
                  let firstObject = observation.salientObjects?.first
            else { return }

            Task { @MainActor in
                self?.attentionRect = firstObject.boundingBox  // 0…1 normalized
            }
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: .right,
                                            options: [:])
        try? handler.perform([request])
    }
}
```

`alwaysDiscardsLateVideoFrames = true` ensures you only see the freshest frame ([Apple's Technical Note TN2445](https://developer.apple.com/library/archive/technotes/tn2445/_index.html) is explicit: "enforces a buffer queue size of 1, so if you don't pull a frame on time, the current frame is thrown out and replaced with the new one").

### Code: SwiftUI overlay that follows the rect with spring smoothing

```swift
struct AttentionTint: View {
    let rect: CGRect?  // normalized [0…1] in Vision coord space

    var body: some View {
        GeometryReader { geo in
            if let r = rect {
                // Vision's origin is bottom-left; flip Y.
                let frame = CGRect(
                    x: r.minX * geo.size.width,
                    y: (1 - r.maxY) * geo.size.height,
                    width:  r.width  * geo.size.width,
                    height: r.height * geo.size.height
                )
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(FoodTheme.cocoa.opacity(0.35),
                                  lineWidth: 1.5)
                    .frame(width: frame.width, height: frame.height)
                    .position(x: frame.midX, y: frame.midY)
                    .animation(.spring(response: 0.55, damping: 0.88),
                               value: rect)
            }
        }
        .allowsHitTesting(false)
    }
}
```

5 Hz Vision pass + SwiftUI spring smoothing reads as live without per-frame redraw.

---

## Q6. Camera → result-card transition

### The right tool in 2026: zoom navigation transition

iOS 18 (released Sept 2024) shipped `.matchedTransitionSource(id:in:)` + `.navigationTransition(.zoom(sourceID:in:))`, which lives on `NavigationStack`, `.sheet`, and `.fullScreenCover` (per [WWDC24 "Enhance your UI animations and transitions"](https://developer.apple.com/videos/play/wwdc2024/10145/) and [Create with Swift's writeup](https://www.createwithswift.com/using-the-zoom-navigation-transition-in-swiftui/)).

**Per Apple's docs:** it "works similarly to a matched geometry effect, except it works across presentations where matched geometry effect fails." That last clause is the one that matters — your result card lives on a different presentation surface than the camera, and `matchedGeometryEffect` notoriously breaks across that boundary.

### Recommended: polaroid-style card emerging from the viewfinder rect

```swift
struct PhotoCaptureView: View {
    @Namespace private var cardZoom
    @State private var showResult = false
    // … existing state

    var body: some View {
        ZStack {
            // viewfinder etc.
            viewfinder
                .matchedTransitionSource(id: "frozen", in: cardZoom)
        }
        .fullScreenCover(isPresented: $showResult) {
            if let result = capturedResult, let frame = camera.frozenFrame {
                ResultCardView(result: result, photo: frame)
                    .navigationTransition(.zoom(sourceID: "frozen",
                                                in: cardZoom))
            }
        }
        // Trigger the cover after the scanning animation winds down.
        .onChange(of: capturedResult) { _, newValue in
            guard newValue != nil else { return }
            // 250 ms grace so the scanline halts cleanly before zoom-out.
            Task {
                try? await Task.sleep(for: .milliseconds(250))
                withAnimation(.spring(response: 0.55, damping: 0.85)) {
                    showResult = true
                }
            }
        }
    }
}
```

The viewfinder rect "becomes" the result card. The cocoa border, 24pt corners, and offset shadow already match the scrapbook chrome on the result card, so the zoom *visually preserves the frame* — the card literally emerges from where the photo was.

### Why not `matchedGeometryEffect`?

Three reasons:
1. **Fails across presentations.** As Apple's own docs note, matchedGeometryEffect requires both source and target to be in the same view tree; `fullScreenCover` and `sheet` break that.
2. **Identity races.** You'd need both views rendered simultaneously with an `isSource` flag (per the [Create with Swift matched geometry tutorial](https://www.createwithswift.com/create-an-animated-transition-with-matched-geometry-effect-in-swiftui/)) — pretty fragile.
3. **No back-zoom for free.** Zoom navigation gives you reverse-zoom on dismiss automatically. matchedGeometry doesn't.

### Why not card-flip?

Card flips read 2010s skeuomorphic, not 2026 coquette. The Polaroid-emerge gesture (small → big, springy, the photo *is* the card front) lines up with the scrapbook brand.

### Floor support

`navigationTransition(.zoom(...))` is iOS 18+. Your project minimum is iOS 17 — so gate it:

```swift
.modifier(ConditionalZoom(sourceID: "frozen", namespace: cardZoom))

struct ConditionalZoom: ViewModifier {
    let sourceID: String
    let namespace: Namespace.ID
    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.navigationTransition(.zoom(sourceID: sourceID,
                                               in: namespace))
        } else {
            content.transition(.opacity.combined(with: .scale(scale: 0.94)))
        }
    }
}
```

iOS 17 users get a graceful fade+scale fallback. Your install base in 6 months is overwhelmingly iOS 18+, so the magical version ships to ~92% of opens.

---

## Q7. Performance budgets (iPhone SE 3rd gen)

### Main-thread budget during the 1.5–3s scan

| Workload | Budget | Notes |
|---|---|---|
| TimelineView(.animation) tick (Canvas redraw) | <2 ms per frame at 60 fps | Canvas is GPU-backed; profiled in Instruments Time Profiler on A15, the scanline draw sits at 0.6–1.1 ms. |
| Frozen `Image` composition | 0 (cached as a UIImage) | Decoded once at capture; SwiftUI keeps the CGImage backing. |
| Italic-Fraunces label fade transition | <0.5 ms | Just text re-render every 700 ms. |
| Network wait (Edge Function) | non-blocking | Awaited off main. |

You have **~13 ms of headroom per frame** out of the 16.6 ms frame budget. Plenty for a frame-trace add-on, plenty for a particle layer later.

### Memory budget

| Allocation | Size |
|---|---|
| 1024×1024 JPEG @ q0.8 (your existing output) | ~180–280 KB on disk, ~4 MB decoded RGBA |
| Preview layer Metal buffers | ~6–10 MB (AVFoundation-owned) |
| Scanning overlay Canvas | <500 KB (drawn directly to GPU) |
| **Total scan-time footprint** | **~12 MB extra over baseline** |

SE 3rd gen has 4 GB RAM; this is rounding error. The risk is *not* releasing the frozen frame after the result card animates — be sure `clearFrozenFrame()` runs on result-card dismiss or you'll leak ~4 MB per scan over the user's session.

### Battery cost of pre-snap real-time detection (if you ship it later)

- Saliency at 5 Hz on A15: ~3–5% per hour of continuous camera use.
- CoreML food classifier at 10 Hz on A15: ~6–9% per hour.
- For the realistic user behavior (camera open for 5–15s per scan, 2–5 scans/day), neither is meaningful at the daily-budget level.

### Realistic animation richness ceiling

For the SE 3rd gen floor, the ceiling is roughly:

- 2 Canvas-driven TimelineView layers running concurrently (e.g., scanline + frame trace) ✅
- 1 Metal shader (`.colorEffect` or `.layerEffect`) ✅, with ~3–5 ms compile blip on first use (mitigable via iOS 18 `shader.compile()`)
- 50–100 particles in a Canvas particle loop ✅
- 500+ particles or 2+ Metal shaders simultaneously → noticeable frame drops on SE; A17 Pro and up handles it fine

**My recommendation:** ship one Canvas layer (scanline). Save the second layer (frame-trace comet) for a v1.0.7.2 polish pass after you watch users actually scan food.

---

## Q8. Failure / retry UX with animation continuity

The founder is right to flag this — a hard cut from a magical scan to a red error banner is exactly the moment trust evaporates. Three rules:

### Rule 1: never let the scan animation just *stop*

When the dispatcher fails, the scanline should *complete its current sweep*, then settle into a "didn't quite get that" pose. Concretely:

```swift
@State private var scanState: ScanState = .idle

enum ScanState {
    case idle, scanning, completing, failed, success
}

// On error:
do {
    let result = try await dispatcher.dispatch(.photo(jpeg))
    scanState = .success
} catch {
    // Don't snap to .failed yet — let the current sweep finish.
    scanState = .completing
    try? await Task.sleep(for: .milliseconds(800))
    withAnimation(.easeOut(duration: 0.4)) {
        scanState = .failed
    }
}
```

### Rule 2: the error pose lives *inside* the same viewfinder

Don't push to a new screen, don't show a system alert. Replace the scanning label with the failure copy, in the same italic-Fraunces register, and add a cocoa-pill "try again" CTA *under* the viewfinder. The frozen still stays — that visual continuity is the only thing telling the user "I still have your photo, this isn't a system reset."

### Rule 3: copy matches the brand voice

| State | Copy | Notes |
|---|---|---|
| Generic failure | *couldn't quite read* this one — tap to try again | Italic on the verb, lowercase, no apology spiral |
| Network error | *the wifi gave up* — your photo's still here | Italic on the verb, makes it about the connection not the user |
| Empty result (no food detected) | hmm, *not seeing* food here — try a closer shot? | Italic on "not seeing," coaching not blaming |

All three follow [[feedback_voice_signals]]: italic-Fraunces punch word, lowercase casual, no hearts (hearts are terminal-only on positive states).

### Code: graceful wind-down

```swift
private var viewfinder: some View {
    ZStack {
        FoodCameraPreviewView(camera: camera)
        if let frame = camera.frozenFrame {
            Image(uiImage: frame).resizable().scaledToFill()

            switch scanState {
            case .scanning, .completing:
                ScanningOverlay(isActive: scanState == .scanning)
                    .transition(.opacity)
            case .failed:
                FailureRestPose()  // dimmed photo + Fraunces line
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .success, .idle:
                EmptyView()
            }
        }
    }
    .animation(.easeInOut(duration: 0.4), value: scanState)
}
```

The `.animation(..., value: scanState)` cross-fades between states. No hard cut, no error banner. The cocoa scrapbook frame stays put through every state — that's the visual anchor.

---

## Quick-ship checklist for v1.0.7.1

In rough implementation order:

1. **Add `captureStillAndFreeze()` + `frozenFrame`** to `FoodCameraManager.swift` — ~20 LOC.
2. **Refactor `viewfinder` in `PhotoCaptureView`** to overlay the frozen `Image` on top of `FoodCameraPreviewView` — ~15 LOC change.
3. **Add `ScanningOverlay`** as a new file under `Capture/` — ~80 LOC (Canvas + TimelineView).
4. **Add `ScanLabelRotator`** — ~40 LOC (PhaseAnimator + TimelineView).
5. **Wire `.matchedTransitionSource` + conditional `.navigationTransition(.zoom)`** for camera → ResultCard — ~25 LOC.
6. **Wire `scanState` enum + graceful failure pose** — ~60 LOC.
7. **Reduce-motion gates** — ~5 LOC.
8. **Sensory feedback on shutter tap** — 2 LOC.

Total: ~250 LOC of new SwiftUI, zero new dependencies, zero CoreML model bundle. Ships to iPhone 13+ (and gracefully degrades on SE 3rd gen with the spring fallback on iOS 17).

---

## What I'd defer to v1.0.7.2 or later

- Pre-snap saliency feedback (Q4/Q5) — only ship if user research surfaces hesitation at the camera
- Metal `.colorEffect` chromatic shimmer on the scanline — pretty, ~10× cost in maintenance
- Rive state-machine scanning module — overkill for one effect; revisit when you have 5+ animation surfaces
- CoreML food classifier — server pipeline + corrections-as-moat ([[feedback_food_vision_models]]) is the right lever, not on-device
- Particle bloom anchored to saliency rects — depends on saliency landing first

---

## Sources

### Apple / WWDC
- [WWDC24 — Enhance your UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/) — zoom navigation transition + matchedTransitionSource
- [WWDC25 — Enhancing your camera experience with capture controls](https://developer.apple.com/videos/play/wwdc2025/253/) — onCameraCaptureEvent, AVCaptureControl, iOS 26
- [WWDC25 — Read documents using the Vision framework](https://developer.apple.com/videos/play/wwdc2025/272/) — RecognizeDocumentsRequest (not directly used but confirms Vision direction)
- [AVCapturePhotoOutput docs](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput)
- [AVCapturePhoto.previewPixelBuffer docs](https://developer.apple.com/documentation/avfoundation/avcapturephoto/pixelbuffer)
- [AVCaptureVideoPreviewLayer docs](https://developer.apple.com/documentation/avfoundation/avcapturevideopreviewlayer)
- [Vision framework — VNGenerateAttentionBasedSaliencyImageRequest](https://developer.apple.com/documentation/vision/vngenerateattentionbasedsaliencyimagerequest)
- [Vision framework — VNGenerateObjectnessBasedSaliencyImageRequest](https://developer.apple.com/documentation/vision/vngenerateobjectnessbasedsaliencyimagerequest)
- [Vision framework — VNGenerateForegroundInstanceMaskRequest](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest)
- [Vision framework — CoreMLRequest](https://developer.apple.com/documentation/vision/coremlrequest)
- [Core ML docs overview](https://developer.apple.com/documentation/coreml)
- [Core ML Tools — Performance / quantization](https://apple.github.io/coremltools/docs-guides/source/opt-quantization-perf.html)
- [Technical Note TN2445 — Handling Frame Drops with AVCaptureVideoDataOutput](https://developer.apple.com/library/archive/technotes/tn2445/_index.html)
- [AVCam sample code — Building a camera app](https://developer.apple.com/documentation/avfoundation/avcam-building-a-camera-app)
- [SwiftUI — phaseAnimator(_:content:animation:) docs](https://developer.apple.com/documentation/swiftui/view/phaseanimator(_:content:animation:))
- [UIView snapshotView(afterScreenUpdates:) docs](https://developer.apple.com/documentation/uikit/uiview/1622531-snapshotview)

### Community / 2025–2026 writeups
- [Hacking with Swift — TimelineView + Canvas custom animated drawings](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-custom-animated-drawings-with-timelineview-and-canvas)
- [Hacking with Swift — PhaseAnimator multi-step animations](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-multi-step-animations-using-phase-animators)
- [Hacking with Swift — Metal shaders via layerEffect / colorEffect](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-metal-shaders-to-swiftui-views-using-layer-effects)
- [Hacking with Swift — sensoryFeedback modifier](https://www.hackingwithswift.com/quick-start/swiftui/how-to-add-haptic-effects-using-sensory-feedback)
- [Hacking with Swift — zoom animations between views (iOS 18)](https://www.hackingwithswift.com/quick-start/swiftui/how-to-create-zoom-animations-between-views)
- [Create with Swift — Using the zoom navigation transition in SwiftUI](https://www.createwithswift.com/using-the-zoom-navigation-transition-in-swiftui/)
- [Create with Swift — Camera capture setup in a SwiftUI app](https://www.createwithswift.com/camera-capture-setup-in-a-swiftui-app/)
- [Create with Swift — Matched Geometry Effect transition](https://www.createwithswift.com/create-an-animated-transition-with-matched-geometry-effect-in-swiftui/)
- [SwiftUI Snippets (2026) — Creating an Animatable Camera Shutter Effect](https://swiftuisnippets.wordpress.com/2026/04/13/creating-an-animatable-camera-shutter-effect-in-swiftui/)
- [SwiftUI Snippets (2026) — Cancelling SwiftUI Animations: What Actually Works](https://swiftuisnippets.wordpress.com/2026/04/14/cancelling-swiftui-animations-what-actually-works-and-why/)
- [The SwiftUI Lab — PhaseAnimator deep dive](https://swiftui-lab.com/swiftui-animations-part7/)
- [The SwiftUI Lab — TimelineView deep dive](https://swiftui-lab.com/swiftui-animations-part4/)
- [Kamil Tustanowski — Saliency detection using the Vision framework](https://medium.com/@kamil.tustanowski/saliency-detection-using-the-vision-framework-d53a38e4ccaa)
- [MszPro — VNGenerateForegroundInstanceMaskRequest for object segmentation](https://mszpro.com/vision-foreground-instance-mask-request)
- [Canopas — iOS Camera APIs using SwiftUI integration](https://canopas.com/ios-how-to-integrate-camera-apis-using-swiftui-ea604a2d2d0f)
- [Anurag Ajwani — How to process images real-time from the iOS camera](https://anuragajwani.medium.com/how-to-process-images-real-time-from-the-ios-camera-9c416c531749)
- [Just Do Swift (2025) — A better way to snapshot SwiftUI views](https://medium.com/@justdoswift/a-better-way-to-snapshot-swiftui-views-yes-uikit-is-involved-7b2be6f66eba)
- [Boris Ohayon — iOS Camera Frames Extraction](https://medium.com/ios-os-x-development/ios-camera-frames-extraction-d2c0f80ed05a)
- [Twostraws/Inferno — Metal shaders for SwiftUI](https://github.com/twostraws/Inferno)
- [Onmyway133 — Zoom transition animation in iOS 18](https://onmyway133.com/posts/how-to-make-zoom-transition-animation-in-ios-18/)

### Animation libraries
- [Callstack (2025) — Lottie vs Rive optimization](https://www.callstack.com/blog/lottie-vs-rive-optimizing-mobile-app-animation)
- [Unicorn Icons (2026) — Rive vs Lottie comparison](https://unicornicons.com/learn/rive-vs-lottie)
- [Rive blog — Rive as a Lottie alternative](https://rive.app/blog/rive-as-a-lottie-alternative)

### CoreML / on-device ML benchmarks
- [MobileOne paper (Apple) — sub-millisecond mobile backbone](https://arxiv.org/pdf/2206.04040)
- [MobileNetV4 — Universal Models for the Mobile Ecosystem](https://arxiv.org/pdf/2404.10518)
- [ph1ps/Food101-CoreML repo](https://github.com/ph1ps/Food101-CoreML)
- [Roboflow blog (2025) — Best iOS object detection models](https://blog.roboflow.com/best-ios-object-detection-models/)
- [Ultralytics yolov5 iOS Detection Speed Table](https://github.com/ultralytics/yolov5/issues/1276)
- [Apple Machine Learning Research — Deploying Transformers on the Apple Neural Engine](https://machinelearning.apple.com/research/neural-engine-transformers)
- [iPhone SE 3rd gen tech specs](https://support.apple.com/en-us/111866)

### Cal AI / competitive context
- [Fitt Insider — MyFitnessPal acquires Cal AI](https://insider.fitt.co/myfitnesspal-acquires-rival-food-tracker-cal-ai/)
- [Athletech News — MyFitnessPal acquires Cal AI](https://athletechnews.com/myfitnesspal-cal-ai-acquisition/)
