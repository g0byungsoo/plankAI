#if canImport(UIKit)
import SwiftUI

// MARK: - CaptureFlowView
//
// End-to-end capture orchestrator. Wraps the capture entry modes
// (camera / describe) → result → log persistence into a single
// fullScreenCover-presentable flow.
//
// Phases:
//   1. .camera     — PhotoCaptureView (THE WINDOW, v23)
//   2. .quickAdd   — QuickAddView ("or write it")
//   3. .result     — the no-photo result (describe path)
//
// On "log it" tap from ResultCard, persists the (possibly edited)
// CapturedFood via FoodLogPersister, then dismisses the flow —
// FoodLogPersister.changeNotifier updates every listening surface.

public struct CaptureFlowView: View {

    public let userId: String
    public let cuisineProfile: String?
    /// Today's program-day archetype string ("protein" / "balanced" /
    /// "movement" / "rest"). Passed through to QuickAddView so the chip
    /// composer can surface archetype-themed picks first. Nil / empty
    /// disables the archetype chip section. Phase 2 of the program-
    /// quality archetype build (2026-06-17).
    public let archetypeHint: String?
    /// v25 E3 — jeni can hand the flow the words a user just said
    /// ("i had a chicken burrito"). Present = the flow opens on the
    /// DESCRIBE path with those words in the field, skipping the
    /// camera. The estimate still runs and the user still confirms;
    /// jeni never authors a plate.
    public let describePrefill: String?
    public let onDismiss: () -> Void
    /// v1.0.21 (2026-06-18) — host hook for the post-snap Lottie wow
    /// moment. Fired the moment a scan result lands (before the user
    /// taps "log it"). Hosts may hook the landing moment (the Lottie
    /// Lottie) listens here. Lottie is a main-app dependency, not a
    /// PlankFood one, so the hook is just a closure — PlankApp owns
    /// the actual animation view.
    public var onResultLanded: () -> Void = {}

    @State private var phase: Phase
    @State private var capturedFood: CapturedFood?
    @State private var capturedPhoto: UIImage?
    /// v23 — the describe-path reading refines through its own
    /// dispatcher (the camera owns a separate one).
    @State private var refineDispatcher = FoodCaptureDispatcher()

    public init(
        userId: String,
        cuisineProfile: String? = nil,
        archetypeHint: String? = nil,
        describePrefill: String? = nil,
        onDismiss: @escaping () -> Void,
        onResultLanded: @escaping () -> Void = {}
    ) {
        self.userId = userId
        self.cuisineProfile = cuisineProfile
        self.archetypeHint = archetypeHint
        self.describePrefill = describePrefill
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
        } else if let prefill = describePrefill,
                  !prefill.trimmingCharacters(in: .whitespaces).isEmpty {
            initial = .quickAdd
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
                    userId: userId,
                    cuisineProfile: cuisineProfile,
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
                    onDismiss: {
                        // Arriving here from jeni means the camera was
                        // never the destination; backing out should
                        // close, not open a lens.
                        if describePrefill != nil { onDismiss() }
                        else { phase = .camera }
                    },
                    userId: userId,
                    cuisineCSV: cuisineProfile,
                    archetypeHint: archetypeHint,
                    prefillText: describePrefill
                )
                .onAppear { FoodAnalytics.track(.quickAddTapped) }

            case .result:
                if let food = capturedFood {
                    resultPhase(food: food)
                        .transition(.opacity.combined(with: .scale(scale: 1.04)))
                } else {
                    // Should be unreachable; defensive fallback.
                    ProgressView()
                }
            }

        }
        // v25 E2 sweep — the FoodCorrectionSheet mount died here: its
        // `editingItem` had no writer since the v23 Result/ subtree
        // retired (the sheet was unreachable and read as a shipped
        // feature). The reading page's item editor + fix-with-words
        // are the correction surface.
    }

    // MARK: - Result phase (v23 §5 S3 — one reading, every source)

    @ViewBuilder
    private func resultPhase(food: CapturedFood) -> some View {
        // The described meal has no photograph, so the hero band is
        // quiet paper; the SAME reading rises with the same order and
        // the same verb. One grammar — the Result/ card subtree died
        // with the era.
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            SnapResultView(
                userId: userId,
                food: food,
                mealLabel: Self.mealLabelForNow(),
                dishName: Self.dishNameDisplay(food: food),
                page: .constant(0),
                allowsShare: false,
                onLog: { edited in logTapped(edited) },
                onRetake: {
                    capturedFood = nil
                    phase = .quickAdd
                },
                onEdited: { edited in capturedFood = edited },
                refine: { request in
                    try await SnapRefine.run(request, dispatcher: refineDispatcher, cuisineProfile: cuisineProfile)
                }
            )

            // The one floating door out, on the paper band.
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(FoodTheme.textSecondary)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(FoodTheme.bgElevated))
                    }
                    .accessibilityLabel("close")
                }
                .padding(.horizontal, FoodTheme.Space.md)
                Spacer()
            }
        }
    }

    // MARK: - No-photo hero helpers (the describe path)

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

    // MARK: - Persistence

    private func logTapped(_ food: CapturedFood) {
        do {
            try FoodLogPersister.persist(
                food,
                userId: userId,
                photo: capturedPhoto
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
    case result
}

#endif  // canImport(UIKit)
