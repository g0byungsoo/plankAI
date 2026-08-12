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
    @State private var plan: RegimenPlanRecord?
    @State private var history: [RegimenPlanRecord] = []
    @State private var page: Page = .overview
    @State private var wizard = false
    @State private var customDose: String = ""
    @State private var customName: String = ""
    @State private var showCorrection = false
    @State private var showEndChoices = false
    @State private var showSideEffects = false

    private enum Page: Equatable {
        case overview, editMedication, editDose, editDay, editHour
    }

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
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Space.xl)
            .animation(JeniMotion.settle, value: page)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Palette.bgPrimary)
        .onAppear(perform: reload)
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

    // MARK: the record

    @ViewBuilder
    private var recordSection: some View {
        Text("the record")
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
        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(lead.isEmpty ? "your medication" : lead)
                    .font(.custom("JeniHeroSerif-Regular", size: 15, relativeTo: .subheadline))
                    .foregroundStyle(
                        version.endedAt == nil
                            ? Palette.textPrimary : Palette.textPrimary.opacity(0.55)
                    )
                Spacer()
                Text(eraSpanWord(version))
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
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
                optionLine(day.word, selected: plan?.anchorWeekday == day.iso) {
                    apply { spec in
                        spec.scheduleRule = "weeklyAnchor"
                        spec.anchorWeekday = day.iso
                    }
                    advance(after: .editDay)
                }
            }
        }
        .padding(.top, Space.sm)

        if wizard {
            skipLine("not settled yet") { advance(after: .editDay) }
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

    private func door(
        _ label: String, _ value: String, action: @escaping () -> Void
    ) -> some View {
        Button {
            JeniHaptic.tick()
            withAnimation(JeniMotion.settle) { action() }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline) {
                    Text(label)
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                    Spacer()
                    Text(value)
                        .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.trailing)
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
        .accessibilityLabel("\(label), \(value)")
        .accessibilityHint("opens the editor")
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
                Text(value)
                    .font(.custom("JeniHeroSerif-Regular", size: 17, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.trailing)
            }
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
        if let wd = plan.anchorWeekday,
           let word = Self.weekdays.first(where: { $0.iso == wd })?.word {
            return "weekly · \(word)s"
        }
        return "weekly · pick a day"
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
