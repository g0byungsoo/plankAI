import SwiftUI
import SwiftData
import PlankSync

// MARK: - WeighInLedgerSheet — `your weigh-ins` (v25 §34)
//
// The record's missing list. `33` gave the GLP-1 user `the doses` on the
// same argument one day earlier: the rows had been on the device since
// v24 and no screen had ever shown them. This is the identical defect in
// the domain the whole product is priced on.
//
// Becoming already draws the weight as a LINE. A line is a trend, and it
// is the right hero — but you cannot read a date off it, you cannot tell
// a scale-with-shoes-on from a real morning, and you cannot touch it. So
// the one number that outranks every other stored weight
// (`TargetsService.resolvedWeightKg` — the calorie target AND the protein
// floor derive from the freshest row) was the only fact in Jeni with no
// list and no repair.
//
// Shape, borrowed on purpose so nothing new was invented: the masthead
// is `FoodJournalView`'s ("your plates" → "your weigh-ins"), the rows are
// the regimen home's dose rows, and the editor is `JKWeightRitual` — the
// same instrument she learned in the consult and uses every morning,
// re-aimed at a past day.
//
// It reports and it never grades. A gain is set in the same typography
// as a loss, there is no red anywhere, no streak, no cadence count, and
// no "you haven't weighed in since Tuesday".

struct WeighInLedgerSheet: View {

    let userId: String
    let onClose: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @AppStorage("weightUnit") private var weightUnitRaw: String = "lb"

    @State private var editing: WeightLedger.Row?
    @State private var confirmingRemoval = false
    @State private var bump = 0
    @State private var arrived = false

