import SwiftUI
import PlankFood

// MARK: - PlateDetailSheet (v5.1)
//
// A logged plate, understood — the surface that never existed: tap a
// plate anywhere (today's strip, her plates) and the meal explains
// itself. What it was, what it carried, how it sat in its day, and
// what to do when the read was off. Receipt grammar, no charts, no
// verdicts. Suppressed cohorts get protein-words only (the standing
// law); numbers appear only where the pipeline stored them.

struct PlateDetailSheet: View {
    /// p61 — @State, not let: "fix this plate" updates the record in
    /// place, and the page re-reads its own entry so the corrected
    /// numbers land in front of her — the proof the fix took.
    @State private var entry: FoodLogPersister.FoodLogEntry
    let userId: String
    let onDismiss: () -> Void

    init(
        entry: FoodLogPersister.FoodLogEntry,
        userId: String,
        onDismiss: @escaping () -> Void
    ) {
        _entry = State(initialValue: entry)
        self.userId = userId
        self.onDismiss = onDismiss
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirmDelete = false
    @State private var pickingDay = false
    @State private var showRepair = false

    private var suppressed: Bool { CohortStore.isNumericSuppressed }

    /// Every plate from the same day — the contribution lines compare
    /// against the day the plate actually fed, so past plates stay
    /// honest ("that day") and today's stay live ("today").
    private var dayEntries: [FoodLogPersister.FoodLogEntry] {
        let key = TodayStateService.dayKey(for: entry.loggedAt)
        return FoodLogPersister.allEntries(userId: userId)
            .filter { TodayStateService.dayKey(for: $0.loggedAt) == key }
    }

    private var isToday: Bool {
        Calendar.current.isDateInToday(entry.loggedAt)
    }

    private var dayWord: String { isToday ? "today" : "that day" }

    var body: some View {
        JKSheetChrome(
            title: entry.title.isEmpty ? "a plate" : entry.title.lowercased(),
            eyebrow: eyebrowLine
        ) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let image = FoodPhotoStore.photo(entryId: entry.id) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 216)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.row, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                                    .strokeBorder(Palette.hairlineCocoa, lineWidth: 0.5)
                            )
                            .padding(.top, Space.md)
                            .accessibilityHidden(true)
                    }

                    hero
                        .padding(.top, Space.lg)

                    chemistryRows
                        .padding(.top, Space.lg)

                    dayRows
                        .padding(.top, Space.section)

                    if let details = entry.itemsDetail, !details.isEmpty {
                        itemLedger(details)
                            .padding(.top, Space.section)
                    }

                    if entry.wasVerified {
                        yourNumbers
                            .padding(.top, Space.section)
                    }

                    theDay
                        .padding(.top, Space.section)

                    againRow
                        .padding(.top, Space.section)

                    honesty
                        .padding(.top, Space.section)

                    Spacer(minLength: Space.xl)
                }
                .padding(.horizontal, Space.lg)
            }
            .scrollIndicators(.hidden)
        }
        .confirmationDialog(
            "let this plate go?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("remove it", role: .destructive) {
                FoodLogPersister.deleteEntry(id: entry.id)
                Haptics.soft()
                onDismiss()
            }
            Button("keep it", role: .cancel) {}
        } message: {
            Text("removing it takes it out of \(dayWord)'s count. you can snap a fresh one anytime.")
        }
        // p61 — the scan-time editor, reopened on the filed plate. On
        // save the page re-reads its own entry, so the corrected
        // numbers animate in right where the wrong ones stood.
        .jeniSheet(isPresented: $showRepair, detents: JeniSheetHeight.tall) {
            PlateRepairSheet(entry: entry, dayWord: dayWord) { saved in
                showRepair = false
                guard saved,
                      let updated = FoodLogPersister
                          .allEntries(userId: userId)
                          .first(where: { $0.id == entry.id })
                else { return }
                withAnimation(JeniMotion.settle) { entry = updated }
            }
        }
    }

    private var eyebrowLine: String {
        let time = entry.loggedAt.formatted(date: .omitted, time: .shortened).lowercased()
        if isToday { return "today \u{00B7} \(time)" }
        let fmt = DateFormatter()
        fmt.dateFormat = "EEEE, MMM d"
        return "\(fmt.string(from: entry.loggedAt).lowercased()) \u{00B7} \(time)"
    }

    // MARK: the relog (v23 §7 — history lives where history is)

    private var againRow: some View {
        Button {
            Haptics.soft()
            // E8.1 — `food_log_saved` now fires inside
            // FoodLogPersister.relog, so every again door is counted and
            // none can be forgotten. Only the surface attribution
            // belongs here.
            FoodLogPersister.relog(entry, userId: userId)
            FoodAnalytics.track(.relogUsed, properties: ["surface": "plate_page"])
            onDismiss()
        } label: {
            HStack(spacing: Space.sm) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textPrimary.opacity(0.7))
                Text("log it again")
                    .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: Space.sm)
                Text("a fresh entry, today")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("log it again as a fresh entry today")
    }

    // MARK: hero — PROTEIN LEADS (v25 E9)
    //
    // This sheet led with `340 calories` in a 44pt serif from v5.1 until
    // now. `00_THE_SYSTEM` §9 has said "protein floor + fiber lead; kcal
    // quiet" since v25 began; E7 fixed the inversion in the post-scan
    // reading and deleted its kcal ring, and E8 fixed it on Home — but
    // BOTH missed this sheet, which is the food detail every other door
    // actually lands on (Home's food row, the book, the plate chips).
    // E6 recorded that "the three food entrances ALREADY converge on one
    // reading"; that was wrong. This was a fourth reading, and the oldest.
    //
    // Calories are not deleted here — a plate's energy is a real fact and
    // this is not the moment to hide it. It states itself once, on the
    // tier that explains it (the split), rather than as the headline.
    @ViewBuilder private var hero: some View {
        if suppressed {
            ItalicAccentText(
                "about \(Int(entry.protein.rounded()))g of protein",
                italic: ["protein"],
                baseFont: .custom("JeniHeroSerif-Regular", size: 22, relativeTo: .title3),
                italicFont: .custom("JeniHeroSerif-Italic", size: 22, relativeTo: .title3),
                color: Palette.textPrimary,
                alignment: .leading
            )
        } else {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(Int(entry.protein.rounded()))")
                        .font(.custom("JeniHeroSerif-Regular", size: 44, relativeTo: .largeTitle))
                        .foregroundStyle(Palette.textPrimary)
                        .monospacedDigit()
                    Text("g protein")
                        .font(.custom("JeniHeroSerif-Italic", size: 18, relativeTo: .body))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 0)
                }
                if let share = proteinShareOfDay {
                    Text(share)
                        .font(.custom("DMSans-Regular", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The plate's protein against the day it belongs to — the one
    /// comparison that is always honest here, because both halves are
    /// hers. Silent on a day that has only this plate (comparing a
    /// number to itself says nothing).
    private var proteinShareOfDay: String? {
        guard entry.protein >= 1 else { return nil }
        let dayProtein = dayEntries.reduce(0.0) { $0 + $1.protein }
        guard dayProtein >= 1, dayEntries.count > 1 else { return nil }
        return "of \(Int(dayProtein.rounded())) g \(dayWord)"
    }

    // MARK: the plate — energy as ONE shape

    /// The macros were five equal receipt rows: protein, carbs, fat,
    /// fiber and sugar at one size, one weight, one colour, each on its
    /// own hairline. Nothing was loud, so nothing was legible, and the
    /// panel read as a spreadsheet.
    ///
    /// They are not five metrics. Protein/carbs/fat are ONE relationship
    /// (v18.1 — "N shapes must be N questions"), so they get one shape
    /// and one legend; fiber, sugar and sodium are a different question
    /// and get a quiet aligned row of their own.
    @ViewBuilder private var chemistryRows: some View {
        if !suppressed {
            VStack(alignment: .leading, spacing: 0) {
                // Stacks from XXXL up — the same frame-caught finding as
                // Home's day tier: a label, a serif figure and a unit on
                // one line do not survive accessibility type.
                Group {
                    if stacksForType {
                        VStack(alignment: .leading, spacing: 2) {
                            plateLabel
                            plateKcal
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            plateLabel
                            Spacer(minLength: 8)
                            plateKcal
                        }
                    }
                }

                PlateEnergySplit(
                    proteinG: Int(entry.protein.rounded()),
                    carbsG: Int(entry.carbs.rounded()),
                    fatG: Int(entry.fat.rounded())
                )
                .padding(.top, 10)

                Group {
                    if stacksForType {
                        VStack(alignment: .leading, spacing: 6) {
                            splitLegend("protein", grams: Int(entry.protein.rounded()),
                                        color: Palette.roseBerry)
                            splitLegend("carbs", grams: Int(entry.carbs.rounded()),
                                        color: Palette.accent)
                            splitLegend("fat", grams: Int(entry.fat.rounded()),
                                        color: Palette.roseBlush)
                        }
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            splitLegend("protein", grams: Int(entry.protein.rounded()),
                                        color: Palette.roseBerry)
                            Spacer(minLength: Space.sm)
                            splitLegend("carbs", grams: Int(entry.carbs.rounded()),
                                        color: Palette.accent)
                            Spacer(minLength: Space.sm)
                            splitLegend("fat", grams: Int(entry.fat.rounded()),
                                        color: Palette.roseBlush)
                        }
                    }
                }
                .padding(.top, 10)

                if !restCells.isEmpty {
                    restRow.padding(.top, 18)
                    if restCells.contains(where: { $0.reference != nil }) {
                        Text("dv is a general daily value, not your target")
                            .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .padding(.top, 8)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(plateA11y))
        } else if entry.protein >= 1 {
            EmptyView()
        }
    }

    private var stacksForType: Bool {
        typeSize.isAccessibilitySize || typeSize >= .xxxLarge
    }

    private var plateLabel: some View {
        Text("the plate")
            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
            .foregroundStyle(Palette.cocoaTertiary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var plateKcal: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(Int(entry.kcal.rounded()))")
                .font(.custom("JeniHeroSerif-Regular", size: 20, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
            Text("kcal")
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.7)
    }

    private func splitLegend(_ label: String, grams: Int, color: Color) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label)
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
            Text("\(grams) g")
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                .monospacedDigit()
                .foregroundStyle(Palette.textPrimary)
        }
        .lineLimit(1)
    }

    /// fiber · sugar · sodium — same denominator law as Home's band:
    /// fiber and sodium quote the published FDA Daily Value (21 CFR
    /// 101.9) marked `dv`; TOTAL sugar gets none, deliberately, because
    /// the FDA limit is on ADDED sugars.
    private struct RestCell: Identifiable {
        let label: String
        let amount: String
        let unit: String
        let reference: String?
        var id: String { label }
    }

    private var restCells: [RestCell] {
        var out: [RestCell] = []
        if entry.fiber >= 1 {
            out.append(RestCell(label: "fiber", amount: "\(Int(entry.fiber.rounded()))",
                                unit: "g", reference: "of 28 dv"))
        }
        if entry.sugar >= 1 {
            out.append(RestCell(label: "sugar", amount: "\(Int(entry.sugar.rounded()))",
                                unit: "g", reference: nil))
        }
        if entry.sodiumMg >= 1 {
            out.append(RestCell(label: "sodium",
                                amount: Int(entry.sodiumMg.rounded()).formatted(),
                                unit: "mg", reference: "of 2,300 dv"))
        }
        return out
    }

    private var restRow: some View {
        let cells = restCells
        let columns = (typeSize.isAccessibilitySize || typeSize >= .xxxLarge) ? 1 : cells.count
        return LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Space.md, alignment: .topLeading),
                count: max(1, columns)
            ),
            alignment: .leading,
            spacing: 12
        ) {
            ForEach(cells) { cell in
                if columns == 1 {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(cell.label)
                            .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: 4)
                        Text(cell.amount)
                            .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textPrimary)
                        Text(cell.unit)
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                        if let reference = cell.reference {
                            Text(reference)
                                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cell.label)
                            .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(1)
                        HStack(alignment: .firstTextBaseline, spacing: 3) {
                            Text(cell.amount)
                                .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
                                .monospacedDigit()
                                .foregroundStyle(Palette.textPrimary)
                            Text(cell.unit)
                                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        Text(cell.reference ?? " ")
                            .font(.custom("DMSans-Regular", size: 10, relativeTo: .caption2))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .opacity(cell.reference == nil ? 0 : 1)
                    }
                }
            }
        }
    }

    private var plateA11y: String {
        var parts = ["the plate, \(Int(entry.kcal.rounded())) calories",
                     "protein \(Int(entry.protein.rounded())) grams",
                     "carbs \(Int(entry.carbs.rounded())) grams",
                     "fat \(Int(entry.fat.rounded())) grams"]
        for cell in restCells {
            parts.append("\(cell.label) \(cell.amount) \(cell.unit)"
                         + (cell.reference.map { ", \($0)" } ?? ""))
        }
        return parts.joined(separator: ", ")
    }

    // MARK: the day around it — contribution with provenance

    @ViewBuilder private var dayRows: some View {
        let dayProtein = dayEntries.reduce(0.0) { $0 + $1.protein }
        let dayKcal = dayEntries.reduce(0.0) { $0 + $1.kcal }

        VStack(alignment: .leading, spacing: 0) {
            Text(isToday ? "in today" : "in its day")
                .font(Typo.captionTracked)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 4)

            // The protein-against-the-day row moved UP into the hero in
            // E9 — it is the reading, not a footnote to it — so it does
            // not repeat here.
            if !suppressed, entry.kcal >= 1, dayKcal >= 1, dayEntries.count > 1 {
                JKReceiptRow(
                    lead: "share of \(dayWord)'s calories",
                    punch: shareWords(entry.kcal / dayKcal),
                    punchItalic: [shareWords(entry.kcal / dayKcal)],
                    showsRule: false
                )
            }

            // Today only: where the day stands after everything so far
            // — the same voice as the snap result's day line, so the
            // app never says this two ways.
            if !suppressed, isToday,
               let target = TargetsService.current(
                   userId: userId,
                   in: modelContext
               ).kcal, target > 0 {
                let room = target - Int(dayKcal.rounded())
                JKReceiptRow(
                    lead: "the day so far",
                    punch: roomWords(room: room),
                    punchItalic: []
                )
            }
        }
    }

    private func shareWords(_ ratio: Double) -> String {
        switch ratio {
        case ..<0.18: "a small part"
        case ..<0.3: "about a quarter"
        case ..<0.42: "about a third"
        case ..<0.62: "about half"
        case ..<0.95: "most of it"
        default: isToday ? "all of it so far" : "the whole day"
        }
    }

    private func roomWords(room: Int) -> String {
        if room >= 150 { return "room for about \((room / 50) * 50)" }
        if room >= -60 { return "right around your target" }
        return "a little over \u{00B7} tomorrow resets"
    }

    // MARK: on the plate — the per-item read (device-local detail)

    @ViewBuilder private func itemLedger(_ details: [FoodLogPersister.ItemDetail]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("on the plate")
                .font(Typo.captionTracked)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 4)

            ForEach(Array(details.enumerated()), id: \.offset) { idx, item in
                // p61 — a portion the pipeline never recorded prints
                // NOTHING, not "0g": zero is a number and reads as a
                // measurement (film-caught on a repaired usual).
                let grams = item.portionG > 0
                    ? "\(Int(item.portionG.rounded()))g" : nil
                JKReceiptRow(
                    lead: item.name.lowercased(),
                    punch: suppressed
                        ? (grams ?? "")
                        : [grams, "\(Int(item.kcal.rounded())) cal"]
                            .compactMap { $0 }
                            .joined(separator: " \u{00B7} "),
                    showsRule: idx > 0
                )
            }
        }
    }

    // MARK: your numbers — the correction, read back
    //
    // E4 shipped corrections that PERSIST; the read half never did (see
    // `FoodLogEntry.corrections`). So the sequence was: she tells jeni
    // "that was a large, not a medium", jeni rescales the plate and
    // files it, and the next morning the plate says "read from your
    // photo · ranges, not exact" as if she had never spoken. Her own
    // words were the one thing in the record that could not be read.
    //
    // WHY IT IS A LEDGER OF SENTENCES AND NOT A BADGE. A pill saying
    // "corrected" would be decoration: it tells her a fact she already
    // knows and hides the only content that matters, which is WHAT she
    // said. These are the highest-value bytes in the food record — the
    // moment the user knew better than the model — so they render as
    // themselves, in her register, quoted.
    //
    // Prominence is EARNED: this tier appears only when it exists, sits
    // below the plate and the day (a provenance footnote, not a
    // headline), and carries no number of its own. It is also the only
    // tier on this sheet whose source is the user.
    @ViewBuilder private var yourNumbers: some View {
        // p53 — her spoken fixes AND her hand edits, one quoted block
        // (both are hers; the channel split matters to the priors, not
        // to this page).
        let lines = (entry.corrections ?? []) + (entry.edits ?? [])
        VStack(alignment: .leading, spacing: 0) {
            Text("your numbers")
                .font(Typo.captionTracked)
                .kerning(1.4)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
                .padding(.bottom, 6)

            // ONE drawn stem for the block, not one per line — a block
            // quote, which is what this is. A mark, never a colour, per
            // the attribution rule the care-team note already follows.
            HStack(alignment: .top, spacing: 12) {
                Capsule()
                    .fill(Palette.hairlineCocoa)
                    .frame(width: 1.5)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        // HER VOICE IS ALREADY SPECIFIED, and it is not
                        // this. The chat's own comment records the
                        // founder's ruling verbatim: "sans in the
                        // bubble. Serif italic is a READING face — set
                        // as a message it read as a book, not a
                        // conversation. Her voice is carried by the rose
                        // and the blush now, not by the slant."
                        //
                        // These lines are the same speaker as those
                        // bubbles, so they get the same face and the
                        // same ink. Two surfaces rendering one person's
                        // words must render them the same way, or the
                        // product code-switches about who is talking —
                        // which is the whole class of defect this pass
                        // exists to close. (I set these in serif italic
                        // first; the transcript is what caught it.)
                        Text(line.lowercased())
                            .font(.custom("DMSans-Regular", size: 16.5, relativeTo: .body))
                            .foregroundStyle(Palette.jeweledRose)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .fixedSize(horizontal: false, vertical: true)

            Text(Self.correctionFooting(for: entry.source))
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "your numbers. " + Self.correctionFooting(for: entry.source) + " "
                + lines.map { $0.lowercased() }.joined(separator: ", ")
        )
    }

    /// A relog copies the corrected numbers, so it carries the
    /// corrections too — but she fixed the DISH, on an earlier plate,
    /// not this entry. Saying "you fixed this plate" on a relog would be
    /// a small lie of the same family as "read from your photo" on a
    /// typed meal. Pure + static so a test can pin it.
    static func correctionFooting(for source: String?) -> String {
        source.flatMap(EntryMethod.init(rawValue:)) == .again
            ? "you fixed this dish before. these are your numbers, not the model's."
            : "you fixed this plate. these are your numbers, not the model's."
    }

    // MARK: the day — the plate lands where she ate it (v25 §34)
    //
    // Every capture path stamps `Date()`, so a plate has only ever been
    // able to land on the day it was LOGGED. A dinner logged at 12:10am
    // goes on tomorrow; a lunch remembered the next morning cannot go
    // anywhere at all. Three sessions named "logging food to a past day"
    // as the largest remaining boring gap and deferred it as a
    // write-path change.
    //
    // This is that capability at its smallest honest size, and it comes
    // out of the RECORD rather than the camera: the capture pipeline is
    // untouched, no door learns a date, and the repair sits where every
    // other repair to this plate already sits. Log it now, then say
    // when.
    //
    // Fourteen days, because that is the window in which a person can
    // actually remember what a meal was, and an unbounded date picker on
    // a record is an invitation to invent history.

    private var dayOptions: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<14).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    private func dayWord(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "today" }
        if cal.isDateInYesterday(date) { return "yesterday" }
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f.string(from: date).lowercased()
    }

    @ViewBuilder private var theDay: some View {
        VStack(alignment: .leading, spacing: Space.sm) {
            #if DEBUG
            // Film door — `--uitest-plate-detail --debug-plate-day`
            // opens the picker without a tap (simctl cannot tap, and an
            // affordance that has never been filmed open is an
            // affordance nobody has looked at).
            Color.clear.frame(height: 0).onAppear {
                guard ProcessInfo.processInfo.arguments
                    .contains("--debug-plate-day") else { return }
                pickingDay = true
            }
            #endif
            Button {
                Haptics.light()
                withAnimation(JeniMotion.settle) { pickingDay.toggle() }
            } label: {
                HStack(alignment: .firstTextBaseline) {
                    Text("the day")
                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
                        .foregroundStyle(Palette.textPrimary)
                    Spacer(minLength: Space.md)
                    Text(pickingDay ? "which day?" : dayWord(entry.loggedAt))
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("logged on \(dayWord(entry.loggedAt)). double-tap to move it to another day.")

            if pickingDay {
                VStack(spacing: 0) {
                    ForEach(dayOptions, id: \.self) { day in
                        let isCurrent = Calendar.current
                            .isDate(day, inSameDayAs: entry.loggedAt)
                        Button {
                            guard !isCurrent else {
                                withAnimation(JeniMotion.settle) { pickingDay = false }
                                return
                            }
                            Haptics.soft()
                            FoodLogPersister.setLoggedDay(id: entry.id, to: day)
                            FoodAnalytics.track(.logSaved, properties: [
                                "source": entry.source ?? "",
                                "entry_method": entry.source ?? "",
                                "action": "redated",
                            ])
                            onDismiss()
                        } label: {
                            HStack {
                                Text(dayWord(day))
                                    .font(.custom("DMSans-Regular", size: 15, relativeTo: .body))
                                    .foregroundStyle(
                                        isCurrent ? Palette.cocoaTertiary : Palette.textPrimary
                                    )
                                Spacer(minLength: Space.md)
                                if isCurrent {
                                    Text("where it is now")
                                        .font(Typo.caption)
                                        .foregroundStyle(Palette.cocoaTertiary)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(JKPress())
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                    }
                    Text("moving it takes its numbers off one day and puts them on another. nothing about the plate changes.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, Space.sm)
                }
                .transition(.opacity)
            }
        }
    }

    // MARK: honesty — what this is, and the way out when it's wrong

    /// One line per door. The vocabulary MOVED to `EntryMethod` — the
    /// type that owns the doors — because this sheet is the second
    /// surface a plate reaches and the first one (`ResultDetailCopy`,
    /// read at the moment of the scan) had no door branch at all. Two
    /// surfaces drawing the same sentence from two places is how one of
    /// them stayed wrong for an era.
    static func provenanceLine(for source: String?) -> String {
        EntryMethod.provenanceLine(for: source)
    }

    @ViewBuilder private var honesty: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            // E8.1 — this line used to be a two-way test on `source ==
            // "photo"`, which was wrong in both directions: a plate she
            // TYPED said "read from your photo" (words persisted as
            // photo), and a barcode read said "logged from your words".
            // Now that the record names the door, it can say what
            // actually happened — and printed truth stops apologising
            // for being an estimate, because it is not one.
            Text(Self.provenanceLine(for: entry.source))
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaTertiary)

            // p61 — the remedy ladder finally has a first rung. The
            // page used to offer exactly one repair: deletion ("off?
            // remove this plate") — while the BOOK's own a11y hint
            // promised "open, fix or remove it". FIX leads now; remove
            // stays. Suppressed cohorts keep the words-only face, so
            // the numeric editor stands down for them (delete and
            // re-log remain).
            // Stacks from xxxLarge — two capsules on one line clip at
            // accessibility sizes (the sheet's own stacksForType law).
            let fixLayout = stacksForType
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                : AnyLayout(HStackLayout(spacing: 10))
            fixLayout {
                if !suppressed {
                    Button {
                        Haptics.light()
                        showRepair = true
                    } label: {
                        Text("off? fix this plate")
                            .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .overlay(
                                Capsule().strokeBorder(Palette.textPrimary.opacity(0.35), lineWidth: 0.66)
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(JKPress())
                    .accessibilityHint("opens the editor to correct its items and numbers")
                }
                Button {
                    Haptics.light()
                    confirmDelete = true
                } label: {
                    Text(suppressed ? "off? remove this plate" : "remove")
                        .font(.custom("DMSans-Medium", size: 13, relativeTo: .footnote))
                        .foregroundStyle(Palette.cocoaSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .overlay(
                            Capsule().strokeBorder(Palette.hairlineCocoa, lineWidth: 0.66)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(JKPress())
                .accessibilityHint("removes this plate from the day")
            }
        }
    }
}
