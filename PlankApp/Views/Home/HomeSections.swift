import SwiftUI
import SwiftData
import PlankFood
import PlankSync

// MARK: - ProteinBandWords (p72 — one register, pinned across processes)
//
// The band's protein read as ONE law. The Home Screen widget carries
// its own copy of these words (`JeniWidgetSnapshot.proteinReading` —
// the widget process never links this file), and that copy drifted for
// two passes when p67 retired "the floor": the widget's pin froze the
// OLD literals instead of this function. WidgetSnapshotTests now pins
// the snapshot's words EQUAL to this — reword one side and a test
// names the other.
enum ProteinBandWords {
    static func reading(eatenG: Int, floorG: Int) -> String {
        let left = floorG - eatenG
        return left > 0 ? "\(left) g protein to go" : "protein goal hit"
    }
}

// MARK: - HomeNutritionSummary (p59 — THE DIAL)
//
// Home's food band, on the paper (no card: a reading lives on the
// paper, v15's container law): the remainder dial and the faces the
// record earns. See the reasoning on `body`. Faces render only what
// a store produced (§1.6): nothing logged → no plates face, no
// numbers face, nothing zeroed. The safety gate
// (targets.numericsSuppressed) collapses the band to the words-only
// face — no numerals anywhere.

struct HomeNutritionSummary: View {
    let snapshot: TodaySnapshot
    var userId: String = ""
    let onOpenFood: () -> Void
    /// Opens the repair door for the one fact that is stopping the energy
    /// target from existing. nil = the host has no door to offer, and the
    /// reference stays a bare word rather than a promise it cannot keep.
    var onRepairNumbers: ((TargetsService.MissingEnergyInput) -> Void)? = nil

    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The dial carousel's page and its measured stage height.
    @State private var faceIndex = 0
    @State private var dialFaceHeight: CGFloat = 0

    /// p63 — the check DRAWS only for a crossing this section
    /// witnessed live: the open-floor numeral rendered first, then
    /// the met state arrived. The once-per-day latch keeps a later
    /// visit from re-performing the draw (a celebration replayed on
    /// every appearance is wallpaper by lunchtime); it stamps only
    /// when the draw actually played, so a crossing swallowed by a
    /// cover keeps its chance. The key is user-scoped same-day state
    /// and joins the sign-out sweep (the §38 law).
    @AppStorage("dial.floorDrawnDayKey") private var floorDrawnDayKey = ""
    @State private var sawOpenFloor = false

    /// Which metric heads the band. The law, not a layout preference:
    /// `00_THE_SYSTEM` §9 — "protein floor + fiber lead; kcal quiet".
    enum Lead: String { case protein, calories }

    /// Pure so the ordering law stays testable. E8 made protein lead a
    /// five-face carousel; E9 removed the carousel and kept the law.
    ///
    /// The honest exception survives verbatim: with no weight collected
    /// there is no floor, so protein would be a bare gram count measured
    /// against nothing (E7's law — a denominator never renders without a
    /// floor). Calories lead in exactly that case and no other.
    static func lead(proteinFloorG: Int?, proteinEatenG: Int) -> Lead {
        (proteinFloorG ?? 0) > 0 ? .protein : .calories
    }

    private var leadMetric: Lead {
        Self.lead(proteinFloorG: snapshot.targets.proteinG,
                  proteinEatenG: snapshot.proteinEatenG)
    }

