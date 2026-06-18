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
    /// Today's program-day archetype string ("protein" / "balanced" /
    /// "movement" / "rest"). Passed through to QuickAddView so the chip
    /// composer can surface archetype-themed picks first. Nil / empty
    /// disables the archetype chip section. Phase 2 of the program-
    /// quality archetype build (2026-06-17).
    public let archetypeHint: String?
    public let onDismiss: () -> Void
    /// v1.0.21 (2026-06-18) — host hook for the post-snap Lottie wow
    /// moment. Fired the moment a scan result lands (before the user
    /// taps "log it"). PlankApp's FoodResultExplosion (heart + star
    /// Lottie) listens here. Lottie is a main-app dependency, not a
    /// PlankFood one, so the hook is just a closure — PlankApp owns
    /// the actual animation view.
    public var onResultLanded: () -> Void = {}

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
        archetypeHint: String? = nil,
        onDismiss: @escaping () -> Void,
        onResultLanded: @escaping () -> Void = {}
    ) {
        self.userId = userId
        self.cuisineProfile = cuisineProfile
        self.archetypeHint = archetypeHint
        self.onResultLanded = onResultLanded
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
                        // v1.0.8 Phase P (2026-06-08) — photo path
                        // reviews INLINE in PhotoCaptureView. onCaptured
                        // now fires only when the user has explicitly
                        // tapped "log it" on the inline result card,
                        // so we persist + dismiss directly here. No
                        // .result phase transition for the photo path
                        // (quickAdd + imOut still use .result since
                        // they have no photo to overlay a card on).
                        capturedFood = food
                        capturedPhoto = photo
                        logTapped(food)
                    },
                    onQuickAddTapped: { phase = .quickAdd },
                    onImOutTapped: { phase = .imOut },
                    onResultLanded: onResultLanded
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
                    onDismiss: { phase = .camera },
                    userId: userId,
                    cuisineCSV: cuisineProfile,
                    archetypeHint: archetypeHint
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
                    } else if !food.items.isEmpty {
                        // v1.0.10 (2026-06-17) — quick-log + im-out
                        // paths arrive here without a photo. Without
                        // a hero the result screen reads as a bare
                        // cream surface, which loses the share moment
                        // photo-scan logs get for free. The typography
                        // polaroid mirrors PolaroidHero's chrome
                        // (matte + cocoa stroke + offset shadow +
                        // sticker scatter) so the result feels like
                        // the same scrapbook page — except the dish
                        // name is the visual anchor instead of a
                        // photo. `--handwritten-share` swaps the
                        // editorial JeniHeroSerif variant for the
                        // Pinterest handwritten one so the founder
                        // can A/B both registers on the same screen.
                        let useHandwritten = ProcessInfo.processInfo.arguments
                            .contains("--handwritten-share")
                        if useHandwritten {
                            HandwrittenPolaroidHero(
                                mealLabel: Self.mealLabelForNow(),
                                dishName: Self.dishNameDisplay(food: food),
                                kcalDisplay: Self.kcalDisplay(food: food)
                            )
                        } else {
                            TypographyPolaroidHero(
                                mealLabel: Self.mealLabelForNow(),
                                dishName: Self.dishNameDisplay(food: food),
                                kcalDisplay: Self.kcalDisplay(food: food)
                            )
                        }
                    }

                    ResultCard(
                        food: food,
                        // v1.0.8 Phase E — the (potentially corrected)
                        // food comes back from the card so any
                        // "more sauce" / "bigger" pill taps in
                        // SingleDishCard end up persisted to the food
                        // log, not just shown on screen.
                        primaryAction: { logTapped($0) },
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

    // MARK: - No-photo hero helpers (quick-log + im-out paths)

    /// Time-of-day → editorial meal-label (lowercase, voice-locked).
    /// Falls through to "snack" for late-night logging — a deliberate
    /// soft choice; no "midnight" label, no shame.
    static func mealLabelForNow() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11:  return "breakfast"
        case 11..<15: return "lunch"
        case 15..<18: return "snack"
        case 18..<22: return "dinner"
        default:      return "snack"
        }
    }

    /// Composes a one-line dish label from up to two items, tailing
    /// "+N" when more were identified. Matches MealSummaryCard's
    /// formatting so the result hero and slide-1 share card agree on
    /// what the meal is called.
    static func dishNameDisplay(food: CapturedFood) -> String {
        if food.items.isEmpty { return "your plate" }
        if food.items.count == 1 { return food.items[0].name }
        if food.items.count == 2 {
            return "\(food.items[0].name) + \(food.items[1].name)"
        }
        return food.items.prefix(2).map(\.name).joined(separator: " + ")
            + " +\(food.items.count - 2)"
    }

    /// Single-line kcal display — honest range first (restaurant
    /// estimate paths return a band), single value second, em-dash
    /// fallback for the rare empty-but-non-zero result.
    static func kcalDisplay(food: CapturedFood) -> String {
        if let low = food.kcalLow, let high = food.kcalHigh, low != high {
            return "\(Int(low.rounded()))\u{2013}\(Int(high.rounded())) cal"
        }
        if let total = food.totalKcal {
            return "\(Int(total.rounded())) cal"
        }
        if let low = food.kcalLow {
            return "\(Int(low.rounded())) cal"
        }
        return "\u{2014}"
    }

    // MARK: - Persistence

    private func logTapped(_ food: CapturedFood) {
        do {
            try FoodLogPersister.persist(
                food,
                userId: userId,
                photo: capturedPhoto,
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

// MARK: - TypographyPolaroidHero
//
// v1.0.10 (2026-06-17) — no-photo hero for the quick-log + im-out
// result paths. Visual parity with PolaroidHero (same matte, cocoa
// stroke, hard offset shadow, sticker scatter) so the result screen
// reads as the same scrapbook page regardless of whether a photo
// exists. The "develops" animation is replaced by a soft fade +
// blur ease-in on the typography — the dish name lands focused as
// the eye settles.
//
// Animation timeline:
//   t = 0.00s — content sits at opacity 0.6, blur 3pt, slight scale
//   t = 0.90s — typography fully readable (opacity 1, blur 0)
//   t = 0.60s — sticker scatter springs in (parallels PolaroidHero)
//
// Reduce-motion: snaps to final, stickers still appear (decorative,
// not motion).

private struct TypographyPolaroidHero: View {
    let mealLabel: String
    let dishName: String
    let kcalDisplay: String

    @State private var revealed: Double = 0
    @State private var stickersIn: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            polaroidFrame
                .opacity(0.5 + revealed * 0.5)
                .blur(radius: (1.0 - revealed) * 3.0)
                .rotationEffect(.degrees(-1.2))

            if stickersIn {
                stickerOverlay
            }
        }
        .onAppear {
            if reduceMotion {
                revealed = 1.0
                stickersIn = true
                return
            }
            withAnimation(.easeOut(duration: 0.95)) {
                revealed = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    stickersIn = true
                }
            }
        }
    }

    @ViewBuilder
    private var polaroidFrame: some View {
        VStack(spacing: 8) {
            // Typography "photo" — a soft rose→cream gradient stands
            // in for the missing photo, with the dish name as the
            // visual hero. The eyebrow + divider + kcal create the
            // same vertical rhythm a real polaroid would have.
            ZStack {
                LinearGradient(
                    colors: [
                        FoodTheme.accentSubtle.opacity(0.55),
                        FoodTheme.bgPrimary,
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 12) {
                    Text(mealLabel)
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                        .foregroundStyle(FoodTheme.accent)
                        .kerning(0.4)

                    Text(dishName)
                        .font(.custom("JeniHeroSerif-Italic", size: 34))
                        .foregroundStyle(FoodTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .minimumScaleFactor(0.7)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle()
                        .fill(FoodTheme.accent.opacity(0.32))
                        .frame(width: 32, height: 1)

                    Text(kcalDisplay)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(FoodTheme.stateGood)
                        .monospacedDigit()
                }
                .padding(.vertical, 24)
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)

            // Matte caption — mirrors PolaroidHero's "just now"
            // exactly so the two heroes feel like siblings.
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

    /// Same four stickers, same positions, same rotations as
    /// PolaroidHero — intentional parity so a user scanning a photo
    /// vs. quick-logging text sees the same scrapbook page.
    private var stickerOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Image("sticker_cherries", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-14))
                    .shadow(color: Color.black.opacity(0.1), radius: 0, x: 1, y: 1)
                    .position(x: geo.size.width - 18, y: 12)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                Image("sticker_bow_satin", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(10))
                    .opacity(0.92)
                    .position(x: 20, y: 14)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                Image("sticker_gummy_bear", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(15))
                    .position(x: geo.size.width - 20, y: geo.size.height - 18)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

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

// MARK: - HandwrittenPolaroidHero
//
// v1.0.10 (2026-06-17) — Pinterest it-girl variant of the quick-log
// + im-out result hero. Same polaroid chrome as PolaroidHero and
// TypographyPolaroidHero (1.5pt cocoa stroke, hard offset shadow,
// 4 corner stickers at identical coordinates) so a user toggling
// between the photo path, the editorial text path, and the
// handwritten text path sees the same scrapbook-page frame.
//
// Typography stack INSIDE the polaroid swaps to the handwriting
// family already shared by HandwrittenDailyShareCard / WeeklyShareCard
// / LessonQuoteCard:
//
//   - meal label  → Bradley Hand 22pt rose eyebrow
//   - dish name   → Snell Roundhand-Bold 52pt cursive hero
//   - divider     → WavyLine bezier (hand-drawn underline accent)
//   - kcal        → Bradley Hand-Bold 22pt rose tint + heart suffix
//   - matte       → Bradley Hand "just now ♥" caption
//
// Same develop-in animation arc as TypographyPolaroidHero so the
// motion vocabulary stays consistent — the founder swaps registers
// via flag without learning a new transition feel.

@MainActor
public struct HandwrittenPolaroidHero: View {

    public let mealLabel: String
    public let dishName: String
    public let kcalDisplay: String

    @State private var revealed: Double = 0
    @State private var stickersIn: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(mealLabel: String, dishName: String, kcalDisplay: String) {
        self.mealLabel = mealLabel
        self.dishName = dishName
        self.kcalDisplay = kcalDisplay
    }

    public var body: some View {
        ZStack {
            polaroidFrame
                .opacity(0.5 + revealed * 0.5)
                .blur(radius: (1.0 - revealed) * 3.0)
                .rotationEffect(.degrees(-1.2))

            if stickersIn {
                stickerOverlay
            }
        }
        .onAppear {
            if reduceMotion {
                revealed = 1.0
                stickersIn = true
                return
            }
            withAnimation(.easeOut(duration: 0.95)) {
                revealed = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                    stickersIn = true
                }
            }
        }
    }

    @ViewBuilder
    private var polaroidFrame: some View {
        VStack(spacing: 8) {
            // Butter→cream gradient inside the polaroid — matches the
            // handwritten share-card background palette so the user
            // who scans a photo and gets the typographic Polaroid
            // earlier and then types a meal and lands on this hero
            // reads them as siblings.
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.985, green: 0.945, blue: 0.880),
                        Color(red: 0.972, green: 0.917, blue: 0.864),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(spacing: 12) {
                    Text(mealLabel)
                        .font(.custom("BradleyHandITCTT-Bold", size: 22))
                        .foregroundStyle(Color(red: 0.78, green: 0.32, blue: 0.40))
                        .kerning(0.4)

                    Text(dishName)
                        .font(.custom("SnellRoundhand-Bold", size: 52))
                        .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.30))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .padding(.horizontal, 24)
                        .fixedSize(horizontal: false, vertical: true)

                    HandwrittenWavyLine()
                        .stroke(
                            Color(red: 0.92, green: 0.52, blue: 0.62).opacity(0.65),
                            style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
                        )
                        .frame(width: 60, height: 10)

                    HStack(spacing: 6) {
                        Text(kcalDisplay)
                            .font(.custom("BradleyHandITCTT-Bold", size: 22))
                            .foregroundStyle(Color(red: 0.45, green: 0.22, blue: 0.30))
                        Image(systemName: "heart.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70))
                    }
                }
                .padding(.vertical, 24)
            }
            .frame(height: 220)
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                Text("just ")
                    .font(.custom("BradleyHandITCTT-Bold", size: 12))
                    .foregroundStyle(Color(red: 0.78, green: 0.32, blue: 0.40))
                Text("now ")
                    .font(.custom("BradleyHandITCTT-Bold", size: 12))
                    .foregroundStyle(Color(red: 0.50, green: 0.30, blue: 0.30))
                Text("\u{2665}")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.95, green: 0.62, blue: 0.70))
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

    private var stickerOverlay: some View {
        GeometryReader { geo in
            ZStack {
                Image("sticker_cherries", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .rotationEffect(.degrees(-14))
                    .shadow(color: Color.black.opacity(0.1), radius: 0, x: 1, y: 1)
                    .position(x: geo.size.width - 18, y: 12)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                Image("sticker_bow_satin", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(10))
                    .opacity(0.92)
                    .position(x: 20, y: 14)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

                Image("sticker_gummy_bear", bundle: .main)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .rotationEffect(.degrees(15))
                    .position(x: geo.size.width - 20, y: geo.size.height - 18)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))

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

// MARK: - HandwrittenWavyLine
//
// Mirrors WavyLine in HandwrittenLessonQuoteCard but kept private to
// PlankFood so the package has no cross-target shape coupling. Single
// cubic-bezier with two humps; small accent under the dish name.

private struct HandwrittenWavyLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let mid = rect.midY
        path.move(to: CGPoint(x: rect.minX, y: mid))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: mid),
            control1: CGPoint(x: rect.minX + rect.width * 0.25, y: mid - 4),
            control2: CGPoint(x: rect.minX + rect.width * 0.25, y: mid + 4)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: mid),
            control1: CGPoint(x: rect.midX + rect.width * 0.25, y: mid - 4),
            control2: CGPoint(x: rect.midX + rect.width * 0.25, y: mid + 4)
        )
        return path
    }
}

#endif  // canImport(UIKit)
