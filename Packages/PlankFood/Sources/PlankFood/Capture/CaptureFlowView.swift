#if canImport(UIKit)
import SwiftUI
import SwiftData

// MARK: - CaptureFlowView
//
// End-to-end capture orchestrator. Wraps the three capture entry
// modes (camera / quick-add / i'm out) → ResultCard → log persistence
// into a single fullScreenCover-presentable flow.
//
// Phases:
//   1. .camera     — PhotoCaptureView (shutter)
//   2. .quickAdd   — QuickAddView (6-tile beverage rail, D20)
//   3. .imOut      — ImOutTonightView (cuisine chips, D14)
//   4. .result     — ResultCard (review + edit + log) — common to all 3
//
// On "log it" tap from ResultCard, persists the (possibly edited)
// CapturedFood via FoodLogPersister into the ModelContext, then
// dismisses the flow — Home's @Query updates the food card
// automatically.

public struct CaptureFlowView: View {

    public let userId: String
    public let cuisineProfile: String?
    public let onDismiss: () -> Void

    @Environment(\.modelContext) private var modelContext

    @State private var phase: Phase
    @State private var capturedFood: CapturedFood?
    @State private var capturedPhoto: UIImage?
    @State private var editingItem: CapturedItem?
    /// v1.0.7 — transient "sparkle" flash that fires when the scan
    /// completes and we cross from camera → result. Soft rose halo
    /// that pulses for ~0.55s. Brief enough to feel magical, short
    /// enough to never block.
    @State private var transitionBloom: Bool = false
    /// Shared namespace so the frozen photo can `matchedGeometryEffect`
    /// from the viewfinder bounds to the result-card Polaroid hero.
    @Namespace private var photoTransition

    public init(
        userId: String,
        cuisineProfile: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.userId = userId
        self.cuisineProfile = cuisineProfile
        self.onDismiss = onDismiss
        // Apple 5.1.2(i) gate — first scan must surface the disclosure
        // before any photo is taken. After consent, the FoodOnboarding
        // sheet collects dietary + cuisine retro + exclusions ONCE.
        // Subsequent scans skip directly to the camera. AppStorage
        // backs both snapshots.
        let initial: Phase
        if !FoodAIConsent.hasAccepted() {
            initial = .consent
        } else if !FoodOnboardingFlag.hasCompleted() {
            initial = .firstScanOnboarding
        } else {
            initial = .camera
        }
        _phase = State(initialValue: initial)
    }

    public var body: some View {
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            switch phase {
            case .consent:
                FoodAIConsentSheet(
                    onAccept: {
                        FoodAnalytics.track(.aiConsentAccepted)
                        FoodAIConsent.markAccepted()
                        // After consent lands, FoodOnboardingSheet
                        // collects dietary + cuisine retro + exclusions
                        // (first-time only). Skip straight to camera
                        // if the sheet already completed.
                        phase = FoodOnboardingFlag.hasCompleted()
                            ? .camera
                            : .firstScanOnboarding
                    },
                    onDecline: {
                        FoodAnalytics.track(.aiConsentDeclined)
                        onDismiss()
                    }
                )

            case .firstScanOnboarding:
                FoodOnboardingSheet(onContinue: {
                    FoodOnboardingFlag.markCompleted()
                    phase = .camera
                })

            case .camera:
                PhotoCaptureView(
                    onDismiss: onDismiss,
                    onCaptured: { food, photo in
                        // v1.0.7 — smooth magical camera→result
                        // transition. Hold the photo, kick off the
                        // sparkle bloom, then animate the phase
                        // change. The Polaroid hero on resultPhase
                        // uses matchedGeometryEffect from the same
                        // photoTransition namespace so the still
                        // morphs from the viewfinder bounds into the
                        // result-card hero block instead of hard cut.
                        capturedFood = food
                        capturedPhoto = photo
                        withAnimation(.easeOut(duration: 0.35)) {
                            transitionBloom = true
                        }
                        withAnimation(.spring(response: 0.55, dampingFraction: 0.82)) {
                            phase = .result
                        }
                        // Fade the bloom back out after the transition
                        // settles. Independent timing from the spring
                        // so the bloom outlasts the phase change by a
                        // beat — "the photo arrived" cue.
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 600_000_000)
                            withAnimation(.easeIn(duration: 0.45)) {
                                transitionBloom = false
                            }
                        }
                    },
                    onQuickAddTapped: { phase = .quickAdd },
                    onImOutTapped: { phase = .imOut }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

            case .quickAdd:
                QuickAddView(
                    onLogged: { food in
                        FoodAnalytics.track(.quickAddLogged, properties: [
                            "items_count": food.items.count,
                        ])
                        capturedFood = food
                        phase = .result
                    },
                    onScanInstead: { phase = .camera },
                    onDismiss: { phase = .camera }
                )
                .onAppear { FoodAnalytics.track(.quickAddTapped) }

            case .imOut:
                ImOutTonightView(
                    onLogged: { food in
                        FoodAnalytics.track(.imOutLogged, properties: [
                            "kcal_low":  food.kcalLow ?? 0,
                            "kcal_high": food.kcalHigh ?? 0,
                        ])
                        capturedFood = food
                        phase = .result
                    },
                    onDismiss: { phase = .camera }
                )
                .onAppear { FoodAnalytics.track(.imOutUsed) }

            case .result:
                if let food = capturedFood {
                    resultPhase(food: food)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    // Should be unreachable; defensive fallback.
                    ProgressView()
                }
            }