    private var unit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .lb }

    /// A cohort the safety gate has told us to show no numerals to gets
    /// no ledger at all — the same standing law every other weight
    /// surface obeys. The door in Becoming is gated too; this is the
    /// belt to that braces.
    private var suppressed: Bool { CohortStore.isNumericSuppressed }

    private var entries: [WeightLedger.Entry] {
        let _ = bump
        return WeightLogWriter.entries(userId: userId, in: modelContext)
    }

    private var rows: [WeightLedger.Row] {
        WeightLedger.rows(entries, unit: unit)
    }

    private var stacksForType: Bool {
        typeSize.isAccessibilitySize || typeSize >= .xxxLarge
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()
            if let editing {
                editor(editing)
            } else {
                list
            }
        }
        .animation(Motion.crossFade, value: editing)
        .task {
            #if DEBUG
            // Film door — `--debug-weigh-ins-edit` opens the newest
            // row's editor without a tap. The editor carries the
            // destructive line, so it is the half of this surface most
            // in need of being looked at.
            if ProcessInfo.processInfo.arguments.contains("--debug-weigh-ins-edit") {
                try? await Task.sleep(nanoseconds: 500_000_000)
                editing = rows.first
            }
            #endif
            guard !arrived else { return }
            try? await Task.sleep(nanoseconds: 40_000_000)
            arrived = true
        }
        .environment(\.jeniArrived, arrived)
    }

    // MARK: - The list

    private var list: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .jeniArrive(arrived, index: 0)

                if suppressed {
                    suppressedState
                        .jeniArrive(arrived, index: 1)
                } else if rows.isEmpty {
                    emptyState
                        .jeniArrive(arrived, index: 1)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                            Button {
                                Haptics.soft()
                                editing = row
                            } label: {
                                rowBody(row)
                                    .padding(.vertical, 11)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(JKPress())
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(row.voiceOver)
                            .accessibilityHint("double-tap to fix or remove it")
                            if index != rows.count - 1 {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(height: 0.5)
                            }
                        }
                    }
                    .padding(.top, 6)
                    .jeniArrive(arrived, index: 1)

                    Text(footnote)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.lg)
                        .jeniArrive(arrived, index: 2)
                }

                Spacer(minLength: Space.heroGap)
            }
            .padding(.horizontal, Space.gutter)
        }
    }

    private var masthead: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("your weigh-ins")
                    .font(Typo.questionHero)
                    .foregroundStyle(Palette.textPrimary)
                if !suppressed, let count = WeightLedger.countLine(entries) {
                    Text(count)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            Spacer(minLength: Space.md)
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Palette.textPrimary.opacity(0.05)))
                    // p63 — 34pt visible, HIG-floor target (the same
                    // X was copy-pasted under-target on four sheets).
                    .tappableArea()
            }
            .buttonStyle(JeniPressable())
            .accessibilityIdentifier("weighins.close")
            .accessibilityLabel("done. closes your weigh-ins")
        }
        .padding(.top, Space.hero)
        .padding(.bottom, Space.sm)
    }

    /// The row: the day leads, the number answers, the change and the
    /// provenance sit under it. At accessibility sizes the pair stacks
    /// rather than competing for one line — the `medica/tion ozem/pic`
    /// law from `33`, applied before it can break.
    @ViewBuilder
    private func rowBody(_ row: WeightLedger.Row) -> some View {
        let day = Text(row.day)
            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
            .foregroundStyle(Palette.textPrimary)
        let value = Text(row.value)
            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
            .foregroundStyle(Palette.textPrimary)
            .monospacedDigit()

        VStack(alignment: .leading, spacing: 3) {
            if stacksForType {
                VStack(alignment: .leading, spacing: 2) {
                    day.fixedSize(horizontal: false, vertical: true)
                    // The numeral keeps one line at every size: the
                    // `124` → `12`/`4` law.
                    value.lineLimit(1).minimumScaleFactor(0.6)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .firstTextBaseline) {
                    day
                    Spacer(minLength: Space.md)
                    value.lineLimit(1).minimumScaleFactor(0.6)
                }
            }
            if let sub = subLine(row) {
                Text(sub)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "0.4 lb down · from health" — the change and the provenance share
    /// one quiet line, and the ordinary case (she typed it, and it is the
    /// oldest row) prints nothing at all.
    private func subLine(_ row: WeightLedger.Row) -> String? {
        let parts = [row.change, row.provenanceWord].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }

    private var footnote: String {
        "the freshest number here is the one your daily targets are built from. fixing one recomputes them; it never moves your starting weight."
    }

    private var emptyState: some View {
        JeniSurface {
            VStack(alignment: .leading, spacing: 6) {
                JeniHeadline("nothing on file yet.", italic: ["yet."])
                Text("every weigh-in lands here with its date, and you can fix or remove any of them.")
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, Space.lg)
    }

    private var suppressedState: some View {
        Text("we're keeping numbers off your screens for now. your weigh-ins are still on file.")
            .font(Typo.body)
            .foregroundStyle(Palette.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.lg)
    }

    // MARK: - The editor
    //
    // The same ruler as the morning ritual, seeded at the row's own
    // number. Saving corrects THAT weigh-in in place — same id, same
    // day, same user — rather than writing a new one today, which is
    // what `persist` would have done and is the whole reason a past
    // mistake used to be permanent.

    @ViewBuilder
    private func editor(_ row: WeightLedger.Row) -> some View {
        JKWeightRitual(
            startingFromKg: row.kg,
            priorLoggedCount: max(0, rows.count - 1),
            isUpdatingToday: true,
            titleOverride: "\(row.day)'s number",
            removeLabel: "remove this weigh-in",
            onRemove: { confirmingRemoval = true },
            onSave: { kg in
                guard !userId.isEmpty else { return }
                WeightLogWriter.update(
                    id: row.id, toKg: kg, userId: userId, in: modelContext
                )
            },
            onDone: { bump += 1; editing = nil },
            onCancel: { editing = nil }
        )
        .confirmationDialog(
            "let this weigh-in go?",
            isPresented: $confirmingRemoval,
            titleVisibility: .visible
        ) {
            Button("remove it", role: .destructive) {
                guard !userId.isEmpty else { return }
                WeightLogWriter.remove(id: row.id, userId: userId, in: modelContext)
                Haptics.soft()
                bump += 1
                editing = nil
            }
            Button("keep it", role: .cancel) {}
        } message: {
            Text(WeightLedger.removalNote(row.provenance, day: row.day))
        }
    }
}
