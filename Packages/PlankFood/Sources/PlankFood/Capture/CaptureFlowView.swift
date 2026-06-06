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
    @State private var editingItem: CapturedItem?

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
                    onCaptured: { food in
                        capturedFood = food
                        phase = .result
                    },
                    onQuickAddTapped: { phase = .quickAdd },
                    onImOutTapped: { phase = .imOut }
                )

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
                } else {
                    // Should be unreachable; defensive fallback.
                    ProgressView()
                }
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
                ResultCard(
                    food: food,
                    primaryAction: { logTapped(food) },
                    // "actually skip" on a populated card OR "retake →"
                    // on an empty-items defensive fallback — both bounce
                    // back to camera so the user can correct course.
                    secondaryAction: {
                        capturedFood = nil
                        phase = .camera
                    },
                    onItemTap: { item in editingItem = item }
                )
                .padding(FoodTheme.Space.screenPadding)
            }
        }
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
