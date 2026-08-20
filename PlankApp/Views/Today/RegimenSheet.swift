import SwiftUI
import SwiftData
import PlankSync

// MARK: - RegimenSheet — THE REGIMEN home (app v24)
//
// Her medication's home, reached from settings ("your medication")
// and the row's long-press. v8 gave it one field (the shot day);
// v24 makes it the full quiet ledger:
//   · the current facts (medication · dose · rhythm · reminder),
//     each a door to its editor — every save is a VERSION through
//     applySelfRegimen; history is never overwritten,
//   · the record (era rows from the version chain),
//   · pause / stop (reasons recorded, chain intact),
//   · the empty state: "add your medication" walks the editors
//     once (the founder's later-enable path for B2C).
// The care-team face stays read-only with the correction door
// (164.526 shape) — only reminders remain hers there.
// Clinical register throughout: ink, hairlines, no rose, no
// celebration. Names render here (she reads it); never in
// notifications, never in analytics.

struct RegimenSheet: View {
    let userId: String
    let onDone: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var plan: RegimenPlanRecord?
    @State private var history: [RegimenPlanRecord] = []
    @State private var page: Page = .overview
    @State private var wizard = false
    @State private var customDose: String = ""
    @State private var customName: String = ""
    @State private var showCorrection = false
    @State private var showEndChoices = false
    @State private var showSideEffects = false
    // v25 §36 — the two past-record repairs. A slot opens THE DOSE
    // SHEET on its own day; a symptom day opens the logger on its own
    // day. Both are `Identifiable` wrappers because `.sheet(item:)`
    // needs one and a bare `String` is not.
    @State private var editingSlot: SlotRef?
    @State private var editingSymptomDay: SlotRef?

    /// A day key, made presentable.
    private struct SlotRef: Identifiable, Equatable { let id: String }

    private enum Page: Equatable {
        case overview, editMedication, editDose, editDay, editHour, editStart
    }

    // p53 — the rhythm editor's drafts (an interval commits once,
    // never per stepper tick) + the tenure editor's month wheel +
    // the past-shot picker.
    @State private var intervalDraftN = 7
    @State private var showIntervalControls = false
    @State private var showSecondDayPicker = false
    @State private var backfillPicking = false
    @State private var startDraftYear = Calendar.current.component(.year, from: .now)
    @State private var startDraftMonth = Calendar.current.component(.month, from: .now)

    private static let weekdays: [(iso: Int, word: String)] = [
        (1, "monday"), (2, "tuesday"), (3, "wednesday"), (4, "thursday"),
        (5, "friday"), (6, "saturday"), (7, "sunday"),
    ]