    // MARK: - the band
    //
    // p59 — THE DIAL. The founder's steer, mid-pass: the big ring IS
    // the default nutrition view, carousel included, with the day's
    // numbers compacted beneath it. What was wrong with the old band
    // was never the ring — it was a small, thick-stroked ring parked
    // in the page's left corner with a caption apologising beside it.
    // The reference (our own steps dial) has the answer: BIG, thin,
    // CENTERED, the serif numeral inside, the interpretation set as
    // an italic caption below — an instrument, not a chart.
    //
    //   face 1 · THE DAY    — the 156pt remainder dial (protein when
    //            a floor exists — §9's law — else calories): what is
    //            LEFT inside the ring, ONE kcal stat beneath.
    //   face 2 · THE PLATES — the day's eaten record as a small
    //            gallery, photographed where a photograph exists.
    //   face 3 · THE NUMBERS — the rest facts as a set table.
    //            E9 deleted the old pager because its faces
    //            duplicated a strip two tiers down; that strip is
    //            gone, so each face is the ONLY place its answer
    //            lives.
    //
    // The accessibility sizes keep the words-and-thread receipt (a
    // ring cannot hold its numeral at AX — §10.2, filmed twice), and
    // suppression keeps the words-only face. Every sentence law
    // stands: the lead rule, the remainder word, the count-up
    // silence, `· holding`, absence prints nothing.
    var body: some View {
        Group {
            if snapshot.targets.numericsSuppressed {
                bandButton {
                    VStack(alignment: .leading, spacing: 0) {
                        gateFace
                        plateStrip(topAir: 14)
                    }
                }
            } else if typeSize.isAccessibilitySize {
                bandButton {
                    VStack(alignment: .leading, spacing: 0) {
                        receiptLead
                        kcalLine
                        plateStrip(topAir: 16)
                        restLine
                    }
                }
            } else {
                dialCarousel
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(a11ySummary)
        .accessibilityHint("opens the book, your food record")
        .padding(.top, Space.sm)
    }

    private func bandButton(@ViewBuilder _ content: () -> some View) -> some View {
        Button(action: onOpenFood) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(JKPress())
    }

    // MARK: - the dial carousel

    /// Whether the record has earned a second face today.
    private var hasPlatesFace: Bool { !snapshot.plates.isEmpty }

    /// The record's own facts decide the pager: the plates face when
    /// plates exist, the numbers face when the day measured anything.
    private var hasNumbersFace: Bool { !numbersFacts.isEmpty }
    private var faceCount: Int {
        1 + (hasPlatesFace ? 1 : 0) + (hasNumbersFace ? 1 : 0)
    }

    private var dialCarousel: some View {
        VStack(spacing: 0) {
            // E8.2's lesson, kept: the stage takes the DAY face's own
            // measured height — a fixed constant sheared three rows
            // across three eras. A page-style TabView never sizes to
            // its pages, so an invisible twin of the day face is laid
            // out in the natural flow and the stage adopts its height.
            ZStack {
                dayFace
                    .hidden()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                TabView(selection: $faceIndex) {
                    bandButton { dayFace }
                        .tag(0)
                    if hasPlatesFace {
                        bandButton { platesFace }
                            .tag(1)
                    }
                    if hasNumbersFace {
                        bandButton { numbersFace }
                            .tag(hasPlatesFace ? 2 : 1)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: dialFaceHeight > 0 ? dialFaceHeight : nil)
            }
            if faceCount > 1 {
                HStack(spacing: 5) {
                    ForEach(0..<faceCount, id: \.self) { i in
                        Circle()
                            .fill(faceIndex == i
                                  ? Palette.roseBerry
                                  : Palette.accent.opacity(0.25))
                            .frame(width: 5, height: 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
                .animation(JeniMotion.morph, value: faceIndex)
            }
        }
        .onPreferenceChange(DialFaceHeightKey.self) { dialFaceHeight = $0 }
        .onAppear {
            #if DEBUG
            // The film door for the later faces — synthesized drags
            // cannot swipe this sim's pagers (the recorded limitation).
            let args = ProcessInfo.processInfo.arguments
            if let idx = args.firstIndex(of: "--uitest-band-face"),
               idx + 1 < args.count, let n = Int(args[idx + 1]) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation(JeniMotion.morph) {
                        faceIndex = min(max(n, 0), faceCount - 1)
                    }
                }
            }
            #endif
        }
    }

    // MARK: face 1 — THE DAY

    /// The dial answers the founder's third steer: the REMAINDER is
    /// the hero (the no-arithmetic UX), the donut is thicker and a
    /// touch smaller, and the words beneath compress to ONE stat —
    /// everything else moved to its own face. Only collected targets
    /// may speak "left" (protein's floor, the kcal target); nothing
    /// else gets a denominator, so nothing else gets a remainder.
    private var dayFace: some View {
        VStack(spacing: 0) {
            // p75 — the hero's budget: 156/15 spent ~500pt of the
            // first viewport on four facts and pushed TODAY below the
            // fold on every medicated day (filmed). 132/11.5 keeps
            // the instrument's presence and hands the fold back to
            // the list; the thinner stroke reads more drawn, less
            // gauge. The laws inside are untouched.
            ZStack {
                JeniRing(fraction: dialFraction, size: 132, lineWidth: 11.5)
                dialCentre
                    .frame(maxWidth: 96)
                    .minimumScaleFactor(0.6)
            }
            miniRow
                .padding(.top, 14)
            if leadMetric == .calories {
                repairLine
                    .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .background(
            GeometryReader { geo in
                Color.clear.preference(key: DialFaceHeightKey.self,
                                       value: geo.size.height)
            }
        )
    }

    /// Inside the dial: what is LEFT while the floor is open, the
    /// drawn check once it is met, the day's kcal when calories lead.
    @ViewBuilder private var dialCentre: some View {
        switch leadMetric {
        case .protein:
            if let target = snapshot.targets.proteinG, target > 0,
               snapshot.proteinEatenG >= target {
                // p63 — the check DRAWS when the crossing happens on
                // glass: this section watched the open floor (the
                // numeral rendered), the state flipped, and no cover
                // stands over Home. Everything else — cold launches
                // already met, mounts under the capture cover or the
                // loader (film-caught: a draw at mount finishes
                // before the reveal, three times) — rests complete.
                // The child holds the stroke until the gate clears,
                // so filing the crossing plate plays the draw at the
                // return, not under the cover; the latch stamps only
                // when the draw actually played.
                DialCheckDraw(
                    animated: sawOpenFloor
                        && floorDrawnDayKey != TodayStateService.dayKey()
                        && !reduceMotion,
                    onShown: { floorDrawnDayKey = TodayStateService.dayKey() }
                )
            } else {
                VStack(spacing: 1) {
                    JeniCountingNumeral(
                        value: Double(proteinToGo),
                        font: .custom("JeniHeroSerif-Regular", size: 38,
                                      relativeTo: .largeTitle)
                    )
                    Text("g protein to go")
                        .font(.custom("DMSans-Regular", size: 11.5, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                }
                // The open floor stood here — the witness half of the
                // live-crossing rule above.
                .onAppear { sawOpenFloor = true }
            }
        case .calories:
            VStack(spacing: 1) {
                JeniCountingNumeral(
                    value: Double(snapshot.kcalEaten),
                    font: .custom("JeniHeroSerif-Regular", size: 38,
                                  relativeTo: .largeTitle)
                )
                Text("kcal today")
                    .font(.custom("DMSans-Regular", size: 11.5, relativeTo: .caption))
                    .foregroundStyle(Palette.textSecondary)
            }
        }
    }


    // MARK: the minis — the deprioritized metrics (p59, fourth steer)

    /// The FDA daily value for fiber — the ONE published reference the
    /// fiber gauge may draw against, and it is NAMED on the label
    /// (`fiber · dv`), the E8 provenance rule. Sugar deliberately has
    /// no counterpart (the total-vs-added refusal), so its mini is a
    /// BADGE — a hairline seat with no track and no fill — never a
    /// gauge.
    private static let fiberDvG = 28

    /// Under the protein dial: sugar · fiber · kcal as mini dials —
    /// the founder's fourth steer (kcal deprioritized). Each mini
    /// echoes the parent's grammar (numeral inside, word below); a
    /// metric the day did not measure DROPS (the rest line's own
    /// absence law); the kcal mini speaks the pinned remainder
    /// grammar and keeps the count-up silence.
    @ViewBuilder private var miniRow: some View {
        if hasDay, leadMetric == .protein {
            HStack(alignment: .top, spacing: 8) {
                if snapshot.sugarEatenG > 0 {
                    miniBadge(numeral: "\(snapshot.sugarEatenG)", meta: "g",
                              label: "sugar")
                }
                if snapshot.fiberEatenG > 0 {
                    miniDial(numeral: "\(snapshot.fiberEatenG)", meta: "g",
                             label: "fiber · dv",
                             fraction: Double(snapshot.fiberEatenG)
                                 / Double(Self.fiberDvG))
                }
                kcalMini
            }
            .frame(maxWidth: 320)
        }
    }

    /// The kcal mini: the remainder inside when the record has one to
    /// state, the eaten figure otherwise — count-up past the target
    /// stays wordless, maintenance keeps `· holding`. Protein leading
    /// implies a weight on file, which implies the kcal target exists.
    @ViewBuilder private var kcalMini: some View {
        if let kcal = snapshot.targets.kcal, kcal > 0 {
            let word = Self.energyRemainderWord(
                targetKcal: kcal,
                eatenKcal: snapshot.kcalEaten,
                isMaintenance: snapshot.energyIsMaintenance,
                countUpOnly: snapshot.chapter == .onMedication
            )
            let fraction = Double(snapshot.kcalEaten) / Double(kcal)
            if let word, word == "right on it" {
                miniDial(numeral: snapshot.kcalEaten.formatted(), meta: nil,
                         label: "right on it", fraction: fraction)
            } else if let word, let space = word.lastIndex(of: " ") {
                miniDial(numeral: String(word[..<space]), meta: nil,
                         label: "kcal \(String(word[word.index(after: space)...]))",
                         fraction: fraction)
            } else if snapshot.energyIsMaintenance {
                miniDial(numeral: snapshot.kcalEaten.formatted(), meta: nil,
                         label: "kcal · holding", fraction: fraction)
            } else {
                // Count-up past the target: the figure, no word.
                miniDial(numeral: snapshot.kcalEaten.formatted(), meta: nil,
                         label: "kcal", fraction: fraction)
            }
        }
    }

    /// One mini dial: a 52pt ring, the numeral inside in the serif,
    /// the word beneath — the parent dial's grammar at gauge scale.
    private func miniDial(
        numeral: String, meta: String?, label: String, fraction: Double
    ) -> some View {
        miniColumn(numeral: numeral, meta: meta, label: label) {
            JeniRing(fraction: fraction, size: 52, lineWidth: 5)
        }
    }

    /// The badge variant — an ink hairline seat for a metric with no
    /// denominator: clearly a different species from a gauge.
    private func miniBadge(
        numeral: String, meta: String?, label: String
    ) -> some View {
        miniColumn(numeral: numeral, meta: meta, label: label) {
            Circle()
                .strokeBorder(Palette.textPrimary.opacity(0.10), lineWidth: 1.2)
                .frame(width: 52, height: 52)
        }
    }

    private func miniColumn(
        numeral: String, meta: String?, label: String,
        @ViewBuilder seat: () -> some View
    ) -> some View {
        VStack(spacing: 7) {
            ZStack {
                seat()
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text(numeral)
                        .font(.custom("JeniHeroSerif-Regular", size: 15,
                                      relativeTo: .subheadline))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textPrimary)
                        .contentTransition(.numericText())
                        .animation(JeniMotion.morph, value: numeral)
                    if let meta {
                        Text(meta)
                            .font(.custom("DMSans-Regular", size: 9,
                                          relativeTo: .caption2))
                            .foregroundStyle(Palette.textSecondary)
                    }
                }
                .frame(maxWidth: 40)
                .minimumScaleFactor(0.55)
            }
            Text(label)
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
    }

    /// What the dial draws: the lead metric's own fraction.
    private var dialFraction: Double {
        switch leadMetric {
        case .protein:
            guard let target = snapshot.targets.proteinG, target > 0 else { return 0 }
            return Double(snapshot.proteinEatenG) / Double(target)
        case .calories:
            guard let kcal = snapshot.targets.kcal, kcal > 0 else { return 0 }
            return Double(snapshot.kcalEaten) / Double(kcal)
        }
    }

    private func captionLine(_ roman: String, _ italic: String) -> Text {
        (Text(roman)
            .font(.custom("JeniHeroSerif-Regular", size: 18, relativeTo: .body))
         + Text(italic)
            .font(.custom("JeniHeroSerif-Italic", size: 18, relativeTo: .body)))
            .foregroundColor(Palette.textPrimary.opacity(0.85))
    }

    // MARK: face 2 — THE PLATES

    /// The record as a small GALLERY — a page from the book, not a
    /// chip row: the latest four plates in a mosaic that fills the
    /// dial's stage, the count set beneath in the caption grammar.
    private var platesFace: some View {
        let shown = Array(snapshot.plates.suffix(4))
        let cell: CGFloat = shown.count <= 2 ? 108 : 92
        return VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(shown.prefix(2), id: \.id) { plate in
                        plateSeat(plate, size: cell)
                    }
                }
                if shown.count > 2 {
                    HStack(spacing: 8) {
                        ForEach(shown.dropFirst(2), id: \.id) { plate in
                            plateSeat(plate, size: cell)
                        }
                    }
                }
            }
            Group {
                if snapshot.plates.count == 1 {
                    captionLine("one plate, ", "counted.")
                } else {
                    captionLine("\(snapshot.plates.count) plates, ", "counted.")
                }
            }
            .padding(.top, 16)
            Text("the full day is in the book")
                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
                .padding(.top, 3)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: face 3 — THE NUMBERS

    /// The day's chemistry as a SET table — the rest line's facts
    /// (same pinned order, same drop-when-unmeasured law), one to a
    /// row, the amount in serif. Fiber and sugar left this table for
    /// the minis under the dial (fourth steer) — each fact lives in
    /// exactly ONE place, the E9 rule that justifies the pager.
    private var numbersFacts: [RestFact] {
        restFacts.filter { $0.label != "fiber" && $0.label != "sugar" }
    }

    private var numbersFace: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ForEach(Array(numbersFacts.enumerated()), id: \.element.label) { i, fact in
                    if i > 0 {
                        Rectangle()
                            .fill(Palette.hairlineCocoa)
                            .frame(height: 0.5)
                    }
                    HStack(alignment: .firstTextBaseline) {
                        Text(fact.label)
                            .font(.custom("DMSans-Regular", size: 13, relativeTo: .caption))
                            .foregroundStyle(Palette.textSecondary)
                        Spacer(minLength: Space.md)
                        (Text(fact.amount)
                            .font(.custom("JeniHeroSerif-Regular", size: 17,
                                          relativeTo: .body))
                         + Text(" \(fact.unit)")
                            .font(.custom("DMSans-Regular", size: 12,
                                          relativeTo: .caption)))
                            .foregroundColor(Palette.textPrimary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 9)
                }
            }
            .frame(maxWidth: 230)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - the accessibility receipt (words and a thread)

    @ViewBuilder private var receiptLead: some View {
        switch leadMetric {
        case .protein: proteinLead
        case .calories: caloriesLead
        }
    }

    /// The serif fact line: a roman numeral phrase closed by an italic
    /// clause — the greeting's own composition, carrying the band's
    /// answer. `.numericText` morphs the digits forward when a plate
    /// lands (v12's law: addition, never a reset).
    private func factLine(_ roman: String, _ italic: String) -> some View {
        (Text(roman)
            .font(.custom("JeniHeroSerif-Regular", size: 26, relativeTo: .title2))
         + Text(italic)
            .font(.custom("JeniHeroSerif-Italic", size: 26, relativeTo: .title2)))
            .foregroundStyle(Palette.textPrimary)
            .contentTransition(.numericText())
            .animation(JeniMotion.morph, value: roman)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var proteinLead: some View {
        VStack(alignment: .leading, spacing: 0) {
            bandLabel(HomeNutritionSummary.Lead.protein.rawValue)
            Group {
                if let target = snapshot.targets.proteinG, target > 0,
                   snapshot.proteinEatenG >= target {
                    factLine("protein goal ", "hit.")
                } else {
                    factLine("\(proteinToGo) g ", "protein to go.")
                }
            }
            .padding(.top, 5)
            Text("\(snapshot.proteinEatenG) of \(snapshot.targets.proteinG ?? 0) g · \(proteinState.tail)")
                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 5)
            if let target = snapshot.targets.proteinG, target > 0 {
                JeniFloorThread(
                    fraction: Double(snapshot.proteinEatenG) / Double(target)
                )
                .padding(.top, 13)
            }
        }
    }

    private var proteinToGo: Int {
        max(0, (snapshot.targets.proteinG ?? 0) - snapshot.proteinEatenG)
    }

    /// The calories lead — the honest exception (no floor on file means
    /// no weight on file, which also means no kcal target). It states
    /// what the day holds and offers the one door that changes it.
    private var caloriesLead: some View {
        VStack(alignment: .leading, spacing: 0) {
            bandLabel(HomeNutritionSummary.Lead.calories.rawValue)
            factLine("\(snapshot.kcalEaten.formatted()) kcal ", "today.")
                .padding(.top, 5)
            repairLine
                .padding(.top, 6)
        }
    }

    /// The no-target repair, stated as a sentence rather than a warning.
    /// Silent when the host has no door, and silent under numeric
    /// suppression — a suppressed cohort is never asked for a weight.
    @ViewBuilder
    private var repairLine: some View {
        if !snapshot.targets.numericsSuppressed,
           let missing = snapshot.missingEnergyInput,
           let onRepairNumbers {
            Button {
                Haptics.light()
                onRepairNumbers(missing)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text("no daily target yet")
                        .font(.custom("DMSans-Medium", size: 15, relativeTo: .subheadline))
                        .foregroundStyle(Palette.textPrimary)
                    Text(missing.repairSubline)
                        .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("no daily target yet. add \(missing.word) and it arrives.")
        }
    }

    // MARK: - the energy sentence

    private var hasDay: Bool { snapshot.kcalEaten > 0 }

    /// A row that fits at 17pt does not fit at 53pt (XXXL frame-caught,
    /// twice) — from the accessibility sizes up the sentence stacks.
    private var stacksForType: Bool {
        typeSize.isAccessibilitySize || typeSize >= .xxxLarge
    }

    /// The p57 energy sentence, one tier down from the lead: the eaten
    /// numeral in serif, the reference (with its remainder word, its
    /// count-up silence, its `· holding`, or its repair door) beside it.
    /// Only rendered once the day has measured something — and only
    /// under the protein lead, because the calories lead already IS the
    /// kcal statement.
    @ViewBuilder private var kcalLine: some View {
        if hasDay, leadMetric == .protein {
            Group {
                if stacksForType {
                    VStack(alignment: .leading, spacing: 2) {
                        kcalNumeral
                        reference
                    }
                } else {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        kcalNumeral
                        reference
                    }
                }
            }
            .padding(.top, 16)
        }
    }

    private var kcalNumeral: some View {
        Text(snapshot.kcalEaten.formatted())
            .font(.custom("JeniHeroSerif-Regular", size: 19, relativeTo: .title3))
            .monospacedDigit()
            .foregroundStyle(Palette.textPrimary)
            .contentTransition(.numericText())
            .animation(JeniMotion.morph, value: snapshot.kcalEaten)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
    }

    // p57 — THE BAND SPEAKS ONE GRAMMAR NOW.
    //
    // E9's three tiers were three different visual systems for one
    // subject: a ring, then a three-segment bar with a dot legend,
    // then a three-column grid with its own serif figures and a
    // regulatory footnote. Each was individually reasoned; together
    // they were the founder's "too complicated, visually fragmented"
    // — the eye re-learns a grammar at every tier of a surface that
    // should answer one question. The ring keeps its earned shape
    // (protein is the only number with a collected personal target);
    // energy remains ONE sentence; and everything else at rest is one
    // quiet line in one register:
    //
    //   carbs 59 g · fat 33 g · fiber 11 g · sugar 20 g · sodium 710 mg
    //
    // The dv references and their footnote leave Home with the grid —
    // the interpretive layer (targets, mechanisms, the FDA references)
    // lives one tap away in Becoming's tiles and the plate reading,
    // where studying happens. Absence laws hold: a day that measured
    // nothing prints nothing, suppression silences every numeral.

    struct RestFact: Equatable {
        let label: String
        let amount: String
        let unit: String
        /// "sodium 710 mg" with no-break joins, so a wrap can never
        /// strand a unit or split a pair (AX sizes wrap between pairs).
        var text: String { "\(label)\u{00A0}\(amount)\u{00A0}\(unit)" }
        var spoken: String {
            let unitWord = unit == "mg" ? "milligrams" : "grams"
            return "\(label) \(amount) \(unitWord)"
        }
    }

    /// Pure, so the one-line law is testable without a view.
    static func restFacts(
        carbsG: Int, fatG: Int, fiberG: Int, sugarG: Int, sodiumMg: Int,
        hasDay: Bool, numericsSuppressed: Bool
    ) -> [RestFact] {
        guard !numericsSuppressed, hasDay else { return [] }
        // p70's absence law, day level: a stated protein-only day
        // measures no carbs or fat — 0 here means not collected (the
        // same convention fiber/sugar/sodium have always followed),
        // and "carbs 0 g" would state a zero-carb day she never had.
        var out: [RestFact] = []
        if carbsG > 0 { out.append(RestFact(label: "carbs", amount: "\(carbsG)", unit: "g")) }
        if fatG > 0 { out.append(RestFact(label: "fat", amount: "\(fatG)", unit: "g")) }
        if fiberG > 0 { out.append(RestFact(label: "fiber", amount: "\(fiberG)", unit: "g")) }
        if sugarG > 0 { out.append(RestFact(label: "sugar", amount: "\(sugarG)", unit: "g")) }
        if sodiumMg > 0 {
            out.append(RestFact(label: "sodium", amount: sodiumMg.formatted(), unit: "mg"))
        }
        return out
    }

    private var restFacts: [RestFact] {
        Self.restFacts(
            carbsG: snapshot.carbsEatenG,
            fatG: snapshot.fatEatenG,
            fiberG: snapshot.fiberEatenG,
            sugarG: snapshot.sugarEatenG,
            sodiumMg: Int(snapshot.plates.reduce(0) { $0 + $1.sodiumMg }.rounded()),
            hasDay: hasDay,
            numericsSuppressed: snapshot.targets.numericsSuppressed
        )
    }

    @ViewBuilder private var restLine: some View {
        let facts = restFacts
        if !facts.isEmpty {
            Text(facts.map(\.text).joined(separator: " · "))
                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 10)
        }
    }

    /// WHAT IS LEFT TODAY — the subtraction the product asked her to do
    /// in her head.
    ///
    /// The band stated `1,660 of 1,460 kcal` and stopped. That is the
    /// eaten figure and its provenance; it is not the number that changes
    /// her next decision, which is *how much room is left*. The whole
    /// grammar for it already ships one tier up: `PlateAnswerEngine`
    /// closes every protein sentence with "18 g to go", and the evening
    /// close is built on the same gap. Energy — the number this plan is
    /// priced on — was the one place the product computed a position and
    /// declined to state the remainder.
    ///
    /// It is also a promise. The consult's own device demo (`V8Device`,
    /// face 1) draws this exact ring and captions it, in italic serif,
    /// **"what's left today"** — a caption for a subtraction the shipped
    /// app never performed. Same class as `31` §4's two broken promises
    /// ("you can change this anytime"), about the number she is paying
    /// for.
    ///
    /// Rides the established `· <word>` suffix (`31` §8's `· holding`)
    /// so it is one line, one tier, no new furniture.
    ///
    /// **Maintenance keeps `· holding` and gets no remainder**, and the
    /// refusal is the point: a maintenance figure is an ESTIMATE OF HER
    /// EXPENDITURE, not a budget she was given to spend. "220 left"
    /// against an estimate is an instruction to eat that nothing in the
    /// record supports.
    /// Pure so the honesty table is testable without a view.
    /// p53 — `countUpOnly` is the GLP-1 posture: the medication is
    /// already doing the deficit, and "over" is the market's named
    /// harm for this cohort (the countdown trauma; the what-the-hell
    /// effect). Under stays spoken — it invites eating, which is this
    /// cohort's actual job — and past the target the pair of numbers
    /// states the fact plainly with no judgment tail.
    static func energyRemainderWord(
        targetKcal: Int?, eatenKcal: Int, isMaintenance: Bool,
        countUpOnly: Bool = false
    ) -> String? {
        guard let kcal = targetKcal, kcal > 0, !isMaintenance else { return nil }
        let diff = kcal - eatenKcal
        if diff > 0 { return "\(diff.formatted()) left" }
        if diff < 0 { return countUpOnly ? nil : "\((-diff).formatted()) over" }
        return "right on it"
    }

    /// The whole reference sentence, so a nil remainder can never leave a
    /// dangling separator on screen.
    static func energyReferenceLine(
        targetKcal: Int?, eatenKcal: Int, isMaintenance: Bool,
        countUpOnly: Bool = false
    ) -> String? {
        guard let kcal = targetKcal, kcal > 0 else { return nil }
        let base = "of \(kcal.formatted()) kcal"
        if isMaintenance { return base + " · holding" }
        guard let word = energyRemainderWord(
            targetKcal: kcal, eatenKcal: eatenKcal, isMaintenance: false,
            countUpOnly: countUpOnly
        ) else { return base }
        return base + " · " + word
    }

    private var energyReference: String? {
        Self.energyReferenceLine(
            targetKcal: snapshot.targets.kcal,
            eatenKcal: snapshot.kcalEaten,
            isMaintenance: snapshot.energyIsMaintenance,
            // p53 — the on-medication chapter counts UP.
            countUpOnly: snapshot.chapter == .onMedication
        )
    }

    /// THE EMPTY DENOMINATOR IS A DOOR.
    ///
    /// When the energy target cannot exist, this said "kcal" — factually
    /// true, and a dead end for the one user who most needs to act.
    /// `missingEnergyInput` knows which fact is absent, so the line names
    /// it and opens on it.
    @ViewBuilder
    private var reference: some View {
        if let line = energyReference {
            // A maintenance number and a loss target are the same glyph
            // and opposite instructions. When she reaches her goal the
            // target jumps by the whole deficit; without the word, that
            // is a number changing for no stated reason, which is a
            // support email.
            Text(line)
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel(
                    "\(snapshot.kcalEaten.formatted()) kcal, "
                    + line.replacingOccurrences(of: " · ", with: ", ")
                )
        } else if !snapshot.targets.numericsSuppressed,
                  let missing = snapshot.missingEnergyInput,
                  let onRepairNumbers {
            Button {
                Haptics.light()
                onRepairNumbers(missing)
            } label: {
                Text("kcal · \(missing.doorLine)")
                    .font(.custom("DMSans-Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .underline(true, pattern: .solid)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
            }
            .buttonStyle(JKPress())
            .accessibilityLabel("no daily target yet. \(missing.doorLine)")
        } else {
            Text("kcal")
                .font(.custom("DMSans-Regular", size: 11, relativeTo: .caption2))
                .foregroundStyle(Palette.cocoaTertiary)
        }
    }

    // MARK: - the plates (the day's record, made visible)

    /// Up to four of today's plates, photographed where a photograph
    /// exists, seated where the record was typed — plus a quiet count
    /// for the rest. The page's only photography, and it is hers
    /// (v21 D6's law, promoted from a 40pt row chip to the band).
    /// Photographs are not numerals, so the strip survives the
    /// suppression face.
    @ViewBuilder
    private func plateStrip(topAir: CGFloat, size: CGFloat = 54) -> some View {
        let plates = snapshot.plates
        if !plates.isEmpty {
            let shown = Array(plates.suffix(4))
            let more = plates.count - shown.count
            HStack(spacing: 7) {
                ForEach(shown, id: \.id) { plate in
                    plateSeat(plate, size: size)
                }
                if more > 0 {
                    Text("+\(more)")
                        .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                        .monospacedDigit()
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 30, height: size, alignment: .leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.top, topAir)
            .accessibilityHidden(true)   // the summary sentence speaks
        }
    }

    @ViewBuilder
    private func plateSeat(_ plate: FoodLogPersister.FoodLogEntry,
                           size: CGFloat) -> some View {
        if let photo = FoodPhotoStore.photo(entryId: plate.id) {
            Image(uiImage: photo)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.28,
                                            style: .continuous))
        } else {
            // A typed plate is a record, not an invitation: a quiet
            // filled seat carrying the dish's own initial in the serif
            // italic — her latte reads "l", her sandwich "t", so two
            // typed plates never render as the same repeated button.
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Palette.accentSubtle.opacity(0.38))
                if let initial = plateInitial(plate.title) {
                    Text(initial)
                        .font(.custom("JeniHeroSerif-Italic", size: size * 0.44))
                        .foregroundStyle(Palette.roseBerry.opacity(0.7))
                        .baselineOffset(2)
                } else {
                    Image("doodle-cutlery")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: size * 0.37, height: size * 0.37)
                        .foregroundStyle(Palette.roseBerry.opacity(0.65))
                }
            }
            .frame(width: size, height: size)
        }
    }

    /// The first letter of the dish, lowercased — nil when the title
    /// holds nothing letter-like to set.
    private func plateInitial(_ title: String) -> String? {
        let first = title.trimmingCharacters(in: .whitespacesAndNewlines).first
        guard let first, first.isLetter else { return nil }
        return String(first).lowercased()
    }

    // MARK: - furniture

    private func bandLabel(_ word: String) -> some View {
        Text(word)
            .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .footnote))
            .foregroundStyle(Palette.textPrimary.opacity(0.55))
    }

    // MARK: - the safety-gate face (words, never numerals)

    private var gateFace: some View {
        VStack(alignment: .leading, spacing: 4) {
            JeniHeadline(platesLine.text, italic: platesLine.italic)
            Text("gentle plates, protein first · numbers off")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
    }

    private var platesLine: (text: String, italic: [String]) {
        let n = snapshot.plates.count
        if n == 0 { return ("no plates yet today.", []) }
        if n == 1 { return ("one plate, counted.", ["counted."]) }
        return ("\(n) plates, counted.", ["counted."])
    }

    // MARK: - the stores behind the tiers (§1.6 — collected fields only)

    /// The state, then its reason. Split so the reading can carry two
    /// registers instead of one 12pt line.
    private var proteinState: (head: String, tail: String) {
        guard let target = snapshot.targets.proteinG, target > 0 else {
            return ("\(snapshot.proteinEatenG) g today", "protein first")
        }
        let head = ProteinBandWords.reading(
            eatenG: snapshot.proteinEatenG, floorG: target
        )
        let left = target - snapshot.proteinEatenG
        return (head, left > 0 ? "protein first" : "nice work")
    }

    private var a11ySummary: String {
        if snapshot.targets.numericsSuppressed {
            return "\(platesLine.text) gentle plates, protein first"
        }
        var parts: [String] = []
        if let target = snapshot.targets.proteinG, target > 0 {
            parts.append("protein \(snapshot.proteinEatenG) of \(target) grams, \(proteinState.head)")
        } else {
            parts.append("protein \(snapshot.proteinEatenG) grams")
        }
        if snapshot.kcalEaten > 0 {
            if let kcal = snapshot.targets.kcal, kcal > 0 {
                parts.append("\(snapshot.kcalEaten) calories of \(kcal) kcal")
            } else if let missing = snapshot.missingEnergyInput {
                parts.append("\(snapshot.kcalEaten) calories, no daily target yet. \(missing.doorLine)")
            } else {
                parts.append("\(snapshot.kcalEaten) calories")
            }
        }
        let n = snapshot.plates.count
        if n > 0 {
            parts.append(n == 1 ? "one plate logged" : "\(n) plates logged")
        }
        parts.append(contentsOf: restFacts.map(\.spoken))
        return parts.joined(separator: ", ")
    }
}

/// The dial's met mark — the strip's kept-check stroke, drawn at the
/// dial's centre (one check language across the page).
private struct DialCheck: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY + rect.height * 0.05))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.36,
                              y: rect.maxY - rect.height * 0.08))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.1))
        return p
    }
}

