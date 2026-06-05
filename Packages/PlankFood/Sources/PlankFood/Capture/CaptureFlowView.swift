#if canImport(UIKit)
import SwiftUI
import SwiftData

// MARK: - CaptureFlowView
//
// End-to-end capture orchestrator. Wraps PhotoCaptureView → ResultCard
// → log persistence into a single fullScreenCover-presentable flow.
//
// Phases:
//   1. .camera     — PhotoCaptureView (shutter, mode chips)
//   2. .result     — ResultCard (review + edit + log)
//   3. .corrected  — FoodCorrectionSheet (per-item edit; returns to .result)
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

    @State private var phase: Phase = .camera
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
    }

    public var body: some View {
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            switch phase {
            case .camera:
                PhotoCaptureView(
                    onDismiss: onDismiss,
                    onCaptured: { food in
                        capturedFood = food
                        phase = .result
                    }
                )

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
                    capturedFood = capturedFood?.replacing(item: edited)
                    editingItem = nil
                },
                onCancel: { editingItem = nil }
            )
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
    case camera
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