            // v1.0.7 transition bloom — soft rose halo that flashes at
            // the moment of scan→result handoff. Sits ABOVE every phase
            // so both the fading camera and the arriving result see the
            // same washing warmth. Subliminal — under 0.25 opacity peak,
            // 0.55s total.
            if transitionBloom {
                RadialGradient(
                    gradient: Gradient(stops: [
                        .init(color: Color(red: 0.77, green: 0.40, blue: 0.48).opacity(0.22),
                              location: 0.0),
                        .init(color: .clear, location: 1.0),
                    ]),
                    center: .center,
                    startRadius: 20,
                    endRadius: 320
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .sheet(item: $editingItem) { item in
            FoodCorrectionSheet(
                original: item,
                onSave: { edited in
                    FoodAnalytics.track(.scanCorrectionSaved, properties: [
                        "field_changed": edited.name != item.name ? "name" : "portion",
                    ])
                    capturedFood = capturedFood?.replacing(item: edited)
                    editingItem = nil
                },
                onCancel: { editingItem = nil }
            )
            .onAppear {
                FoodAnalytics.track(.scanCorrectionOpened)
            }
        }
    }

    // MARK: - Result phase

    @ViewBuilder
    private func resultPhase(food: CapturedFood) -> some View {
        VStack(spacing: 0) {
            // Header with cancel.
            HStack {
                Button {
                    // Back to camera to retake.
                    capturedFood = nil
                    phase = .camera
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("retake")

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("close")
            }
            .padding(.horizontal, FoodTheme.Space.md)

            ScrollView {
                VStack(spacing: FoodTheme.Space.md) {
                    // v1.0.7 Polaroid hero — the captured photo lands
                    // here from the camera transition. Cream border +
                    // hard offset shadow + 1.5pt cocoa stroke matches
                    // the scrapbook chrome family. The matchedGeometry
                    // namespace shares with the viewfinder so SwiftUI
                    // morphs the photo from its full-screen position
                    // into this hero block instead of hard-cutting.
                    if let photo = capturedPhoto {
                        PolaroidHero(photo: photo)
                    }

                    ResultCard(
                        food: food,
                        primaryAction: { logTapped(food) },
                        // "actually skip" on a populated card OR "retake →"
                        // on an empty-items defensive fallback — both bounce
                        // back to camera so the user can correct course.
                        secondaryAction: {
                            capturedFood = nil
                            capturedPhoto = nil
                            phase = .camera
                        },
                        onItemTap: { item in editingItem = item }
                    )
                }
                .padding(FoodTheme.Space.screenPadding)
            }
        }
    }

    // PolaroidHero is now its own View struct (further down in this
    // file) so it can manage internal animation state — the photo
    // "develops" over 1.2s (saturation / blur / opacity ease in) and
    // sticker scatter fades in around it after the develop completes.

    // MARK: - Persistence

    private func logTapped(_ food: CapturedFood) {
        do {
            try FoodLogPersister.persist(
                food,
                userId: userId,
                into: modelContext
            )
            FoodAnalytics.track(.logSaved, properties: [
                "items_count": food.items.count,
                "source": food.source.rawValue,
            ])
            FoodAnalytics.firstLogSavedIfNeeded()
            onDismiss()
        } catch {
            // Persistence error — surface as a transient banner in
            // a follow-up polish ticket. For W4-T1, log + dismiss
            // (the user already saw the result; they can re-log).
            #if DEBUG
            print("[CaptureFlowView] persist failed: \(error)")
            #endif
            onDismiss()
        }
    }
}

// MARK: - Phase

private enum Phase {
    case consent
    case firstScanOnboarding
    case camera
    case quickAdd
    case imOut
    case result
}

// MARK: - CapturedFood replace helper

private extension CapturedFood {
    /// Return a copy with `item` replaced by `replacement` (matched
    /// by id). Used by the correction sheet save path.
    func replacing(item replacement: CapturedItem) -> CapturedFood {
        let newItems = items.map { $0.id == replacement.id ? replacement : $0 }
        return CapturedFood(
            items: newItems,
            plateType: plateType,
            source: source,
            confidence: confidence,
            needsSecondPhoto: needsSecondPhoto,
            secondPhotoHint: secondPhotoHint,
            kcalLow: kcalLow,
            kcalHigh: kcalHigh
        )
    }
}

// MARK: - PolaroidHero
//
// v1.0.8 Phase D (2026-06-07) — the captured photo lands as a
// polaroid that "develops" over ~1.2s (saturation / opacity / blur
// ease in) while a sticker scatter floats in around it. Brand-
// perfect cohort-fit: the same gesture as printing a polaroid +
// pasting it into a scrapbook with washi tape stickers.
//
// Why this beats Cal AI's reveal: Cal AI shows a clinical result
// number under a static thumbnail — the photo is just data. JeniFit
// frames the same data as a curated memory. Per UX-2 research:
// "the cohort's #1 organic acquisition channel is Pinterest +
// TikTok screenshots — we are designing the screenshot."
//
// Animation timeline (per UX-2 recommendation):
//   t = 0.00s — photo lands in polaroid frame (matchedGeometryEffect
//               from the viewfinder, handled by parent). At this
//               moment, saturation=0.4, opacity=0.4, blur=4pt.
//   t = 0.60s — saturation reaches 1.0, blur clears (the "developing"
//               effect — like a real polaroid coming out clear).
//   t = 0.90s — sticker scatter (cherries, bowSatin, gummyBear,
//               flower3D) springs in around the polaroid edges.
//   t = 1.20s — develop animation fully settled.

private struct PolaroidHero: View {
    let photo: UIImage

    /// Drives the develop-in: 0 = fresh polaroid (dim/desaturated/blurred),
    /// 1 = fully developed. Animates from 0 → 1 on appear.
    @State private var developed: Double = 0
    /// Sticker scatter visibility. Fires after develop is mostly done
    /// so the stickers feel like they were placed AFTER the photo
    /// "appeared" — the order matches how a physical scrapbook moment
    /// would unfold.
    @State private var stickersIn: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // The polaroid frame itself.
            polaroidFrame
                .saturation(0.4 + developed * 0.6)
                .opacity(0.4 + developed * 0.6)
                .blur(radius: (1.0 - developed) * 4.0)
                .rotationEffect(.degrees(-1.2))

            // Sticker scatter overlay — positioned at the corners of
            // the polaroid using offsets relative to the photo's
            // approximate visual bounds (220pt photo + 12pt padding
            // ≈ 244pt tall, frame width determined by parent).
            if stickersIn {
                stickerOverlay
            }
        }
        .onAppear {
            // Reduce-motion: snap to final state, skip the develop
            // beat. Stickers still appear (decorative, not motion).
            if reduceMotion {
                developed = 1.0
                stickersIn = true
                return
            }
            withAnimation(.easeOut(duration: 1.2)) {
                developed = 1.0
            }
            // Spring the stickers in after the develop settles —
            // 0.9s delay matches the moment the photo reads as
            // "fully there," so the stickers feel intentional, not
            // pre-loaded.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    stickersIn = true
                }
            }
        }
    }

    @ViewBuilder
    private var polaroidFrame: some View {
        VStack(spacing: 8) {
            Image(uiImage: photo)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 220)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            HStack {
                Text("just")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                    .foregroundStyle(FoodTheme.accent)
                Text("now")
                    .font(.custom("Fraunces72pt-Regular", size: 12))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer()
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .background(FoodTheme.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(FoodTheme.textPrimary, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: FoodTheme.textPrimary.opacity(0.22), radius: 0, x: 4, y: 4)
    }

    /// Four stickers placed at the polaroid corners, overhanging the
    /// frame edge so they read as "stuck on" rather than "drawn on."
    /// Each gets a small rotation per the y2k coquette spec — never
    /// perfectly aligned, never identical.
    private var stickerOverlay: some View {
        GeometryReader { geo in
            ZStack {
                // Top-right cherries — the food-rail signature sticker
                Image("sticker_cherries", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-14))
                    .shadow(color: Color.black.opacity(0.1), radius: 0, x: 1, y: 1)
                    .position(x: geo.size.width - 18, y: 12)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                // Top-left bow — washi-tape energy
                Image("sticker_bow_satin", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(10))
                    .opacity(0.92)
                    .position(x: 20, y: 14)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                // Bottom-right gummy bear — playful corner anchor
                Image("sticker_gummy_bear", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(15))
                    .position(x: geo.size.width - 20, y: geo.size.height - 18)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                // Bottom-left flower3D — softens the lower corner
                Image("sticker_flower_3d", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(-8))
                    .position(x: 18, y: geo.size.height - 20)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#endif  // canImport(UIKit)