/// p63 — the dial's met centre: the check draws tip-to-tail on the
/// chart curve (curves draw, springs touch), the label breathes in
/// under it — only for a LIVE crossing (`animated`), and only once
/// no cover stands over Home: the crossing plate flips the state
/// while the capture cover is still up, so the stroke waits for the
/// gate to clear and plays at the return. No haptic — an appearance
/// is a passive event (§8.3); the crossing's haptic rides the plate
/// answer, the action that caused it. Owns its own progress so the
/// carousel's page re-hosting cannot strand the animation mid-mount.
private struct DialCheckDraw: View {
    let animated: Bool
    var onShown: () -> Void = {}

    @State private var progress: CGFloat
    @State private var labelShown: Bool
    @State private var played = false

    init(animated: Bool, onShown: @escaping () -> Void = {}) {
        self.animated = animated
        self.onShown = onShown
        _progress = State(initialValue: animated ? 0 : 1)
        _labelShown = State(initialValue: !animated)
    }

    var body: some View {
        // Reading the gate in `body` registers the @Observable
        // dependency, so the clear re-renders and `onChange` fires.
        let covered = PresentationGate.shared.occupied()
        VStack(spacing: 5) {
            DialCheck()
                .trim(from: 0, to: progress)
                .stroke(Palette.textPrimary,
                        style: StrokeStyle(lineWidth: 2.4, lineCap: .round,
                                           lineJoin: .round))
                .frame(width: 26, height: 26)
            Text("goal hit")
                .font(.custom("DMSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Palette.textSecondary)
                .opacity(labelShown ? 1 : 0)
        }
        .onAppear { maybePlay(covered: covered) }
        .onChange(of: covered) { _, nowCovered in
            maybePlay(covered: nowCovered)
        }
    }

    private func maybePlay(covered: Bool) {
        guard animated else { return }
        guard !played, !covered else { return }
        played = true
        onShown()
        withAnimation(JeniMotion.draw.delay(0.25)) { progress = 1 }
        withAnimation(.easeOut(duration: 0.3).delay(0.7)) { labelShown = true }
    }
}

/// The dial carousel's stage height — the DAY face reports, the
/// stage adopts (E8.2's measured-faces law).
private struct DialFaceHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - JeniFloorThread (p59 — the floor as a line you cross)
//
// The protein instrument, re-shaped for what a floor IS: not a budget
// that closes (a ring's grammar) but a threshold to rise past. The
// tick marks the floor at 82% of the drawn track, so landing beyond
// it is VISIBLE — met is a crossing, never a clipped full circle.
// The fill keeps the rose ramp (dusty → berry, quantities fill rose)
// and lands whole-berry once the floor is met, the ring's own met
// law. Draws in on the elastic spring at arrival; morphs to any new
// fraction (a landed plate) — JeniRing's trace grammar, on a thread.

struct JeniFloorThread: View {
    /// eaten / floor; values past 1 keep filling to the track's end.
    let fraction: Double

    @Environment(\.jeniArrived) private var arrived
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn: Double = 0
    @State private var seen = false

    /// Where the floor sits on the track.
    private let floorStop: Double = 0.82

    private var target: Double { min(1.0 / floorStop, max(0, fraction)) }

    var body: some View {
        GeometryReader { geo in
            let floorX = geo.size.width * floorStop
            let fillW = max(0, floorX * drawn)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Palette.accent.opacity(0.18))
                    .frame(height: 3)
                if drawn > 0 {
                    Capsule()
                        .fill(
                            drawn >= 1
                                ? AnyShapeStyle(Palette.roseBerry)
                                : AnyShapeStyle(LinearGradient(
                                    colors: [Palette.accent, Palette.roseBerry],
                                    startPoint: .leading, endPoint: .trailing
                                ))
                        )
                        .frame(width: max(3, fillW), height: 3)
                }
                Rectangle()
                    .fill(Palette.textPrimary.opacity(0.32))
                    .frame(width: 1.2, height: 9)
                    .offset(x: floorX)
            }
            .frame(height: 9)
        }
        .frame(height: 9)
        .accessibilityHidden(true)   // the words above it speak
        .jeniArmOnVisible($seen)
        .onChange(of: arrived) { _, _ in trace() }
        .onChange(of: seen) { _, _ in trace() }
        .onAppear { trace() }
        .onChange(of: fraction) {
            withAnimation(reduceMotion ? nil : JeniMotion.morph) {
                drawn = target
            }
        }
    }

