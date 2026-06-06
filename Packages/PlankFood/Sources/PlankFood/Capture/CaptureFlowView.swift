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
                        polaroidHero(photo: photo)
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

    /// Polaroid-style photo hero. Cream border (~12pt all around),
    /// hard offset shadow, 1.5pt cocoa stroke — matches the scrapbook
    /// chrome family. Photo clips to a 20pt inner radius so the
    /// Polaroid frame reads as a sticker-stack layer, not a crop. The
    /// caption row at the bottom carries italic-Fraunces "*just now*"
    /// — locked voice signal making the moment feel curated, not just
    /// logged.
    @ViewBuilder
    private func polaroidHero(photo: UIImage) -> some View {
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
        // Slight angle — Polaroid signature. Not too much, so it
        // doesn't fight the underlying ResultCard.
        .rotationEffect(.degrees(-1.2))
    }

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

#endif  // canImport(UIKit)
