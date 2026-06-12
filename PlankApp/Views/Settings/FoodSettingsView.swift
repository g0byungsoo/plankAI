import SwiftUI

// MARK: - FoodSettingsView
//
// Settings sub-screen for the food rail per sprint W4-T4. Renders under
// ProfileHubView when FoodFlags.isEnabled. All values persist via
// AppStorage so changes are immediately reflected by HomeFoodCard,
// CaptureFlowView, and the FoodVisionService dispatch path.
//
// Sections (top → bottom):
//   1. daily target — kcal, editable, seeded from onboarding reveal
//   2. what you eat — dietary pattern + exclusions + cuisine
//   3. tracking    — HealthKit write toggle + evening check-in toggle
//   4. privacy     — photo retention + AI consent status + export
//
// Voice locks: lowercase section headers, italic-Fraunces punch words
// where natural, hearts ♥ as terminal punctuation, cocoa pill CTAs,
// scrapbook chrome on every grouped card.

struct FoodSettingsView: View {

    // MARK: - State

    @AppStorage("foodDailyTarget") private var foodDailyTargetKcal: Double = 1650
    @AppStorage("foodDietaryPattern") private var dietaryPattern: String = ""
    @AppStorage("foodExclusionsCSV") private var exclusionsCSV: String = ""
    @AppStorage("onboardingCuisinePreference") private var cuisineCSV: String = ""
    @AppStorage("foodHealthKitWriteEnabled") private var healthKitWriteEnabled: Bool = false
    /// Drives the daily 8:30pm Evening Plate Review push. Mirrors
    /// RetentionNotifications.eveningPlateReviewEnabled exactly — same
    /// UserDefaults key — so toggling here updates the schedule and the
    /// bootstrap path reads the same value.
    @AppStorage("notif.evening_plate_review_enabled") private var eveningCheckInEnabled: Bool = true
    @AppStorage("foodPhotoRetention") private var photoRetention: String = "discard"
    @AppStorage("foodAIConsentAccepted") private var aiConsentAccepted: Bool = false
    @AppStorage("foodAIConsentAt") private var aiConsentAt: String = ""

    @State private var calorieDraft: String = ""

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
        ScrollView {
            VStack(spacing: Space.lg) {
                dailyTargetSection
                whatYouEatSection
                trackingSection
                privacySection
            }
            .padding(.horizontal, Space.screenPadding)
            .padding(.top, Space.md)
            .padding(.bottom, 40)
        }
        .background(Palette.bgPrimary.ignoresSafeArea())
        .onAppear {
            calorieDraft = String(Int(foodDailyTargetKcal.rounded()))
        }
    }

    // MARK: - Daily target

    private var dailyTargetSection: some View {
        sectionCard(title: "your daily target") {
            HStack(spacing: 8) {
                TextField("kcal", text: $calorieDraft)
                    .keyboardType(.numberPad)
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: 110)
                    .onChange(of: calorieDraft) { _, newValue in
                        // Clamp to a sane range so a typo can't wreck
                        // the food card. Mifflin-St Jeor floor for a
                        // small adult is ~1200; pro athletes top out
                        // around 3500 kcal. Anything outside is more
                        // likely a typo than a real target.
                        if let kcal = Int(newValue) {
                            let clamped = max(1200, min(3500, kcal))
                            foodDailyTargetKcal = Double(clamped)
                            if clamped != kcal {
                                // Reflect the clamp back to the field
                                // so the user sees the corrected value.
                                calorieDraft = String(clamped)
                            }
                        }
                    }
                Text("kcal/day")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
                Spacer(minLength: 0)
            }
            Text("seeded from your goal pace + body data. tap to adjust.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text("each meal logs as dietary energy. off by default.")
                            .font(.system(size: 11))
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
                        Text("evening check-in ♥")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text("one soft look back at today's plate. 8:30pm.")
                            .font(.system(size: 11))
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
                        ("discard", "discard after analysis"),
                        ("keep30",  "keep 30 days"),
                    ],
                    current: photoRetention,
                    onSelect: { key in
                        Haptics.light()
                        photoRetention = key
                    }
                )

                Divider().background(Palette.divider)

                // AI consent — read-only display of acceptance state.
                // Cannot be toggled here; declined users go through the
                // sheet again at their next capture attempt.
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: aiConsentAccepted ? "checkmark.circle.fill" : "circle.dashed")
                        .font(.system(size: 16))
                        .foregroundStyle(aiConsentAccepted ? Palette.accent : Palette.textSecondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI consent")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Text(aiConsentAccepted
                             ? "accepted \(formattedConsentDate)"
                             : "not yet. you'll see the disclosure on your next scan.")
                            .font(.system(size: 11))
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
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helpers

    private func sectionCard<Content: View>(
        title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Space.md) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.4)
                .foregroundStyle(Palette.textSecondary)
                .textCase(.uppercase)
            content()
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(scrapbookChrome())
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
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

    private func scrapbookChrome() -> some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Palette.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Palette.textPrimary, lineWidth: 1)
            )
            .shadow(color: Palette.textPrimary.opacity(0.18), radius: 0, x: 2, y: 2)
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selected ? Palette.bgInverse : Palette.accentSubtle.opacity(0.5))
                        )
                }
                .buttonStyle(.plain)
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
            let size = s.sizeThatFits(.unspecified)
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
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            s.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
