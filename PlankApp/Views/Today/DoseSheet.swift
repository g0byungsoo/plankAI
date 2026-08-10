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
        let recent = DoseEventStore.recentSites(userId: userId, in: modelContext)
        let suggestion = SiteRotationAdvisor.suggestion(recent: recent)
        suggestedSite = suggestion
        rotationLine = SiteRotationAdvisor.line(recent: recent, suggested: suggestion)
        if let existing = event {
            pickedSite = existing.site.flatMap(InjectionSite.init(rawValue:))
            note = existing.note ?? ""
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
        JeniHaptic.land()
        withAnimation(JeniMotion.settle) { justMarked = true }
        MedicationLog.resolve(
            .taken(site: site, note: note.isEmpty ? nil : note, at: .now),
            slotDayKey: slotDayKey, source: .sheet,
            userId: userId, in: modelContext
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { onDone() }
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