    private var isCareTeam: Bool {
        plan.map(RegimenService.isManagedByCareTeam) ?? false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                switch page {
                case .overview:
                    if isCareTeam, let plan {
                        careTeamFace(plan)
                    } else if plan != nil {
                        overview
                    } else {
                        emptyFace
                    }
                case .editMedication: medicationEditor
                case .editDose: doseEditor
                case .editDay: dayEditor
                case .editHour: hourEditor
                case .editStart: startEditor
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
            .animation(JeniMotion.settle, value: page)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.bgPrimary)
        .onAppear {
            reload()
            #if DEBUG
            // p53 film door — the editors, framed without taps (the
            // sim's recorded walker limitation; the write chokepoint
            // is unit-proven, the frames are what film needs).
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "--uitest-regimen-page"),
               idx + 1 < args.count {
                switch args[idx + 1] {
                case "day":
                    page = .editDay
                    showIntervalControls = true
                case "split":
                    page = .editDay
                    showSecondDayPicker = true
                case "start":
                    page = .editStart
                case "backfill":
                    backfillPicking = true
                default: break
                }
            }
            #endif
        }
        .sheet(isPresented: $showCorrection) {
            if let plan {
                CorrectionSheet(userId: userId, plan: plan, onDone: { showCorrection = false })
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                    .presentationBackground(Palette.bgPrimary)
            }
        }
        .sheet(isPresented: $showSideEffects) {
            SideEffectSheet(userId: userId, onDone: { showSideEffects = false })
                .presentationDetents(JeniSheetHeight.tall)
                .presentationDragIndicator(.visible)
                .presentationBackground(Palette.bgPrimary)
                .presentationCornerRadius(28)
        }
        // v25 §36 — a row in `the doses` opens THE DOSE SHEET on its own
        // slot. No new editor: `DoseSheet` has taken a `slotDayKey`
        // since v24 and already carries the whole past-slot face (the
        // day's own title, the taken record with its time, the site
        // still editable, `didn't, actually`, the skip reasons). What
        // was missing was a tap target — the ledger `33` built listed
        // her shots and could not be touched, which is the same
        // write-only defect the list itself was written to close.
        .sheet(item: $editingSlot) { slot in
            DoseSheet(
                userId: userId,
                slotDayKey: slot.id,
                onDone: { editingSlot = nil; reload() }
            )
            .presentationDetents(JeniSheetHeight.tall)
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)
        }
        .sheet(item: $editingSymptomDay) { day in
            SideEffectSheet(
                userId: userId,
                initialDayKey: day.id,
                onDone: { editingSymptomDay = nil; reload() }
            )
            .presentationDetents(JeniSheetHeight.tall)
            .presentationDragIndicator(.visible)
            .presentationBackground(Palette.bgPrimary)
            .presentationCornerRadius(28)
        }
    }

    private func reload() {
        plan = RegimenService.activeMedicationPlan(userId: userId, in: modelContext)
        history = RegimenService.medicationHistory(userId: userId, in: modelContext)
    }

    private func apply(_ mutate: (inout RegimenService.SelfRegimenSpec) -> Void) {
        var spec = plan.map(RegimenService.spec(from:))
            ?? RegimenService.SelfRegimenSpec()
        mutate(&spec)
        _ = RegimenService.applySelfRegimen(spec, userId: userId, in: modelContext)
        reload()
        let uid = userId
        let context = modelContext
        Task { await MedicationReminders.refresh(userId: uid, in: context) }
    }

    private func advance(after edited: Page) {
        guard wizard else {
            withAnimation(JeniMotion.settle) { page = .overview }
            return
        }
        let isDaily = plan?.scheduleRule == "daily"
        withAnimation(JeniMotion.settle) {
            switch edited {
            case .editMedication: page = .editDose
            case .editDose: page = isDaily ? .editHour : .editDay
            case .editDay: page = .editHour
            case .editHour: page = .overview; wizard = false
            case .editStart: page = .overview
            case .overview: break
            }
        }
    }

    // MARK: overview (self)

    @ViewBuilder
    private var overview: some View {
        title("your medication")

        VStack(spacing: 0) {
            door("medication", renderName) { page = .editMedication }
            door("dose", doseWordLine ?? "set it") { page = .editDose }
            if plan?.scheduleRule != "daily" {
                door("rhythm", rhythmLine) { page = .editDay }
            } else {
                factRow("rhythm", rhythmLine)
            }
            door("reminder", reminderLine) { page = .editHour }
            // p53 — treatment tenure: jeni day is not treatment day.
            // One editable biographical fact; asked never demanded.
            door("on it since", tenureLine) {
                if let key = plan?.treatmentStartedOn,
                   let date = MedicationScheduleEngine.parseDayKey(key, calendar: .current) {
                    startDraftYear = Calendar.current.component(.year, from: date)
                    startDraftMonth = Calendar.current.component(.month, from: date)
                }
                page = .editStart
            }
        }
        .padding(.top, Space.lg)

        if let next = nextDoseLine {
            Text(next)
                .font(.custom("JeniHeroSerif-Italic", size: 15, relativeTo: .subheadline))
                .foregroundStyle(Palette.cocoaSecondary)
                .padding(.top, 10)
        }

        Button {
            JeniHaptic.tick()
            showSideEffects = true
        } label: {
            HStack {
                Text("how it's sitting")
                    .font(.custom("JeniHeroSerif-Regular", size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                Text("log a side effect")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.sm)
        .accessibilityLabel("how it's sitting. log a side effect.")

        doseLogSection

        // What she did → how it sat → what changed. The two record
        // lists sit together; the era chain (the rarer question) stays
        // last, which is the order `33` established.
        symptomLogSection

        if history.count > 0 {
            recordSection
        }

        if showEndChoices {
            endChoices
        } else {
            Button {
                withAnimation(JeniMotion.settle) { showEndChoices = true }
                JeniHaptic.tick()
            } label: {
                Text("not taking it right now")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .underline()
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.lg)
        }

        privacyLine
    }

    @ViewBuilder
    private var endChoices: some View {
        Text("paused, or stopped for good? the record stays either way.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.lg)
        HStack(spacing: 10) {
            endChip("paused for now", reason: "paused")
            endChip("stopped", reason: "ended")
        }
        .padding(.top, 8)
    }

    private func endChip(_ word: String, reason: String) -> some View {
        Button {
            Haptics.soft()
            RegimenService.endMedicationPlan(userId: userId, reason: reason, in: modelContext)
            let uid = userId
            let context = modelContext
            Task { await MedicationReminders.refresh(userId: uid, in: context) }
            onDone()
        } label: {
            Text(word)
                .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
                .foregroundStyle(Palette.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .overlay(
                    Capsule().stroke(Palette.textPrimary.opacity(0.25), lineWidth: 0.5)
                )
        }
        .buttonStyle(JKPress())
    }

    // MARK: the doses (v25 §33 — the shot log)
    //
    // "the record" below states her plan's ERAS. This states the SHOTS.
    // They are different questions and they were collapsed into one
    // heading that only answered the rarer of the two: `DoseEventRecord`
    // has held the day, the status and the site since v24 and no screen
    // had ever listed them.
    //
    // Boring on purpose (the brief's §14): a day, a dose, a site. No
    // adherence percentage, no streak, no "you missed one", no pattern
    // and no link to a symptom or a weight — the ledger reports, the
    // pattern engine (which is floor-gated and cited) is the only thing
    // in this product allowed to observe.

    private var doseRows: [DoseLedger.Row] {
        DoseLedger.rows(doseEntries)
    }

    /// Flattened from the events + the regimen VERSION in force for
    /// each slot, so a row shows the dose she was actually on that
    /// week — not today's dose printed over her history.
    private var doseEntries: [DoseLedger.Entry] {
        let versions = history
        return DoseEventStore.events(userId: userId, in: modelContext).map { event in
            let version = versions.first(where: { $0.id == event.regimenPlanId })
            // p53 — HER word for THIS shot outranks the era's label
            // (the record keeps what happened; the version keeps the
            // plan).
            let doseWord = event.doseLabel.map {
                "\($0) \(version?.strengthUnit ?? "mg")"
            } ?? version?.strengthValue.map {
                "\(MedicationProduct.doseWord($0)) \(version?.strengthUnit ?? "mg")"
            }
            return DoseLedger.Entry(
                dayKey: event.dayKey,
                status: event.status,
                takenAt: event.takenAt,
                site: event.site,
                doseWord: doseWord,
                skipReason: event.skipReason
            )
        }
    }

    @ViewBuilder
    private var doseLogSection: some View {
        let rows = doseRows
        if !rows.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text("the doses")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: Space.md)
                Text(rows.count == 1 ? "1 on file" : "\(rows.count) on file")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .monospacedDigit()
            }
            .padding(.top, Space.sectionGap)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Button {
                        JeniHaptic.tick()
                        editingSlot = SlotRef(id: row.dayKey)
                    } label: {
                        VStack(spacing: 0) {
                            doseRowBody(row)
                                .padding(.vertical, 9)
                            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.voiceOver)
                    .accessibilityHint("double-tap to fix this one")
                }
            }
            .padding(.top, 6)

            Text("tap any of these to fix the site, the status, or take it back.")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, Space.sm)
        }

        // p53 — history that predates jeni belongs in the record
        // too. The picker hands the day to the SAME dose sheet every
        // slot uses; no second editor exists.
        if backfillPicking {
            Text("a past shot · which day?")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.top, Space.sm)
            backfillDayGrid
        } else {
            Button {
                JeniHaptic.tick()
                withAnimation(JeniMotion.settle) { backfillPicking = true }
            } label: {
                Text("+ add a past shot")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .underline()
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.sm)
        }
    }

    /// p53 — the last 14 days that hold no dose row yet, newest
    /// first. Fourteen back mirrors the food record's re-dating law.
    @ViewBuilder
    private var backfillDayGrid: some View {
        let cal = Calendar.current
        let recorded = Set(doseRows.map(\.dayKey))
        let days: [(key: String, word: String)] = (1...14).compactMap { back in
            guard let day = cal.date(byAdding: .day, value: -back, to: .now)
            else { return nil }
            let key = MedicationScheduleEngine.dayKey(for: day)
            guard !recorded.contains(key) else { return nil }
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = back <= 6 ? "EEEE" : "MMM d"
            let word = back == 1 ? "yesterday" : f.string(from: day).lowercased()
            return (key, word)
        }
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(days, id: \.key) { day in
                Button {
                    JeniHaptic.tick()
                    backfillPicking = false
                    editingSlot = SlotRef(id: day.key)
                } label: {
                    Text(day.word)
                        .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Palette.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 1)
                        )
                }
                .buttonStyle(JKPress())
            }
        }
        .padding(.top, 4)
    }

    // MARK: the symptoms (v25 §36 — how it sat, listed)
    //
    // The third instance of one shape. `33` gave the SHOTS a list;
    // `34` gave the WEIGH-INS a list; this gives the SYMPTOMS one.
    //
    // `ObservationRecord` has carried a day, a symptom and a severity
    // since v24. Five readers consume them — including `VisitPacket`,
    // which prints them for a clinician — and the only surface that
    // showed them to HER was the chip cloud, filtered to today. The
    // product would tell her doctor what she recorded three weeks ago
    // and would not tell her.
    //
    // Same refusals as its two siblings: no count of bad days, no
    // "worse than last week", no severity arithmetic, no streak, no
    // link to a dose or a weight. It reports.

    private var symptomRows: [SymptomLedger.Row] {
        SymptomLedger.rows(
            SideEffectLog.entries(userId: userId, limit: 400, in: modelContext)
                .map {
                    SymptomLedger.Entry(
                        dayKey: $0.dayKey,
                        word: $0.symptom.word,
                        severityWord: $0.severity.word
                    )
                }
        )
    }

    @ViewBuilder
    private var symptomLogSection: some View {
        let rows = symptomRows
        if !rows.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                Text("the symptoms")
                    .font(Typo.eyebrow)
                    .kerning(1.4)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: Space.md)
                Text(rows.count == 1 ? "1 day on file" : "\(rows.count) days on file")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .monospacedDigit()
            }
            .padding(.top, Space.sectionGap)

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    Button {
                        JeniHaptic.tick()
                        editingSymptomDay = SlotRef(id: row.dayKey)
                    } label: {
                        VStack(spacing: 0) {
                            symptomRowBody(row)
                                .padding(.vertical, 9)
                            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(row.voiceOver)
                    .accessibilityHint("double-tap to change that day")
                }
            }
            .padding(.top, 6)
        }
    }

    @ViewBuilder
    private func symptomRowBody(_ row: SymptomLedger.Row) -> some View {
        let day = Text(row.day)
            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
            .foregroundStyle(Palette.textPrimary)
            .monospacedDigit()
        let detail = Text(row.detail)
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaSecondary)
        // The same AX5 rule the dose rows, the era rows and THE BOOK's
        // ledger use: from xxxLarge the pair stacks, so no word ever
        // wraps inside itself (`33`'s `medica/tion ozem/pic` law).
        if stacksForType {
            VStack(alignment: .leading, spacing: 2) {
                day.fixedSize(horizontal: false, vertical: true)
                detail
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                day
                Spacer(minLength: Space.md)
                detail
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func doseRowBody(_ row: DoseLedger.Row) -> some View {
        let day = Text(row.day)
            .font(.custom("DMSans-Medium", size: 14, relativeTo: .subheadline))
            .foregroundStyle(
                row.isMuted ? Palette.textPrimary.opacity(0.5) : Palette.textPrimary
            )
            .monospacedDigit()
        let detail = Text(row.detail)
            .font(Typo.caption)
            .foregroundStyle(row.isMuted ? Palette.cocoaTertiary : Palette.cocoaSecondary)
        if stacksForType {
            VStack(alignment: .leading, spacing: 2) {
                day.fixedSize(horizontal: false, vertical: true)
                detail
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                day
                Spacer(minLength: Space.md)
                detail
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: the record

    /// Renamed from "the record" (v24) now that the SHOTS have their own
    /// heading above it. Two lists under one word called "the record"
    /// answered the rarer question and hid the common one; each says
    /// what it is now.
    @ViewBuilder
    private var recordSection: some View {
        Text("dose changes")
            .font(Typo.eyebrow)
            .kerning(1.4)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.sectionGap)

        VStack(spacing: 0) {
            ForEach(history, id: \.id) { version in
                eraRow(version)
            }
        }
        .padding(.top, 6)
    }

    private func eraRow(_ version: RegimenPlanRecord) -> some View {
        let name = MedicationCatalog.renderName(
            productId: version.productId, displayName: version.displayName
        )
        let dose = version.strengthValue.map {
            "\(MedicationProduct.doseWord($0)) \(version.strengthUnit ?? "mg")"
        }
        let lead = [name == "your medication" ? nil : name, dose]
            .compactMap { $0 }.joined(separator: " · ")
        let leadText = Text(lead.isEmpty ? "your medication" : lead)
            .font(.custom("JeniHeroSerif-Regular", size: 15, relativeTo: .subheadline))
            .foregroundStyle(
                version.endedAt == nil
                    ? Palette.textPrimary : Palette.textPrimary.opacity(0.55)
            )
        let span = Text(eraSpanWord(version))
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
        return VStack(spacing: 0) {
            Group {
                if stacksForType {
                    VStack(alignment: .leading, spacing: 2) {
                        leadText.fixedSize(horizontal: false, vertical: true)
                        span.fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        leadText
                        Spacer()
                        span
                    }
                }
            }
            .padding(.vertical, 9)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private func eraSpanWord(_ version: RegimenPlanRecord) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        let start = f.string(from: version.startedAt).lowercased()
        guard let ended = version.endedAt else { return "since \(start)" }
        let end = f.string(from: ended).lowercased()
        switch version.endReason {
        case "paused": return "\(start) – \(end) · paused"
        case "ended": return "\(start) – \(end) · stopped"
        default: return "\(start) – \(end)"
        }
    }

    // MARK: empty face (B2C later-enable)

    @ViewBuilder
    private var emptyFace: some View {
        title("your medication")

        Text("add it when you're ready. your days shape themselves around it, and everything stays yours.")
            .font(Typo.body)
            .foregroundStyle(Palette.cocoaSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 6)

        if history.count > 0 {
            recordSection
            Button {
                wizard = true
                withAnimation(JeniMotion.settle) { page = .editMedication }
                JeniHaptic.tick()
            } label: {
                Text("starting again? set it up")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaSecondary)
                    .underline()
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.lg)
        } else {
            Button {
                wizard = true
                withAnimation(JeniMotion.settle) { page = .editMedication }
                JeniHaptic.tick()
            } label: {
                Text("add your medication")
                    .font(.custom("DMSans-SemiBold", size: 16, relativeTo: .body))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                            .fill(Palette.textPrimary)
                    )
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.lg)
        }

        privacyLine
    }

    // MARK: editors

    @ViewBuilder
    private var medicationEditor: some View {
        editorHeader("which one?")

        VStack(spacing: 0) {
            ForEach(MedicationCatalog.products) { product in
                optionLine(
                    product.displayName,
                    selected: plan?.productId == product.id,
                    detail: product.route == .oral ? "pill" : nil
                ) {
                    apply { spec in
                        let compoundChanged =
                            MedicationCatalog.product(id: spec.productId)?.compound != product.compound
                        spec.productId = product.id
                        spec.displayName = product.displayName
                        spec.route = product.route.rawValue
                        spec.scheduleRule = product.defaultCadence.scheduleRule
                        if product.defaultCadence == .daily { spec.anchorWeekday = nil }
                        // A different compound invalidates the old
                        // dose — never carry 0.5 into a 2.5 world.
                        if compoundChanged { spec.doseValue = nil; spec.doseUnit = nil }
                    }
                    advance(after: .editMedication)
                }
            }
        }
        .padding(.top, Space.sm)

        Text("something else?")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)
        HStack(spacing: 10) {
            TextField("its name, your words", text: $customName)
                .font(Typo.body)
                .foregroundStyle(Palette.textPrimary)
                .textInputAutocapitalization(.never)
            Button {
                let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                apply { spec in
                    spec.productId = nil
                    spec.displayName = trimmed
                }
                customName = ""
                advance(after: .editMedication)
            } label: {
                Text("keep")
                    .font(Typo.caption)
                    .foregroundStyle(
                        customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Palette.cocoaTertiary : Palette.textPrimary
                    )
                    .underline()
            }
            .buttonStyle(JKPress())
        }
        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5).padding(.top, 6)

        backLine
    }

    @ViewBuilder
    private var doseEditor: some View {
        editorHeader("your current dose.")

        let ladder = MedicationCatalog.product(id: plan?.productId)?.doseLadder ?? []
        let unit = MedicationCatalog.product(id: plan?.productId)?.doseUnit ?? "mg"
        if !ladder.isEmpty {
            VStack(spacing: 0) {
                ForEach(ladder, id: \.self) { value in
                    optionLine(
                        "\(MedicationProduct.doseWord(value)) \(unit)",
                        selected: plan?.strengthValue == value
                    ) {
                        apply { $0.doseValue = value; $0.doseUnit = unit }
                        advance(after: .editDose)
                    }
                }
            }
            .padding(.top, Space.sm)
        }

        Text(ladder.isEmpty ? "your dose, in \(unit)" : "or a custom one")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)
        HStack(spacing: 10) {
            TextField("2.5", text: $customDose)
                .font(Typo.body)
                .keyboardType(.decimalPad)
                .foregroundStyle(Palette.textPrimary)
            Text(unit)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
            Button {
                guard let value = Double(customDose), value > 0, value < 100 else { return }
                apply { $0.doseValue = value; $0.doseUnit = unit }
                customDose = ""
                advance(after: .editDose)
            } label: {
                Text("keep")
                    .font(Typo.caption)
                    .foregroundStyle(Double(customDose) == nil ? Palette.cocoaTertiary : Palette.textPrimary)
                    .underline()
            }
            .buttonStyle(JKPress())
        }
        Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5).padding(.top, 6)

        if wizard {
            skipLine("not sure yet") { advance(after: .editDose) }
        }
        backLine
    }

    @ViewBuilder
    private var dayEditor: some View {
        editorHeader("which day is your shot, usually?")

        VStack(spacing: 0) {
            ForEach(Self.weekdays, id: \.iso) { day in
                optionLine(
                    day.word,
                    selected: plan?.scheduleRule == "weeklyAnchor"
                        && plan?.anchorWeekday == day.iso
                        && plan?.secondAnchorWeekday == nil
                ) {
                    apply { spec in
                        spec.scheduleRule = "weeklyAnchor"
                        spec.anchorWeekday = day.iso
                        spec.secondAnchorWeekday = nil
                        spec.intervalDays = nil
                        spec.anchorDayKey = nil
                    }
                    showIntervalControls = false
                    showSecondDayPicker = false
                    advance(after: .editDay)
                }
            }
        }
        .padding(.top, Space.sm)

        // p53 — the rhythms real regimens run on, one quiet layer
        // down. A weekly customer never has to see past this line.
        Text("a different rhythm")
            .font(.custom("DMSans-Medium", size: 12, relativeTo: .caption2))
            .kerning(1.6)
            .textCase(.uppercase)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)

        VStack(spacing: 0) {
            optionLine(
                "twice a week",
                selected: plan?.secondAnchorWeekday != nil
            ) {
                withAnimation(JeniMotion.settle) {
                    showSecondDayPicker.toggle()
                    showIntervalControls = false
                }
            }
            if showSecondDayPicker {
                Text("which two days?")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .padding(.top, 6)
                splitDayGrid
            }
            optionLine(
                "every few days",
                selected: plan?.scheduleRule == "intervalDays"
            ) {
                withAnimation(JeniMotion.settle) {
                    showIntervalControls.toggle()
                    showSecondDayPicker = false
                    if let n = plan?.intervalDays { intervalDraftN = n }
                }
            }
            if showIntervalControls {
                intervalControls
            }
        }
        .padding(.top, 6)

        if wizard {
            skipLine("not settled yet") { advance(after: .editDay) }
        }
        backLine
    }

    /// p53 — the split rhythm: her current shot day plus one more.
    /// Two named weekdays, half the week apart is typical; the
    /// record holds whatever two days she names.
    @ViewBuilder
    private var splitDayGrid: some View {
        let first = plan?.anchorWeekday ?? 1
        VStack(spacing: 0) {
            ForEach(Self.weekdays.filter { $0.iso != first }, id: \.iso) { day in
                optionLine(
                    "\(Self.weekdays.first { $0.iso == first }?.word ?? "")s + \(day.word)s",
                    selected: plan?.secondAnchorWeekday == day.iso
                ) {
                    apply { spec in
                        spec.scheduleRule = "weeklyAnchor"
                        spec.anchorWeekday = min(first, day.iso)
                        spec.secondAnchorWeekday = max(first, day.iso)
                        spec.intervalDays = nil
                        spec.anchorDayKey = nil
                    }
                    showSecondDayPicker = false
                    advance(after: .editDay)
                }
            }
        }
        .padding(.leading, Space.md)
    }

    /// p53 — every N days: a stepper draft plus "when's your next
    /// shot", committed once. The chain then counts N from each
    /// real injection.
    @ViewBuilder
    private var intervalControls: some View {
        HStack(spacing: Space.md) {
            Text("every \(intervalDraftN) days")
                .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
                .foregroundStyle(Palette.textPrimary)
                .monospacedDigit()
            Spacer()
            Stepper(
                "interval days", value: $intervalDraftN, in: 2...90
            )
            .labelsHidden()
        }
        .padding(.vertical, 10)
        .padding(.leading, Space.md)

        Text("when's your next shot?")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.leading, Space.md)

        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        VStack(spacing: 0) {
            ForEach(0..<min(intervalDraftN, 7), id: \.self) { offset in
                let day = cal.date(byAdding: .day, value: offset, to: today) ?? today
                let key = MedicationScheduleEngine.dayKey(for: day)
                let word: String = {
                    if offset == 0 { return "today" }
                    if offset == 1 { return "tomorrow" }
                    let f = DateFormatter()
                    f.locale = Locale(identifier: "en_US_POSIX")
                    f.dateFormat = "EEEE"
                    return f.string(from: day).lowercased()
                }()
                optionLine(
                    word,
                    selected: plan?.scheduleRule == "intervalDays"
                        && plan?.anchorDayKey == key
                        && plan?.intervalDays == intervalDraftN
                ) {
                    apply { spec in
                        spec.scheduleRule = "intervalDays"
                        spec.intervalDays = intervalDraftN
                        spec.anchorDayKey = key
                        spec.anchorWeekday = nil
                        spec.secondAnchorWeekday = nil
                    }
                    showIntervalControls = false
                    advance(after: .editDay)
                }
            }
        }
        .padding(.leading, Space.md)
    }

    /// p53 — treatment tenure: the month treatment actually began.
    /// Roughly is fine; the record never demands a day.
    @ViewBuilder
    private var startEditor: some View {
        editorHeader("when did you start this medication?")

        Text("roughly is fine. jeni speaks to month four differently than day four.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 4)

        HStack(spacing: 0) {
            Picker("month", selection: $startDraftMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text(DateFormatter().monthSymbols[m - 1].lowercased()).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            Picker("year", selection: $startDraftYear) {
                let year = Calendar.current.component(.year, from: .now)
                ForEach((year - 10)...year, id: \.self) { y in
                    Text(String(y)).tag(y)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
        }
        .frame(height: 150)
        .padding(.top, Space.md)

        Button {
            JeniHaptic.tick()
            let key = String(format: "%04d-%02d-01", startDraftYear, startDraftMonth)
            RegimenService.setTreatmentStart(
                civilDay: key, userId: userId, in: modelContext
            )
            reload()
            page = .overview
        } label: {
            Text("keep it")
                .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Capsule().fill(Palette.textPrimary))
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.md)

        if plan?.treatmentStartedOn != nil {
            skipLine("clear it") {
                RegimenService.setTreatmentStart(
                    civilDay: nil, userId: userId, in: modelContext
                )
                reload()
                page = .overview
            }
        }
        backLine
    }

    @ViewBuilder
    private var hourEditor: some View {
        editorHeader("a quiet reminder?")

        Text("one nudge. your medication is never named in it.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 4)

        let choices: [(String, Int?, Bool)] = [
            ("morning", 8 * 60, true),
            ("midday", 12 * 60, true),
            ("evening", 18 * 60, true),
            ("no reminders", nil, false),
        ]
        VStack(spacing: 0) {
            ForEach(choices, id: \.0) { choice in
                let selected = plan.map { p in
                    choice.2
                        ? p.reminderEnabled && p.timeOfDayMinutes == choice.1
                        : !p.reminderEnabled
                } ?? false
                optionLine(choice.0, selected: selected) {
                    apply { spec in
                        spec.reminderEnabled = choice.2
                        if let minutes = choice.1 { spec.timeOfDayMinutes = minutes }
                    }
                    advance(after: .editHour)
                }
            }
        }
        .padding(.top, Space.sm)

        backLine
    }

    // MARK: care-team face (read-only, S4 — unchanged law)

    @ViewBuilder
    private func careTeamFace(_ plan: RegimenPlanRecord) -> some View {
        title("your medication")

        Text("recorded by your care team.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, 4)

        VStack(spacing: 0) {
            factRow("medication", plan.displayName.isEmpty ? "your medication" : plan.displayName)
            if let v = plan.strengthValue {
                factRow("dose", "\(MedicationProduct.doseWord(v)) \(plan.strengthUnit ?? "mg")")
            }
            if let wd = plan.anchorWeekday,
               let word = Self.weekdays.first(where: { $0.iso == wd })?.word {
                factRow("schedule", "weekly · \(word)s")
            }
            if let inst = plan.instruction, !inst.isEmpty {
                factRow("how", inst)
            }
        }
        .padding(.top, Space.lg)

        if history.count > 1 {
            recordSection
        }

        Button {
            Haptics.soft()
            showCorrection = true
        } label: {
            Text("something look wrong?")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
                .underline()
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.lg)

        Text("only you see this. never named in notifications. this is the plan your clinic recorded, not a prescription.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
    }

    // MARK: pieces

    private func title(_ word: String) -> some View {
        Text(word)
            .font(.custom("JeniHeroSerif-Regular", size: 28, relativeTo: .title))
            // Pass 51 (D2) — at AX5 the scaled serif exceeded the
            // sheet's width and SwiftUI broke "medication" mid-word
            // ("your medicatio / n"). Two lines lets the title wrap on
            // the word; the scale floor absorbs the case where a
            // single word still cannot fit a line.
            .lineLimit(2)
            .minimumScaleFactor(0.7)
            .foregroundStyle(Palette.textPrimary)
            .padding(.top, Space.xl)
    }

    @ViewBuilder
    private func editorHeader(_ ask: String) -> some View {
        title("your medication")
        Text(ask)
            .font(.custom("JeniHeroSerif-Italic", size: 17, relativeTo: .body))
            .foregroundStyle(Palette.cocoaSecondary)
            .padding(.top, Space.lg)
    }

    private var backLine: some View {
        Button {
            withAnimation(JeniMotion.settle) { page = .overview; wizard = false }
            JeniHaptic.tick()
        } label: {
            Text("back")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .underline()
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.lg)
        .padding(.bottom, Space.xl)
    }

    private func skipLine(_ word: String, action: @escaping () -> Void) -> some View {
        Button {
            JeniHaptic.tick()
            action()
        } label: {
            Text(word)
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .underline()
        }
        .buttonStyle(JKPress())
        .padding(.top, Space.lg)
    }

    /// A label-and-value row that fits at 17pt does not fit at 53pt.
    ///
    /// FRAME REVIEW, AX5 — this sheet's rows read
    /// `medica/tion  ozem/pic` and `rhyth/m  weekly / . / thursd/ays`:
    /// SwiftUI wrapping INSIDE both the label and the medication name,
    /// which is the `124` → `12`/`4` law happening to words. It is
    /// pre-existing (the helper shipped in v24) and it is this change's
    /// responsibility, because this change is what promoted the sheet
    /// to a full-page destination and added a section to it — a
    /// full-screen conversion must not hand back a bigger broken scroll
    /// (brief §28).
    ///
    /// The rule is the one `HomeNutritionSummary.stacksForType` already
    /// uses: from xxxLarge up, a row becomes a column.
    private var stacksForType: Bool {
        typeSize.isAccessibilitySize || typeSize >= .xxxLarge
    }

    @ViewBuilder
    private func labelValuePair(_ label: String, _ value: String) -> some View {
        let labelText = Text(label)
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
        let valueText = Text(value)
            .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
            .foregroundStyle(Palette.textPrimary)
        if stacksForType {
            VStack(alignment: .leading, spacing: 3) {
                labelText.fixedSize(horizontal: false, vertical: true)
                valueText
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline) {
                labelText
                Spacer()
                valueText.multilineTextAlignment(.trailing)
            }
        }
    }

    private func door(
        _ label: String, _ value: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            JeniHaptic.tick()
            withAnimation(JeniMotion.settle) { action() }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    labelValuePair(label, value)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .padding(.vertical, 11)
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label), \(value)")
        .accessibilityHint("opens the editor")
        .accessibilityAddTraits(.isButton)
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            labelValuePair(label, value)
                .padding(.vertical, 11)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
    }

    private func optionLine(
        _ word: String, selected: Bool, detail: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.soft()
            action()
        } label: {
            VStack(spacing: 0) {
                HStack {
                    Text(word)
                        .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary.opacity(selected ? 1 : 0.8))
                    if let detail {
                        Text(detail)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    Spacer()
                    if selected {
                        Text("now")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                    }
                }
                .padding(.vertical, 10)
                Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.5)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
        .accessibilityLabel(word)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    private var privacyLine: some View {
        Text("only you see this. never named in notifications.")
            .font(Typo.caption)
            .foregroundStyle(Palette.cocoaTertiary)
            .padding(.top, Space.lg)
            .padding(.bottom, Space.xl)
    }

    // MARK: derived words

    private var renderName: String {
        guard let plan else { return "your medication" }
        return MedicationCatalog.renderName(
            productId: plan.productId, displayName: plan.displayName
        )
    }

    private var doseWordLine: String? {
        guard let plan, let value = plan.strengthValue else { return nil }
        return "\(MedicationProduct.doseWord(value)) \(plan.strengthUnit ?? "mg")"
    }

    private var rhythmLine: String {
        guard let plan else { return "" }
        if plan.scheduleRule == "daily" {
            return plan.route == "oral" ? "every morning" : "daily"
        }
        let facts = RegimenService.facts(for: plan)
        switch MedicationScheduleEngine.cadence(facts) {
        case .everyNDays(let n):
            return "every \(n) days"
        case .twiceWeekly(let a, let b):
            let wa = Self.weekdays.first { $0.iso == a }?.word ?? ""
            let wb = Self.weekdays.first { $0.iso == b }?.word ?? ""
            return "\(wa)s + \(wb)s"
        case .weekly(let anchor):
            if let word = Self.weekdays.first(where: { $0.iso == anchor })?.word {
                return "weekly · \(word)s"
            }
            return "weekly · pick a day"
        default:
            return "weekly · pick a day"
        }
    }

    /// p53 — the tenure row's word: "march 2026" or the soft ask.
    private var tenureLine: String {
        guard let key = plan?.treatmentStartedOn,
              let date = MedicationScheduleEngine.parseDayKey(key, calendar: .current)
        else { return "add it, if you like" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMMM yyyy"
        return f.string(from: date).lowercased()
    }

    private var reminderLine: String {
        guard let plan, plan.reminderEnabled else { return "off" }
        let minutes = RegimenService.facts(for: plan).resolvedMinutes
        if minutes < 11 * 60 { return "morning" }
        if minutes < 15 * 60 { return "midday" }
        return "evening"
    }

    private var nextDoseLine: String? {
        guard let plan else { return nil }
        let facts = RegimenService.facts(for: plan)
        let events = DoseEventStore.slotEvents(userId: userId, in: modelContext)
        guard let next = MedicationScheduleEngine.nextDoseDate(
            after: .now, facts: facts, events: events
        ) else { return nil }
        let cal = Calendar.current
        let dayWord: String
        if cal.isDateInToday(next) { dayWord = "today" }
        else if cal.isDateInTomorrow(next) { dayWord = "tomorrow" }
        else {
            let f = DateFormatter()
            f.dateFormat = "EEEE"
            dayWord = f.string(from: next).lowercased()
        }
        let time = next.formatted(date: .omitted, time: .shortened).lowercased()
        return "next dose · \(dayWord), \(time)"
    }
}
