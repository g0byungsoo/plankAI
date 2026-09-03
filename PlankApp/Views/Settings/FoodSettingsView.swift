import SwiftUI

// MARK: - FoodSettingsView
//
// Settings sub-screen for the food rail per sprint W4-T4. Renders under
// ProfileHubView when FoodFlags.isEnabled. All values persist via
// AppStorage so changes are immediately reflected by HomeFoodCard,
// CaptureFlowView, and the FoodVisionService dispatch path.
//
// Sections (top → bottom):
//   1. daily target — READ-ONLY (p71): the number TargetsService
//      actually uses. The old editable field wrote `foodDailyTarget`,
//      a v1-era knob nothing on the arithmetic path reads (its own
//      SnapResultView comment calls it "the legacy AppStorage value…
//      previews, package tests"), so editing it changed nothing on
//      Home — a dead control presented as the daily target. Change
//      flows through `your numbers` (weight · movement · pace), where
//      the plan actually derives.
//   2. what you eat — dietary pattern + exclusions + cuisine
//   3. tracking    — HealthKit write toggle + evening check-in toggle
//   4. privacy     — photo retention + AI consent status + export
//
// Voice locks: lowercase section headers, italic-Fraunces punch words
// where natural, hearts as terminal punctuation. v1.1 clean-luxury
// pass: hairline sections (SettingsChrome), no card chrome.

struct FoodSettingsView: View {

    let userId: String

    // MARK: - State

    @Environment(\.modelContext) private var modelContext
    @AppStorage("foodDietaryPattern") private var dietaryPattern: String = ""
    @AppStorage("foodExclusionsCSV") private var exclusionsCSV: String = ""
    @AppStorage("onboardingCuisinePreference") private var cuisineCSV: String = ""
    @AppStorage("foodHealthKitWriteEnabled") private var healthKitWriteEnabled: Bool = false
    /// Drives the daily 8:30pm Evening Plate Review push. Mirrors
    /// RetentionNotifications.eveningPlateReviewEnabled exactly — same
    /// UserDefaults key — so toggling here updates the schedule and the
    /// bootstrap path reads the same value.
    @AppStorage("notif.evening_plate_review_enabled") private var eveningCheckInEnabled: Bool = true
    /// Release audit 2026-08-08 — default flipped "discard" → "keep":
    /// the control had no reader (photos always persisted), so the old
    /// default was a broken promise; keep matches actual behavior and
    /// the book's photograph-led design. "discard" is honored at the
    /// persist seam now; the unbackable "keep 30 days" tier retired
    /// (no server cleanup exists) — stored "keep30" reads as keep.
    @AppStorage("foodPhotoRetention") private var photoRetention: String = "keep"
    @AppStorage("foodAIConsentAccepted") private var aiConsentAccepted: Bool = false
    @AppStorage("foodAIConsentAt") private var aiConsentAt: String = ""

    // MARK: - Lookups

    private static let dietaryOptions: [(key: String, label: String)] = [
        ("omnivore",     "omnivore"),
        ("pescatarian",  "pescatarian"),
        ("vegetarian",   "vegetarian"),
        ("vegan",        "vegan"),
    ]

    private static let exclusionOptions: [(key: String, label: String)] = [
        ("dairy",     "dairy"),
        ("gluten",    "gluten"),
        ("nuts",      "nuts"),
        ("shellfish", "shellfish"),
        ("eggs",      "eggs"),
        ("soy",       "soy"),
    ]

    // v4.6 (2026-06-11): key space matches the onboarding cuisine photo
    // grid (case 169). Legacy keys (korean/japanese/chinese) persist in
    // the CSV for existing users until they edit here.
    private static let cuisineOptions: [(key: String, label: String)] = [
        ("american",      "american"),
        ("italian",       "italian"),
        ("mexican",       "mexican"),
        ("eastAsian",     "east asian"),
        ("southAsian",    "south asian"),
        ("mediterranean", "mediterranean"),
        ("other",         "other"),
    ]

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                JFPageHero(title: "your food.", italic: ["food."], alignment: .leading)
                    .padding(.horizontal, -Space.screenPadding)

