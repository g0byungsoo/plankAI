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
    /// Owning user id — used to pull personal recents from
    /// FoodLogPersister. Empty string disables the recents chip
    /// section and falls back to cuisine + evergreen only.
    public let userId: String
    /// CSV of cuisine keys from onboardingCuisinePreference (e.g.
    /// "american,italian,eastAsian"). nil / empty falls back to a
    /// neutral evergreen chip set.
    public let cuisineCSV: String?
    /// Today's program-day archetype string ("protein" / "balanced" /
    /// "movement" / "rest"). Empty / unknown values skip the archetype
    /// chip section. PlankFood doesn't know about ProgramDayArchetype
    /// (that type lives in PlankApp) — callers pass the raw string and
    /// the composer maps it to its own internal pool. Phase 2 of the
    /// program-quality archetype build (2026-06-17).
    public let archetypeHint: String?

    @State private var inputText: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String?
    @FocusState private var textFocused: Bool

    public init(
        onLogged: @escaping (CapturedFood) -> Void,
        onScanInstead: @escaping () -> Void,
        onDismiss: @escaping () -> Void,
        userId: String = "",
        cuisineCSV: String? = nil,
        archetypeHint: String? = nil
    ) {
        self.onLogged = onLogged
        self.onScanInstead = onScanInstead
        self.onDismiss = onDismiss
        self.userId = userId
        self.cuisineCSV = cuisineCSV
        self.archetypeHint = archetypeHint
    }

    /// v1.0.10 (2026-06-17) — suggestions are now per-user + per-day-
    /// archetype. Computed once per appearance: today's archetype picks
    /// (3 chips) → recents (top 5) → cuisine pool (≤7) → evergreen
    /// defaults (≤3). Archetype chips render first so a protein-day
    /// user sees protein-forward options before anything else.
    private var suggestions: [QuickAddSuggestion] {
        QuickAddSuggestion.compose(
            userId: userId,
            cuisineCSV: cuisineCSV,
            archetypeHint: archetypeHint
        )
    }

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
                ForEach(suggestions) { suggestion in
                    suggestionChip(suggestion)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func suggestionChip(_ suggestion: QuickAddSuggestion) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            inputText = suggestion.text
            textFocused = true
        } label: {
            HStack(spacing: 5) {
                if let icon = suggestion.kind.iconName {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(FoodTheme.textSecondary)
                }
                Text(suggestion.text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(FoodTheme.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Capsule().fill(suggestion.kind.background))
            .overlay(Capsule().stroke(suggestion.kind.stroke, lineWidth: 1))
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
        dispatcher.dietaryProfile = dietaryProfile
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

    /// v1.1.3 (2026-06-29) — dietary pattern + restrictions + allergies
    /// CSV from onboarding (case 170). Read straight into the food-vision
    /// dietary_profile hint, same as cuisineProfile.
    private var dietaryProfile: String? {
        UserDefaults.standard.string(forKey: "onboarding_dietary")
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

// MARK: - QuickAddSuggestion
//
// v1.0.10 (2026-06-17) — typed quick-add chip. Replaces the hardcoded
// `[String]` chip list with a model that knows where each suggestion
// came from (the user's own logs, an onboarding-declared cuisine,
// or a neutral evergreen drink default). The chip view consults
// `kind` to pick its icon + color so a returning user can tell at a
// glance which chips are personalized vs. universal.
//
// Composition order — locked: recents first (~5), then cuisine
// suggestions (~5–7), then a small evergreen drink default set (~3).
// Recents shadow lower-ranked chips by case-folded text so a heavy
// "matcha latte" logger doesn't see it duplicated under the cuisine
// section.

struct QuickAddSuggestion: Identifiable, Hashable {
    let id: String
    let text: String
    let kind: Kind

    enum Kind: Hashable {
        /// Today's archetype-themed pick — surfaces first so a protein-
        /// day user sees protein-forward chips before anything else.
        case archetype
        case recent
        case cuisine
        case evergreen

        var iconName: String? {
            switch self {
            case .archetype: return "sparkle"
            case .recent:    return "clock"
            case .cuisine:   return nil
            case .evergreen: return nil
            }
        }

        var background: Color {
            switch self {
            case .archetype: return FoodTheme.stateGood.opacity(0.10)
            case .recent:    return FoodTheme.accent.opacity(0.10)
            default:         return FoodTheme.bgElevated
            }
        }

        var stroke: Color {
            switch self {
            case .archetype: return FoodTheme.stateGood.opacity(0.55)
            case .recent:    return FoodTheme.accent.opacity(0.55)
            default:         return FoodTheme.accent.opacity(0.45)
            }
        }
    }
}

extension QuickAddSuggestion {
    /// Compose the chip list. Returns a deterministic ordering so the
    /// view doesn't shuffle between renders.
    @MainActor
    static func compose(
        userId: String,
        cuisineCSV: String?,
        archetypeHint: String? = nil
    ) -> [QuickAddSuggestion] {
        var seen: Set<String> = []
        var out: [QuickAddSuggestion] = []

        // 0. ARCHETYPE — today's protein/balanced/movement/rest theme.
        // 3 picks from the archetype pool render first so the chip
        // cloud's lead row matches the day's nutrition register. Empty
        // hint or unknown key skips silently — the rest of the
        // composition is unchanged.
        if let hint = archetypeHint?.lowercased(),
           let pool = archetypePool[hint] {
            for text in pool.prefix(3) {
                let key = text.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(QuickAddSuggestion(
                    id: "archetype_" + hint + "_" + key,
                    text: text,
                    kind: .archetype
                ))
            }
        }

        // 1. RECENTS — dedupe by case-folded title, cap at 5. Skip
        // entries with empty titles (legacy logs pre-D3.B).
        if !userId.isEmpty {
            let recent = FoodLogPersister.allEntries(userId: userId)
                .sorted { $0.loggedAt > $1.loggedAt }
                .map { $0.title.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(40)

            for title in recent {
                let key = title.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(QuickAddSuggestion(
                    id: "recent_" + key,
                    text: title.lowercased(),
                    kind: .recent
                ))
                if out.count >= 5 { break }
            }
        }

        // 2. CUISINE — split the CSV, pull each cuisine's top picks.
        // Round-robin so a user with multiple cuisines sees a mix
        // (italian + mexican users shouldn't get all italian before
        // any mexican appears). Cap the section at 7.
        let cuisines = (cuisineCSV ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            .filter { !$0.isEmpty }
        var cuisinePools = cuisines.compactMap { cuisinePool[$0] }
        var cuisineEmitted = 0
        outer: while !cuisinePools.isEmpty {
            for i in cuisinePools.indices {
                guard !cuisinePools[i].isEmpty else { continue }
                let candidate = cuisinePools[i].removeFirst()
                let key = candidate.lowercased()
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                out.append(QuickAddSuggestion(
                    id: "cuisine_" + key,
                    text: candidate,
                    kind: .cuisine
                ))
                cuisineEmitted += 1
                if cuisineEmitted >= 7 { break outer }
            }
            cuisinePools.removeAll { $0.isEmpty }
        }

        // 3. EVERGREEN — universal drink + breakfast defaults. Always
        // tail the list (small set; user has options even on day 1).
        for text in evergreen {
            let key = text.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            out.append(QuickAddSuggestion(
                id: "evergreen_" + key,
                text: text,
                kind: .evergreen
            ))
        }

        return out
    }

    /// Cuisine-keyed default picks. Keys match the FoodSettingsView
    /// cuisine option set (american, italian, mexican, eastAsian,
    /// southAsian, mediterranean, other) PLUS the legacy onboarding
    /// keys (korean, japanese, chinese, indian) — existing users still
    /// have those in AppStorage until they edit settings.
    static let cuisinePool: [String: [String]] = [
        "american": [
            "chick-fil-a grilled nuggets",
            "two slices of cheese pizza",
            "chipotle chicken bowl",
            "panera mediterranean bowl",
        ],
        "italian": [
            "pasta carbonara",
            "margherita pizza slice",
            "caprese salad",
            "lemon ricotta pancakes",
        ],
        "mexican": [
            "chipotle chicken bowl",
            "two carne asada tacos",
            "carnitas burrito",
            "elote (mexican street corn)",
        ],
        "eastAsian": [
            "salmon rice bowl",
            "8-piece sushi roll",
            "pad thai with chicken",
            "bibimbap bowl",
        ],
        "korean": ["bibimbap bowl", "korean fried chicken", "kimchi stew"],
        "japanese": ["salmon poke bowl", "8-piece sushi roll", "matcha latte with oat milk"],
        "chinese": ["dumplings (6 pieces)", "kung pao chicken", "fried rice with shrimp"],
        "southAsian": [
            "chicken tikka masala with rice",
            "naan with butter chicken",
            "biryani bowl",
            "samosa (2 pieces)",
        ],
        "indian": ["chicken tikka masala with rice", "naan with butter chicken", "biryani bowl"],
        "mediterranean": [
            "cava chicken bowl",
            "greek salad with chicken",
            "hummus with pita",
            "chicken shawarma wrap",
        ],
        // 2026-06-29 - onboarding case 169 cuisine inclusivity expansion.
        // New keys read straight into the food-vision cuisine_profile
        // hint; these pools keep their QuickAdd suggestion chips on-brand.
        "soulFood": [
            "fried chicken with collard greens",
            "shrimp and grits",
            "baked mac and cheese",
            "cornbread with honey butter",
        ],
        "middleEastern": [
            "chicken shawarma plate",
            "falafel with hummus",
            "lamb kofta with rice",
            "tabbouleh salad",
        ],
        "caribbean": [
            "jerk chicken with rice and peas",
            "oxtail stew",
            "grilled plantains",
            "ackee and saltfish",
        ],
        // 2026-06-29 - case 169 specific-culture chip expansion. New keys
        // read straight into the food-vision cuisine_profile hint; these
        // pools keep their QuickAdd suggestion chips on-brand + cohort-real.
        "thai": [
            "pad thai with chicken",
            "green curry with rice",
            "thai basil chicken (pad krapow)",
            "mango sticky rice",
        ],
        "vietnamese": [
            "chicken pho",
            "banh mi sandwich",
            "vermicelli bowl (bun)",
            "fresh spring rolls",
        ],
        "filipino": [
            "chicken adobo with rice",
            "pancit bihon",
            "lumpia (3 pieces)",
            "sinigang (sour soup)",
        ],
        "french": [
            "nicoise salad",
            "ratatouille",
            "croque madame",
            "quiche lorraine slice",
        ],
        "greek": [
            "chicken souvlaki bowl",
            "greek salad with feta",
            "chicken gyro wrap",
            "spanakopita slice",
        ],
        "spanish": [
            "seafood paella",
            "spanish tortilla slice",
            "gambas al ajillo",
            "patatas bravas",
        ],
        "brazilian": [
            "grilled picanha with rice and beans",
            "feijoada bowl",
            "grilled chicken with farofa",
            "acai bowl",
        ],
        "ethiopian": [
            "doro wat with injera",
            "misir wat (red lentils)",
            "gomen (collard greens)",
            "veggie combo platter",
        ],
        "everything": [
            "sweetgreen harvest bowl",
            "protein smoothie",
            "avocado toast with egg",
        ],
        "other": [
            "sweetgreen harvest bowl",
            "protein smoothie",
            "avocado toast with egg",
        ],
    ]

    /// Universal defaults: high-frequency cohort orders that work
    /// regardless of cuisine. Tail of the chip list — always visible
    /// so a new user without recents or cuisine still gets 3 options.
    static let evergreen: [String] = [
        "matcha latte with oat milk",
        "iced brown sugar oatmilk shaken espresso",
        "avocado toast with egg",
    ]

    /// Archetype-keyed chip pools — surfaced first on the chip cloud
    /// when the caller passes today's archetype. Each pool is curated
    /// for the day's nutrition register per the 2026-06-17 research
    /// session: protein-forward picks on protein days, neutral mix on
    /// balanced days, slightly higher-carb fuel options on movement
    /// days, hydration + softer options on rest days. Top 3 of each
    /// pool render with the `.archetype` kind (sage tint, sparkle
    /// icon) so the user sees them as "today's pick" rather than
    /// generic suggestions. Keys match the `rawValue` of
    /// PlankApp's ProgramDayArchetype enum.
    static let archetypePool: [String: [String]] = [
        "protein": [
            "chick-fil-a grilled nuggets",
            "salmon rice bowl",
            "greek yogurt with berries",
            "chipotle chicken bowl",
            "fairlife protein shake",
        ],
        "balanced": [
            "sweetgreen harvest bowl",
            "cava chicken bowl",
            "avocado toast with egg",
            "pad thai with chicken",
            "berry smoothie",
        ],
        "movement": [
            "oatmeal with peanut butter",
            "banana with peanut butter",
            "sweet potato + chicken bowl",
            "fairlife protein shake",
            "lemon ricotta pancakes",
        ],
        "rest": [
            "matcha latte with oat milk",
            "chicken noodle soup",
            "caesar salad with chicken",
            "bone broth",
            "chamomile tea with honey",
        ],
    ]
}

#endif  // canImport(UIKit)
