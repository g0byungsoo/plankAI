import SwiftUI
import SwiftData
import PlankSync

// MARK: - DoseSheet (app v24 THE REGIMEN)
//
// THE DOSE SHEET — the medication row's module. Everything already
// known is already filled: her medication and dose read from the
// regimen, the site the rotation suggests is pre-chosen, the mark
// is one tap. Clinical register throughout (v8 FR2): ink and
// hairlines, no rose, no celebration — the timestamp is the reward.
//
// Faces:
//   · due (today, unmarked): site cells + note + "mark it taken"
//     + a quiet "not today" that opens skip reasons.
//   · taken: the record ("taken · 8:04 pm"), site still editable,
//     "didn't, actually" unmark door.
//   · late (a past slot inside its window): "log it late, or let
//     it go." — mark writes the SLOT day with the real takenAt.
//   · oral: no injection vocabulary anywhere; oral semaglutide
//     carries the label rhythm line (water, a quiet half hour).

struct DoseSheet: View {
    let userId: String
    let slotDayKey: String
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var plan: RegimenPlanRecord?
    @State private var event: DoseEventRecord?
    @State private var pickedSite: InjectionSite?
    @State private var suggestedSite: InjectionSite?
    @State private var rotationLine: String?
    @State private var note: String = ""
    @State private var showSkipReasons = false
    @State private var justMarked = false
    // v25 E2 — the late face's label facts + the taken face's
    // symptom door (the end-of-cycle moment side effects already
    // belong to).
    @State private var consecutiveMissed = 0
    @State private var showSideEffects = false
    // p53 — the late face asks WHEN it was actually taken (the
    // cycle anchors to the real injection, not the tap), and any
    // taken face can carry HER word for this shot's strength.
    @State private var lateTakeDayKey: String? = nil
    @State private var doseWordDraft: String = ""
    @State private var editingDoseWord = false

    private var isOral: Bool { plan?.route == "oral" }
    private var isCareTeam: Bool {
        plan.map(RegimenService.isManagedByCareTeam) ?? false
    }
    private var isLate: Bool { slotDayKey != TodayStateService.dayKey() }
    private var isTaken: Bool { event?.status == "taken" }
    private var doseNoun: String { isOral ? "pill" : "shot" }

    private var emptyStomach: Bool {
        MedicationCatalog.product(id: plan?.productId)?.emptyStomach ?? false
    }

    /// "ozempic · 0.5 mg" — only what she declared; nothing renders
    /// when nothing is known.
    private var factsLine: String? {
        guard let plan else { return nil }
        let name = MedicationCatalog.renderName(
            productId: plan.productId, displayName: plan.displayName
        )
        var parts: [String] = name == "your medication" ? [] : [name]
        if let dose = plan.strengthValue {
            parts.append("\(MedicationProduct.doseWord(dose)) \(plan.strengthUnit ?? "mg")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var slotWeekdayWord: String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        guard let day = f.date(from: slotDayKey) else { return "" }
        let words = ["sunday", "monday", "tuesday", "wednesday",
                     "thursday", "friday", "saturday"]
        return words[Calendar.current.component(.weekday, from: day) - 1]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if !isOral { siteSection }
                noteField
                doseWordRow
                actions
                privacyLine
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.bgPrimary)
        .onAppear {
            load()
            #if DEBUG
            // v24 film door — the mark ceremony self-drives for
            // the camera (sheet rise → a beat → the mark → the
            // pen-tick → dismissal → the row's compression).
            if ProcessInfo.processInfo.arguments.contains("--uitest-walk-medication"),
               !isTaken {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) { mark() }
            }
            #endif
        }
    }

    // MARK: header

    @ViewBuilder
    private var header: some View {
        if let factsLine {
            Text(factsLine.uppercased())
                .font(Typo.eyebrow)
                .kerning(1.4)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, Space.xl)
                .accessibilityLabel(factsLine)
        }