                Spacer().frame(height: 28)
                dailyTargetSection
                Spacer().frame(height: 36)
                whatYouEatSection
                Spacer().frame(height: 36)
                trackingSection
                Spacer().frame(height: 36)
                privacySection
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Palette.programEraBg)
    }

    // MARK: - Daily target (read-only — the number the dial uses)

    /// The one energy authority. nil = no number (honest absence);
    /// a suppressed cohort renders no numeral section at all — the
    /// old editable field showed "1650 kcal/day" to everyone.
    private var resolvedTargets: TargetsService.Targets {
        TargetsService.current(userId: userId, in: modelContext)
    }

    @ViewBuilder
    private var dailyTargetSection: some View {
        let targets = resolvedTargets
        if !targets.numericsSuppressed {
            sectionCard(title: "your daily target") {
                if let kcal = targets.kcal {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(kcal.formatted())")
                            .font(.custom("Fraunces72pt-SemiBold", size: 28))
                            .foregroundStyle(Palette.textPrimary)
                            .monospacedDigit()
                            // p72 — the p51-D2 scale floor: at AX5 this
                            // numeral wrapped MID-NUMBER ("1,59 / 6",
                            // SE-filmed). A numeral scales, never wraps.
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("kcal/day")
                            .font(.custom("DMSans-Regular", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textSecondary)
                        Spacer(minLength: 0)
                    }
                    Text("set by your plan. to change it, adjust weight, movement or pace in your numbers.")
                        .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("no energy number yet. once your numbers are in, it appears here.")
                        .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - What you eat

    private var whatYouEatSection: some View {
        sectionCard(title: "what you eat") {
            VStack(alignment: .leading, spacing: Space.md) {
                fieldLabel("dietary pattern")
                singleSelectChipRow(
                    options: Self.dietaryOptions,
                    current: dietaryPattern,
                    onSelect: { key in
                        Haptics.light()
                        dietaryPattern = (dietaryPattern == key) ? "" : key
                    }
                )

                fieldLabel("exclusions")
                multiSelectChipRow(
                    options: Self.exclusionOptions,
                    binding: csvBinding(for: $exclusionsCSV)
                )

                fieldLabel("cuisine profile")
                multiSelectChipRow(
                    options: Self.cuisineOptions,
                    binding: csvBinding(for: $cuisineCSV)
                )
            }
        }
    }

    // MARK: - Tracking

    private var trackingSection: some View {
        sectionCard(title: "tracking") {
            VStack(alignment: .leading, spacing: Space.md) {
                Toggle(isOn: $healthKitWriteEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("write to apple health")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                        Text("each meal logs as dietary energy. off by default.")
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .tint(Palette.accent)
                .onChange(of: healthKitWriteEnabled) { _, newValue in
                    Haptics.light()
                    if newValue {
                        // First flip-on surfaces the system HK share
                        // sheet. If the user denies, the toggle stays
                        // on but writes silently no-op until they
                        // grant access via Settings → Health → JeniFit.
                        Task {
                            await HealthKitDietaryEnergyWriter.shared.requestAuthorization()
                        }
                    }
                }

                Divider().background(Palette.divider)

                Toggle(isOn: $eveningCheckInEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("evening check-in")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                        Text("one soft look back at today's plate. 8:30pm.")
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .tint(Palette.accent)
                .onChange(of: eveningCheckInEnabled) { _, _ in
                    Haptics.light()
                    // The scheduler reads eveningPlateReviewEnabled
                    // internally and either schedules or cancels — same
                    // path either way. Idempotent re-arm.
                    RetentionNotifications.scheduleEveningPlateReview()
                }
            }
        }
    }

    // MARK: - Privacy

    private var privacySection: some View {
        sectionCard(title: "privacy") {
            VStack(alignment: .leading, spacing: Space.md) {
                fieldLabel("photo retention")
                singleSelectChipRow(
                    options: [
                        // v25 §37 — ONE NAME FOR THE FOOD RECORD. Nine
                        // customer-facing strings call it `your plates`
                        // (the door in becoming › your record, the
                        // screen's own masthead, every Becoming tile's
                        // provenance whisper, jeni's `doors` block).
                        // This was the last one calling it `my journal`,
                        // which made a privacy setting read as if it
                        // governed a different record from the one she
                        // opens.
                        ("keep",    "keep with my plates"),
                        ("discard", "discard after analysis"),
                    ],
                    current: photoRetention == "discard" ? "discard" : "keep",
                    onSelect: { key in
                        Haptics.light()
                        photoRetention = key
                    }
                )

                Divider().background(Palette.divider)

                // Photo-analysis consent — read-only display of
                // acceptance state. Cannot be toggled here; declined
                // users go through the sheet again at their next
                // capture attempt.
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: aiConsentAccepted ? "checkmark.circle" : "circle.dashed")
                        .font(.custom("DMSans-Light", size: 16, relativeTo: .body))
                        .foregroundStyle(aiConsentAccepted ? Palette.accent : Palette.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("photo analysis consent")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                        Text(aiConsentAccepted
                             ? "accepted \(formattedConsentDate)"
                             : "not yet. you'll see the disclosure on your next scan.")
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }

                Divider().background(Palette.divider)

                // Export — mailto handoff. The export-data flow is a
                // privacy floor (Apple 5.1.5 + GDPR right-to-data).
                Button {
                    Haptics.light()
                    if let url = URL(string: "mailto:support@jenifit.app?subject=export%20my%20data") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack {
                        Text("export my data")
                            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .buttonStyle(JKPress())
            }
        }
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        SettingsSection(title: title) {
            VStack(alignment: .leading, spacing: Space.md) {
                content()
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
            }
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.textSecondary)
    }

    private func singleSelectChipRow(
        options: [(key: String, label: String)],
        current: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        FoodChipFlowLayoutChipRow(
            options: options,
            isSelected: { $0 == current },
            onTap: onSelect
        )
    }

    private func multiSelectChipRow(
        options: [(key: String, label: String)],
        binding: Binding<Set<String>>
    ) -> some View {
        FoodChipFlowLayoutChipRow(
            options: options,
            isSelected: { binding.wrappedValue.contains($0) },
            onTap: { key in
                Haptics.light()
                if binding.wrappedValue.contains(key) {
                    binding.wrappedValue.remove(key)
                } else {
                    binding.wrappedValue.insert(key)
                }
            }
        )
    }

    /// CSV ↔ Set bridge so AppStorage strings can drive a multi-select
    /// chip row's Set<String> binding without per-call boilerplate.
    private func csvBinding(for storage: Binding<String>) -> Binding<Set<String>> {
        Binding<Set<String>>(
            get: {
                Set(storage.wrappedValue
                    .split(separator: ",")
                    .map(String.init)
                    .filter { !$0.isEmpty })
            },
            set: { newValue in
                storage.wrappedValue = newValue.sorted().joined(separator: ",")
            }
        )
    }

    private var formattedConsentDate: String {
        let iso = ISO8601DateFormatter()
        guard !aiConsentAt.isEmpty, let date = iso.date(from: aiConsentAt) else {
            return ""
        }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date).lowercased()
    }

}

// MARK: - FoodChipFlowLayoutChipRow
//
// Wrapping HStack of selectable chips. Native HStack would clip on
// narrow viewports for the larger chip sets (e.g. 8 cuisines); this
// uses an iOS 16+ Layout for natural line wrapping.

private struct FoodChipFlowLayoutChipRow: View {
    let options: [(key: String, label: String)]
    let isSelected: (String) -> Bool
    let onTap: (String) -> Void

    var body: some View {
        FoodChipFlowLayout(spacing: 8) {
            ForEach(options, id: \.key) { opt in
                let selected = isSelected(opt.key)
                Button {
                    onTap(opt.key)
                } label: {
                    Text(opt.label)
                        .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                        .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                        // p72 — at AX5 a chip wider than the screen ran
                        // off the edge mid-word ("keep with my plat…",
                        // SE-filmed). The layout now proposes its own
                        // width, and the words wrap inside the capsule.
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(selected ? Palette.bgInverse : Palette.accentSubtle.opacity(0.5))
                        )
                }
                .buttonStyle(JKPress())
            }
        }
    }
}

// Minimal flow Layout — wraps subviews onto new rows when they would
// overflow the proposed width. iOS 16+. Used only by the chip row above.
private struct FoodChipFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for s in subviews {
            // p72 — cap the proposal at the container: a chip that
            // cannot fit on one line wraps its words instead of
            // running off the screen edge (AX5, SE-filmed).
            let size = s.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if currentX + size.width > maxWidth, currentX > 0 {
                totalHeight += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
        totalHeight += currentRowHeight
        return CGSize(width: maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0

        for s in subviews {
            let capped = ProposedViewSize(width: bounds.width, height: nil)
            let size = s.sizeThatFits(capped)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: capped)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