    private func trace() {
        guard arrived, seen, drawn == 0 else { return }
        if reduceMotion {
            drawn = target
            return
        }
        withAnimation(JeniMotion.elastic) { drawn = target }
    }
}

// MARK: - HomeDayRecap (v11.5 — the strip's answer for other days)
//
// Selecting a past day re-keys the page to that day's RECORD: what
// landed, in that day's own numbers. Never a report card — quiet
// memory (L10). Future days decline politely. v21: the recap wears
// the card grammar (label · value · shape).

struct HomeDayRecap: View {
    let date: Date
    let userId: String
    let onOpenRecord: () -> Void
    let onBackToToday: () -> Void
    /// p72 — a tapped plate opens the host's existing detail sheet
    /// (fix, re-date, remove — the full repair loop from a past day).
    var onOpenPlate: ((FoodLogPersister.FoodLogEntry) -> Void)? = nil

    @Environment(\.modelContext) private var modelContext

    private var cal: Calendar { Calendar.current }
    private var isFuture: Bool { date > cal.startOfDay(for: .now) }

    struct DayTotals {
        var kcal = 0.0, protein = 0.0, carbs = 0.0, fat = 0.0
        var plates = 0
        // p70's absence law at the DAY level: a macro no plate measured
        // is unknown, not zero — this card printed "carbs 0 g · fat 0 g"
        // and drew a 100% protein split over a stated protein bar.
        var proteinMeasured = false, carbsMeasured = false, fatMeasured = false
        var splitKnown = false
        var photoEntryIds: [String] = []
    }