        Text(titleWord)
            .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, factsLine == nil ? Space.xl : 6)

        if isTaken, let takenAt = event?.takenAt {
            Text("taken · \(takenAt.formatted(date: .omitted, time: .shortened).lowercased())")
                .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
                .foregroundStyle(Palette.cocoaSecondary)
                .padding(.top, 4)
        } else if isLate {
            Text("still open from \(slotWeekdayWord). log it late, or let it go.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 4)

            // p53 — WHEN did it actually happen? A forgotten log and
            // a late take are different truths, and the cycle counts
            // from the real one.
            whenTakenChips
                .padding(.top, Space.sm)

            // v25 E2 (B3/B4) — a late dose meets FACTS, not silence:
            // the label's own rule, attributed and routed. Never a
            // computed catch-up, never "take it now".
            labelFactsCard
                .padding(.top, Space.md)
        }

        if isCareTeam {
            Text("assigned by your care team. you record what you took.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, 4)
        }

        if isOral, emptyStomach, !isTaken {
            Text("water only, then a quiet half hour before food.")
                .font(Typo.body)
                .foregroundStyle(Palette.cocoaSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
        }
    }

    private var titleWord: String {
        if isTaken { return "\(isLate ? slotWeekdayWord + "'s" : "today's") \(doseNoun)" }
        if isLate { return "\(slotWeekdayWord)'s \(doseNoun)" }
        return "today's \(doseNoun)"
    }

    /// The label's rule lines (MedicationCatalog.lateFactLines):
    /// rule + optional interruption in body ink, attribution +
    /// routing quieter beneath — a hairline card in the clinical
    /// register, zero ornament.
    private var labelFactsCard: some View {
        let lines = MedicationCatalog.lateFactLines(
            productId: plan?.productId,
            consecutiveMissed: consecutiveMissed
        )
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                let quiet = line == MedicationLabelFacts.routingLine
                    || line.hasPrefix("from the ")
                Text(line)
                    .font(quiet ? Typo.caption : Typo.body)
                    .foregroundStyle(
                        quiet ? Palette.cocoaTertiary : Palette.cocoaSecondary
                    )
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                .stroke(Palette.hairlineCocoa, lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
    }

    /// p53 — the honest "when" set for a late mark: just now (she
    /// took it late, default), the slot's own day (she took it on
    /// time and forgot to log), yesterday (when distinct from both).
    private var whenTakenOptions: [(key: String?, word: String)] {
        var options: [(String?, String)] = [(nil, "took it just now")]
        let todayKey = TodayStateService.dayKey()
        let yesterdayKey = Calendar.current.date(
            byAdding: .day, value: -1, to: .now
        ).map { MedicationScheduleEngine.dayKey(for: $0) }
        if let yesterdayKey, yesterdayKey != slotDayKey, yesterdayKey != todayKey {
            options.append((yesterdayKey, "yesterday"))
        }
        options.append((slotDayKey, "on \(slotWeekdayWord), forgot to log"))
        return options
    }

    @ViewBuilder
    private var whenTakenChips: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(whenTakenOptions, id: \.word) { option in
                let selected = lateTakeDayKey == option.key
                Button {
                    JeniHaptic.tick()
                    withAnimation(JeniMotion.press) { lateTakeDayKey = option.key }
                } label: {
                    Text(option.word)
                        .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(selected ? Palette.textInverse : Palette.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(selected ? Palette.textPrimary : Palette.bgElevated)
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                selected ? Color.clear : Palette.hairlineCocoa, lineWidth: 1
                            )
                        )
                }
                .buttonStyle(JKPress())
            }
        }
        .accessibilityLabel("when did you take it")
    }

    /// The instant a late mark records: the chosen day at her usual
    /// hour, or now.
    private var lateTakenAt: Date {
        guard let key = lateTakeDayKey,
              let day = MedicationScheduleEngine.parseDayKey(key, calendar: .current),
              let plan
        else { return .now }
        let facts = RegimenService.facts(for: plan)
        return MedicationScheduleEngine.scheduledAt(onDay: day, facts: facts)
    }

    // MARK: the dose word (p53 — what THIS shot was, when it differed)

    @ViewBuilder
    private var doseWordRow: some View {
        if editingDoseWord {
            HStack(spacing: 8) {
                Text("this \(doseNoun) —")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                TextField(
                    factsLine.map { _ in "\(planDoseWord ?? "the usual")" } ?? "how much",
                    text: $doseWordDraft
                )
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .keyboardType(.decimalPad)
                .onSubmit(persistDoseWordIfTaken)
            }
            .padding(.top, Space.sm)
            Rectangle()
                .fill(Palette.hairlineCocoa)
                .frame(height: 0.5)
                .padding(.top, 6)
        } else {
            Button {
                JeniHaptic.tick()
                withAnimation(JeniMotion.settle) { editingDoseWord = true }
            } label: {
                Text(
                    event?.doseLabel.map { "this \(doseNoun) — \($0) \(plan?.strengthUnit ?? "mg")" }
                        ?? "different amount this time?"
                )
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .underline()
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.sm)
        }
    }

    private var planDoseWord: String? {
        guard let value = plan?.strengthValue else { return nil }
        return "\(MedicationProduct.doseWord(value)) \(plan?.strengthUnit ?? "mg")"
    }

    /// Her typed word, trimmed; nil when empty or identical to the
    /// plan's own dose (the era label already speaks then).
    private var doseWordToRecord: String? {
        let trimmed = doseWordDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let value = plan?.strengthValue,
           trimmed == MedicationProduct.doseWord(value) { return nil }
        return trimmed
    }

    private func persistDoseWordIfTaken() {
        guard isTaken else { return }
        MedicationLog.resolve(
            .taken(site: pickedSite, note: note.isEmpty ? nil : note,
                   at: event?.takenAt ?? .now),
            slotDayKey: slotDayKey, source: .sheet,
            doseLabel: doseWordToRecord,
            userId: userId, in: modelContext
        )
        reloadEvent()
    }

    // MARK: the site (injection only)

    private static let siteRows: [[InjectionSite]] = [
        [.leftAbdomen, .rightAbdomen],
        [.leftThigh, .rightThigh],
        [.leftArm, .rightArm],
    ]

    @ViewBuilder
    private var siteSection: some View {
        Text("the site")
            .font(Typo.eyebrow)
            .kerning(1.4)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)

        VStack(spacing: 8) {
            ForEach(0..<3) { rowIndex in
                HStack(spacing: 8) {
                    ForEach(Self.siteRows[rowIndex]) { site in
                        siteCell(site)
                    }
                }
            }
        }
        .padding(.top, Space.sm)

        if let rotationLine {
            Text(rotationLine)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
        }
    }

    private func siteCell(_ site: InjectionSite) -> some View {
        let isPicked = pickedSite == site
        let isSuggested = suggestedSite == site && pickedSite == nil
        return Button {
            JeniHaptic.tick()
            withAnimation(JeniMotion.press) {
                pickedSite = isPicked ? nil : site
            }
            // Editing a recorded dose updates the site in place.
            if isTaken {
                MedicationLog.resolve(
                    .taken(site: pickedSite, note: note.isEmpty ? nil : note,
                           at: event?.takenAt ?? .now),
                    slotDayKey: slotDayKey, source: .sheet,
                    userId: userId, in: modelContext
                )
                reloadEvent()
            }
        } label: {
            Text(site.word)
                .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(isPicked ? Palette.textInverse : Palette.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .fill(isPicked ? Palette.textPrimary : Palette.bgElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.chip, style: .continuous)
                        .stroke(
                            isPicked
                                ? Color.clear
                                : Palette.textPrimary.opacity(isSuggested ? 0.45 : 0.10),
                            lineWidth: isSuggested ? 1.0 : 0.5
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(
            site.word + (isSuggested ? ", suggested next" : "")
        )
        .accessibilityAddTraits(isPicked ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: note

    @ViewBuilder
    private var noteField: some View {
        TextField("anything to note", text: $note, axis: .vertical)
            .font(Typo.body)
            .foregroundStyle(Palette.textPrimary)
            .lineLimit(1...3)
            .padding(.top, Space.lg)
            .onSubmit(persistNoteIfTaken)
        Rectangle()
            .fill(Palette.hairlineCocoa)
            .frame(height: 0.5)
            .padding(.top, 6)
    }

    // MARK: actions

    @ViewBuilder
    private var actions: some View {
        if isTaken {
            // v25 E2 — the symptom logger reaches the moment it
            // belongs to (it was buried two levels under settings):
            // the mark is done, the week just closed, "how it's
            // sitting" is one tap away. Food noise lives here too.
            Button {
                JeniHaptic.tick()
                showSideEffects = true
            } label: {
                HStack {
                    Text("how it's sitting")
                        .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.md)
            .accessibilityLabel("how it's sitting. log a side effect.")
            .jeniSheet(isPresented: $showSideEffects) {
                SideEffectSheet(userId: userId, onDone: { showSideEffects = false })
            }

            Button {
                Haptics.soft()
                MedicationLog.resolve(
                    .unmark, slotDayKey: slotDayKey, source: .sheet,
                    userId: userId, in: modelContext
                )
                onDone()
            } label: {
                Text("didn't, actually")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .underline()
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.lg)
        } else {
            Button {
                mark()
            } label: {
                Text(justMarked ? "taken" : "mark it taken")
                    .font(.custom("DMSans-SemiBold", size: 17, relativeTo: .body))
                    .contentTransition(.opacity)
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                            .fill(Palette.textPrimary)
                    )
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.lg)
            .accessibilityLabel("mark today's \(doseNoun) taken")

            if showSkipReasons {
                skipReasons
            } else {
                Button {
                    withAnimation(JeniMotion.settle) { showSkipReasons = true }
                    JeniHaptic.tick()
                } label: {
                    Text(isLate ? "let it go" : "not today")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .underline()
                }
                .buttonStyle(JKPress())
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
            }
        }
    }

    private static let skipChoices: [(key: String, word: String)] = [
        ("traveling", "traveling"),
        ("out_of_medication", "out of medication"),
        ("clinician_paused", "paused by my clinician"),
        ("just_didnt", "just didn't"),
    ]

    @ViewBuilder
    private var skipReasons: some View {
        Text(isLate ? "let it go. a reason, if you want one." : "skipping. a reason, if you want one.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)

        VStack(spacing: 6) {
            ForEach(Self.skipChoices, id: \.key) { choice in
                skipRow(choice.key, choice.word)
            }
            skipRow(nil, "skip without a reason")
        }
        .padding(.top, 6)
    }

    private func skipRow(_ key: String?, _ word: String) -> some View {
        Button {
            Haptics.soft()
            MedicationLog.resolve(
                .skipped(reason: key), slotDayKey: slotDayKey,
                source: .sheet, userId: userId, in: modelContext
            )
            onDone()
        } label: {
            HStack {
                Text(word)
                    .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary.opacity(key == nil ? 0.6 : 1))
                Spacer()
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(key == nil ? "skip without a reason" : "skip, \(word)")
    }

    // MARK: privacy

    private var privacyLine: some View {
        Text("only you see this. never named in notifications.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
    }

    // MARK: mutations

    private func load() {
        plan = RegimenService.activeMedicationPlan(userId: userId, in: modelContext)
        reloadEvent()
        // v25 E2 — the interruption line renders only when HER
        // record shows ≥2 consecutive unresolved slots BEFORE this
        // one (fact selection from the record, never a guess).
        if let plan {
            let facts = RegimenService.facts(for: plan)
            let events = DoseEventStore.slotEvents(
                userId: userId, limit: 40, in: modelContext
            )
            let slots = MedicationScheduleEngine.slotDays(
                through: .now, lookbackDays: 35, facts: facts, events: events
            )
            var run = 0
            for slot in slots.reversed() {
                let key = MedicationScheduleEngine.dayKey(for: slot)
                guard key < slotDayKey else { continue }
                let resolved = events.contains {
                    $0.dayKey == key && $0.isResolved
                }
                if resolved { break }
                run += 1
            }
            consecutiveMissed = run
        }
        let recent = DoseEventStore.recentSites(userId: userId, in: modelContext)
        let suggestion = SiteRotationAdvisor.suggestion(recent: recent)
        suggestedSite = suggestion
        rotationLine = SiteRotationAdvisor.line(recent: recent, suggested: suggestion)
        if let existing = event {
            pickedSite = existing.site.flatMap(InjectionSite.init(rawValue:))
            note = existing.note ?? ""
            doseWordDraft = existing.doseLabel ?? ""
        } else if plan?.route != "oral" {
            // The rotation's suggestion arrives PRE-SELECTED (a
            // filled cell she sees before marking) — recording it
            // is her confirmation, never a fabrication. Tapping it
            // again clears it; a site-less mark stays valid.
            pickedSite = suggestion
        }
    }

    private func reloadEvent() {
        event = DoseEventStore.event(
            dayKey: slotDayKey, userId: userId, in: modelContext
        )
    }

    private func mark() {
        // Only what is VISIBLY chosen records — pickedSite is
        // filled on screen (pre-selected by rotation or tapped by
        // her); nil records a site-less mark, honestly.
        let site: InjectionSite? = isOral ? nil : pickedSite
        // p58 — a dose entering the record is the product's most
        // consequential daily commit; it speaks `record`, the same
        // hand as a weight save and a filed plate.
        JeniHaptic.record()
        withAnimation(JeniMotion.settle) { justMarked = true }
        MedicationLog.resolve(
            .taken(
                site: site, note: note.isEmpty ? nil : note,
                at: isLate ? lateTakenAt : .now
            ),
            slotDayKey: slotDayKey, source: .sheet,
            doseLabel: doseWordToRecord,
            userId: userId, in: modelContext
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + JeniMotion.commitDwell) { onDone() }
    }

    private func persistNoteIfTaken() {
        guard isTaken else { return }
        MedicationLog.resolve(
            .taken(site: pickedSite, note: note.isEmpty ? nil : note,
                   at: event?.takenAt ?? .now),
            slotDayKey: slotDayKey, source: .sheet,
            userId: userId, in: modelContext
        )
        reloadEvent()
    }
}
