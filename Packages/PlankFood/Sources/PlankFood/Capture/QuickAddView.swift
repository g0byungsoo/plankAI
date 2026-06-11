#if canImport(UIKit)
import SwiftUI

// MARK: - QuickAddView
//
// v1.0.9 D1 (2026-06-08) — text-first quick add. Replaces the v1.0.7
// 50-tile canonical_pantry catalog. Founder direction: "for quick-add
// my intention was for user to write anything and openai to analyze
// and calculate calories."
//
// Flow:
//   1. user types free-text description of what they ate
//      ("two slices pepperoni pizza", "matcha latte oat milk grande")
//   2. tap "log it" → FoodVisionService.scanText routes through the
//      same food-vision EF (text branch added in same commit) and
//      returns a CapturedFood with kcal + macros
//   3. CaptureFlowView's .result phase shows the result card
//
// Cost: ~5× cheaper than photo path since no image tokens. Latency
// also faster — typical text request lands in 1-2s vs 3-5s for vision.
//
// Quick-suggestion chips below the form pre-fill the text on tap.
// They're meant as discoverability for the common cohort orders, NOT
// as one-tap log shortcuts (every tap still goes through the model
// for accuracy — Chipotle bowls vary; Starbucks orders vary).

public struct QuickAddView: View {

    public let onLogged: (CapturedFood) -> Void
    public let onScanInstead: () -> Void
    public let onDismiss: () -> Void

    @State private var inputText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @FocusState private var textFocused: Bool

    public init(
        onLogged: @escaping (CapturedFood) -> Void,
        onScanInstead: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.onLogged = onLogged
        self.onScanInstead = onScanInstead
        self.onDismiss = onDismiss
    }

    // Quick suggestions — pre-fill the text field on tap. Pick the
    // 12 cohort orders that are most-typed-but-vague (so they benefit
    // from the model resolving portion + macros). Order matters:
    // first 6 cover ~60% of cohort intake per Cal AI top-50.
    private let suggestions: [String] = [
        "matcha latte with oat milk",
        "chipotle chicken bowl",
        "avocado toast with egg",
        "greek yogurt parfait",
        "iced brown sugar oatmilk shaken espresso",
        "chick-fil-a grilled nuggets",
        "two slices of cheese pizza",
        "cava chicken bowl",
        "raising cane's 3-finger combo",
        "protein smoothie",
        "caesar salad with chicken",
        "sweetgreen harvest bowl",
    ]

    public var body: some View {
        ZStack {
            FoodTheme.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                ScrollView {
                    VStack(spacing: 24) {
                        header
                        inputCard
                        suggestionsBlock
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }

            // Loading overlay during submit
            if isSubmitting {
                loadingOverlay
            }
        }
        .onAppear {
            // Auto-focus the field after a beat so the keyboard
            // rises smoothly without fighting the view-in animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                textFocused = true
            }
        }
        .overlay(alignment: .top) {
            if let errorMessage {
                errorBanner(errorMessage)
                    .padding(.horizontal, 20)
                    .padding(.top, 70)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    // MARK: - Top bar

    @ViewBuilder private var topBar: some View {
        HStack {
            Button(action: onScanInstead) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13, weight: .medium))
                    Text("scan instead")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(FoodTheme.accent)
            }

            Spacer()

            Button(action: onDismiss) {
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
    }

    // MARK: - Header

    @ViewBuilder private var header: some View {
        VStack(spacing: 8) {
            (
                Text("what'd you ")
                    .font(.system(size: 28, weight: .semibold))
                + Text("eat")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                + Text(" ♥")
                    .font(.system(size: 28, weight: .semibold))
            )
            .foregroundStyle(FoodTheme.textPrimary)
            .multilineTextAlignment(.center)

            Text("type any meal or drink. jeni'll figure out the calories.")
                .font(.system(size: 14))
                .foregroundStyle(FoodTheme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Input card

    @ViewBuilder private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack(alignment: .topLeading) {
                if inputText.isEmpty {
                    Text("e.g. matcha latte with oat milk, or two slices of pizza")
                        .font(.system(size: 15))
                        .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 8)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $inputText)
                    .focused($textFocused)
                    .font(.system(size: 15))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 100)
                    .tint(FoodTheme.accent)
            }

            Button {
                guard !trimmedInput.isEmpty, !isSubmitting else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                Task { await submit() }
            } label: {
                Text("log it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        Capsule().fill(
                            trimmedInput.isEmpty
                            ? FoodTheme.textPrimary.opacity(0.35)
                            : FoodTheme.textPrimary
                        )
                    )
                    .shadow(
                        color: trimmedInput.isEmpty ? .clear : FoodTheme.textPrimary.opacity(0.18),
                        radius: 8, x: 0, y: 2
                    )
            }
            .disabled(trimmedInput.isEmpty || isSubmitting)
        }
        .padding(18)
        .background(FoodTheme.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: FoodTheme.textPrimary.opacity(0.15), radius: 0, x: 3, y: 3)
    }

    // MARK: - Suggestions block

    @ViewBuilder private var suggestionsBlock: some View {
        VStack(alignment: .leading, spacing: 12) {
            (
                Text("or pick a ")
                    .font(.system(size: 14))
                + Text("vibe")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                + Text(" ♥")
                    .font(.system(size: 14))
            )
            .foregroundStyle(FoodTheme.textSecondary)

            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    suggestionChip(suggestion)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func suggestionChip(_ text: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            inputText = text
            textFocused = true
        } label: {
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(FoodTheme.bgElevated))
                .overlay(Capsule().stroke(FoodTheme.accent.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Loading overlay

    @ViewBuilder private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()

            VStack(spacing: 18) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(.white)

                (
                    Text("jeni's ")
                        .font(.system(size: 15))
                    + Text("thinking")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 15))
                    + Text(" ♥")
                        .font(.system(size: 15))
                )
                .foregroundStyle(.white)
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
        }
        .colorScheme(.dark)
    }

    // MARK: - Error banner

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
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(FoodTheme.bgPrimary)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
    }

    // MARK: - Actions

    private var trimmedInput: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submit() async {
        let text = trimmedInput
        guard !text.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }

        let dispatcher = FoodCaptureDispatcher()
        do {
            let result = try await dispatcher.dispatch(
                .text(text, cuisineProfile: cuisineProfile)
            )
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            onLogged(result)
        } catch let captureError as FoodCaptureError {
            errorMessage = captureError.errorDescription
                ?? "couldn't read that just now. try rephrasing?"
            FoodAnalytics.track(.scanFallbackFired, properties: [
                "reason": "text_quickadd_error",
                "case": String(describing: captureError),
            ])
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription
                ?? "couldn't read that just now. try rephrasing?"
        }
    }

    private var cuisineProfile: String? {
        UserDefaults.standard.string(forKey: "onboardingCuisinePreference")
    }
}

// MARK: - FlowLayout
//
// Simple SwiftUI flow layout for the suggestion chips. Wraps children
// onto new lines when they exceed the available width.

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var totalHeight: CGFloat = 0
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = size.width + spacing
                rowHeight = size.height
            } else {
                rowWidth += size.width + spacing
                rowHeight = max(rowHeight, size.height)
            }
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#endif  // canImport(UIKit)