    /// Pure, so the day-level absence law is testable without a view
    /// (the p36 lesson: a rule inside a view body cannot be tested).
    static func dayTotals(
        _ entries: [FoodLogPersister.FoodLogEntry], on date: Date,
        cal: Calendar = .current
    ) -> DayTotals {
        var t = DayTotals()
        var allSplitsKnown = true
        for entry in entries where cal.isDate(entry.loggedAt, inSameDayAs: date) {
            t.kcal += entry.kcal
            if let p = entry.measuredProtein { t.protein += p; t.proteinMeasured = true }
            if let c = entry.measuredCarbs { t.carbs += c; t.carbsMeasured = true }
            if let f = entry.measuredFat { t.fat += f; t.fatMeasured = true }
            allSplitsKnown = allSplitsKnown && entry.splitIsKnown
            t.plates += 1
            t.photoEntryIds.append(entry.id)
        }
        t.splitKnown = t.plates > 0 && allSplitsKnown
        return t
    }

    private var totals: DayTotals {
        Self.dayTotals(FoodLogPersister.allEntries(userId: userId), on: date, cal: cal)
    }

    /// The safety gate's numeric suppression — every sibling record
    /// surface (the band, the BOOK, the plate page) already holds it;
    /// this card printed the kcal numeral to the suppressed cohort.
    private var suppressed: Bool { CohortStore.isNumericSuppressed }

    /// v25 E4 (R1) — the rest of the day: a manual weigh-in and her
    /// evening word used to vanish from the recap (it rendered food
    /// only, so a kept day read as "nothing logged").
    private var weighedIn: Bool {
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.source != "onboarding" }
        )
        return ((try? modelContext.fetch(descriptor)) ?? [])
            .contains { cal.isDate($0.loggedAt, inSameDayAs: date) }
    }

    private var feelingWord: String? {
        let key = TodayStateService.dayKey(for: date)
        return ObservationStore.valueText(
            .feeling, dayKey: key, userId: userId, in: modelContext
        ) ?? UserDefaults.standard.string(forKey: "day.reflection.\(key)")
    }

    /// The day line, in the letter's receipt grammar — one product,
    /// one way of saying "this is what the day left behind."
    private var dayLine: String {
        var parts: [String] = []
        if weighedIn { parts.append("weighed in") }
        if let feelingWord { parts.append("closed \(feelingWord)") }
        return parts.joined(separator: " · ")
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // p33's stack-at-AX law — sharing the row sheared the date
            // mid-word at AX5 on the SE ("TUESDA / Y,"); stacked, the
            // words wrap at spaces.
            let headerLayout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline))
            headerLayout {
                JeniSectionHeader(dayLabel)
                if !typeSize.isAccessibilitySize {
                    Spacer(minLength: Space.md)
                }
                Button(action: onBackToToday) {
                    Text("today")
                        .font(.custom("DMSans-SemiBold", size: 12, relativeTo: .caption))
                        .foregroundStyle(Palette.textInverse)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Palette.textPrimary))
                }
                .buttonStyle(JeniPressable())
                .accessibilityLabel("back to today")
            }

            if isFuture {
                JeniSurface {
                    JeniHeadline("still ahead.")
                }
            } else if totals.plates == 0 && dayLine.isEmpty {
                JeniSurface {
                    JeniHeadline("nothing logged this day.")
                }
            } else if totals.plates == 0 {
                // The day left a record even without plates.
                JeniSurface(radius: Radius.card) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        Text("no plates logged.")
                            .font(Typo.body)
                            .foregroundStyle(Palette.textSecondary)
                        recapDayLine
                    }
                }
            } else {
                JeniSurface(radius: Radius.card) {
                    VStack(alignment: .leading, spacing: Space.sm) {
                        plateThumbs
                        if !suppressed {
                            let kcalLayout = typeSize.isAccessibilitySize
                                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 0))
                                : AnyLayout(HStackLayout(alignment: .firstTextBaseline,
                                                         spacing: 5))
                            kcalLayout {
                                Text("\(Int(totals.kcal.rounded()).formatted())")
                                    .font(Typo.numeralDash)
                                    .foregroundStyle(Palette.textPrimary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                                Text("kcal that day")
                                    .font(Typo.numeralMeta)
                                    .foregroundStyle(Palette.textSecondary)
                            }
                            // A split is a composition claim — it draws
                            // only when every plate's composition is known.
                            if totals.splitKnown {
                                JeniMacroSplit(
                                    proteinG: Int(totals.protein.rounded()),
                                    carbsG: Int(totals.carbs.rounded()),
                                    fatG: Int(totals.fat.rounded())
                                )
                            }
                        }
                        let pairsLayout = typeSize.isAccessibilitySize
                            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                            : AnyLayout(HStackLayout(alignment: .firstTextBaseline,
                                                     spacing: Space.md))
                        pairsLayout {
                            recapPair("plates", "\(totals.plates)")
                            recapPair("protein", totals.proteinMeasured
                                ? "\(Int(totals.protein.rounded())) g" : "—")
                            if !suppressed {
                                recapPair("carbs", totals.carbsMeasured
                                    ? "\(Int(totals.carbs.rounded())) g" : "—")
                                recapPair("fat", totals.fatMeasured
                                    ? "\(Int(totals.fat.rounded())) g" : "—")
                            }
                            if !typeSize.isAccessibilitySize {
                                Spacer(minLength: 0)
                            }
                        }
                        recapDayLine
                    }
                }
            }

            // p72 — the day's own plates, named. The card summed the
            // day ("plates 16") while the page beneath it sat empty and
            // "what did I eat that day" — the question a past day is
            // opened FOR, and the category's most-repeated history ask —
            // stayed a tap and a scroll away. The BOOK's ledger grammar,
            // in place; each row opens the same repair loop.
            dayPlateRows

            Button(action: onOpenRecord) {
                HStack(spacing: 6) {
                    Text("open the book")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Palette.cocoaTertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(JKPress())
            .padding(.top, Space.md)
        }
    }

    /// The day's entries, oldest first — the spread's own order.
    private var dayEntries: [FoodLogPersister.FoodLogEntry] {
        FoodLogPersister.allEntries(userId: userId)
            .filter { cal.isDate($0.loggedAt, inSameDayAs: date) }
            .sorted { $0.loggedAt < $1.loggedAt }
    }

    @ViewBuilder private var dayPlateRows: some View {
        let entries = dayEntries
        if !entries.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { idx, plate in
                    Button {
                        JeniHaptic.tick()
                        onOpenPlate?(plate)
                    } label: {
                        recapPlateRow(plate)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(JKPress())
                    .disabled(onOpenPlate == nil)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(plateRowA11y(plate))
                    .accessibilityHint("double-tap to open, fix or remove it")
                    .accessibilityAddTraits(.isButton)
                    if idx < entries.count - 1 {
                        Rectangle()
                            .fill(Palette.textPrimary.opacity(0.07))
                            .frame(height: 0.5)
                    }
                }
            }
            .padding(.top, Space.md)
        }
    }

    /// The BOOK's ledger row grammar (title · time | facts), with its
    /// own AX law: from accessibility sizes the title takes its line.
    @ViewBuilder private func recapPlateRow(
        _ plate: FoodLogPersister.FoodLogEntry
    ) -> some View {
        let title = Text(plate.title.replacingOccurrences(of: "_", with: " ").lowercased())
            .font(.custom("DMSans-Medium", size: 15, relativeTo: .body))
            .foregroundStyle(Palette.textPrimary)
        let time = Text(plate.loggedAt.formatted(.dateTime.hour().minute()).lowercased())
            .font(Typo.statLabel)
            .foregroundStyle(Palette.cocoaTertiary)
        let facts = Text(plateFactsLine(plate))
            .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .footnote))
            .foregroundStyle(Palette.textSecondary)
            .monospacedDigit()
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 3) {
                title.fixedSize(horizontal: false, vertical: true)
                HStack(spacing: Space.sm) { time; facts }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Space.sm) {
                title.lineLimit(1)
                time
                Spacer(minLength: Space.sm)
                facts
            }
        }
    }

    /// The BOOK's facts grammar: suppression keeps protein only; an
    /// unmeasured protein prints nothing, never "0 g".
    private func plateFactsLine(_ plate: FoodLogPersister.FoodLogEntry) -> String {
        if suppressed {
            return plate.measuredProtein.map { "\(Int($0.rounded())) g protein" } ?? ""
        }
        let kcal = "\(Int(plate.kcal.rounded()).formatted()) kcal"
        guard let p = plate.measuredProtein else { return kcal }
        return "\(kcal) · \(Int(p.rounded())) g"
    }

    private func plateRowA11y(_ plate: FoodLogPersister.FoodLogEntry) -> String {
        let name = plate.title.replacingOccurrences(of: "_", with: " ").lowercased()
        let facts = plateFactsLine(plate)
        return facts.isEmpty ? name : "\(name), \(facts)"
    }

    private var dayLabel: String {
        date.formatted(.dateTime.weekday(.wide).month(.wide).day()).lowercased()
    }

    /// The receipt-grammar footer row ("weighed in · closed proud").
    @ViewBuilder private var recapDayLine: some View {
        if !dayLine.isEmpty {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(Palette.hairlineCocoa)
                    .frame(width: 28, height: 0.5)
                Text(dayLine)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.top, 2)
            .accessibilityLabel("that day: \(dayLine)")
        }
    }

    /// v25 E4 (L4) — the day's plate photographs return to Home's
    /// recap (they lived only in the book). Up to three, small,
    /// leading the numbers the way the book leads with photographs.
    @ViewBuilder private var plateThumbs: some View {
        let thumbs = totals.photoEntryIds
            .compactMap { FoodPhotoStore.photo(entryId: $0) }
            .prefix(3)
        if !thumbs.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(thumbs.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 56, height: 56)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                Spacer(minLength: 0)
            }
            .padding(.bottom, 2)
            .accessibilityHidden(true)
        }
    }

    private func recapPair(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text(label)
                .font(Typo.statLabel)
                .foregroundStyle(Palette.cocoaTertiary)
            Text(value)
                .font(.custom("DMSans-Medium", size: 13, relativeTo: .caption))
                .foregroundStyle(Palette.textPrimary.opacity(0.85))
        }
    }
}
