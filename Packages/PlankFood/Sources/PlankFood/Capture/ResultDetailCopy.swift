import Foundation

// MARK: - ResultDetailCopy
//
// Pure, deterministic copy engine for the post-scan detail slide
// ("a note from jeni"). Reads ONLY real measured fields + real user
// context — never fabricates a number. Every string is anti-shame
// (post-Ozempic 2026 register): no "bad / too much / cheat / guilty",
// no red-flag framing; a "consideration" is always paired with what's
// already working and ends on permission. One italic punch word per
// line is expressed as an explicit (prefix, punch, suffix) segment so
// the view composes it via a JeniHeroSerif-Italic run — no asterisk
// markers ship in copy.
//
// Determinism: every selection is a pure function of the scan + the
// context + a copySeed (hash of item names + kcal), so the same plate
// always shows the same note and the engine is unit-testable.
//
// Slide-1 dedup contract: satiety ("holds you ~Xh") lives on slide 1,
// so this slide carries day-fit, macro-balance shape, protein-density
// (moved off slide 1), timing, and the why-behind-a-consideration —
// it deepens, never echoes.

struct ResultDetailContext {
    /// Daily protein target in grams (1.0 g/kg, floor 70, cap 150).
    let proteinTargetG: Int
    /// Protein already logged today (before this scan), grams.
    let todayLoggedProtein: Int
    /// Daily calorie target if the user set one; 0 when unset (we then
    /// never imply a budget).
    let kcalTarget: Int
    /// GLP-1 cohort (current / past) → muscle-protection framing.
    let isGlp1: Bool
    /// Hour of day the meal was logged, 0...23.
    let hour: Int
}

/// One line with a single italic punch word. `punch` renders in
/// JeniHeroSerif-Italic; prefix/suffix in the body face.
struct PunchLine: Equatable {
    let prefix: String
    let punch: String
    let suffix: String
}

/// A labelled detail row. `progress` (0...1) drives an optional sage
/// underline bar (used by the protein-toward-target row).
struct DetailRow: Equatable, Identifiable {
    let label: String
    let value: String
    let progress: Double?
    var id: String { label }
}

/// A calm, non-alarming consideration: an acknowledgment line (with a
/// punch word) + a gentle pairing action. Never red, never stacks.
struct Consideration: Equatable {
    let ackPrefix: String
    let ackPunch: String
    let ackSuffix: String
    let action: String
}

struct ResultDetailCopy {

    let food: CapturedFood
    let ctx: ResultDetailContext

    // Convenience totals (Int, matching slide 1's rounding).
    private var kcal: Int { Int((food.totalKcal ?? 0).rounded()) }
    private var protein: Int { sum(\.proteinG) }
    private var carbs: Int { sum(\.carbsG) }
    private var fat: Int { sum(\.fatG) }
    private var fiber: Int { sum(\.fiberG) }
    private var sodium: Double { sumD(\.sodiumMg) }
    private var sugar: Double { sumD(\.sugarG) }
    private var satfat: Double { sumD(\.saturatedFatG) }

    private func sum(_ kp: KeyPath<CapturedItem, Double?>) -> Int {
        Int(food.items.compactMap { $0[keyPath: kp] }.reduce(0, +).rounded())
    }
    private func sumD(_ kp: KeyPath<CapturedItem, Double?>) -> Double {
        // nil when NO item carries the field (so threshold rules can
        // gate hard on "we actually measured this").
        let vals = food.items.compactMap { $0[keyPath: kp] }
        return vals.isEmpty ? -1 : vals.reduce(0, +)
    }

    private var firstItem: String {
        food.items.first?.name.lowercased() ?? "this"
    }

    /// Deterministic seed: stable per-plate, varies across plates.
    private var seed: Int {
        var h = Hasher()
        h.combine(kcal)
        for i in food.items { h.combine(i.name) }
        return abs(h.finalize())
    }

    private var confidence: Double { food.confidence ?? 0.85 }
    private var lowConfidence: Bool { confidence < 0.65 }

    // MARK: Safety net — overrides everything below

    /// Very low intake → never praise smallness; replace the note with
    /// a safety line and suppress detail rows + considerations. Protects
    /// restriction-risk + GLP-1 cohorts.
    var isSafetyNet: Bool { kcal > 0 && kcal < 150 }

    // MARK: Module A — day-fit (always renders)

    var dayFit: PunchLine {
        guard ctx.kcalTarget > 0 else {
            // No target set — refuse to imply a budget.
            return PunchLine(prefix: "about \(kcal) calories, ", punch: "logged", suffix: ". your record stays accurate.")
        }
        let share = Double(kcal) / Double(ctx.kcalTarget)
        // p54 — the on-medication cohort never receives an eat-less
        // instruction from a plate reading: the drug is already doing
        // the deficit, under-eating is that population's named risk,
        // and "plan a lighter evening meal" is the countdown grammar
        // in a kinder font. The share is stated; the planning is hers.
        switch share {
        case ..<0.35:
            return PunchLine(prefix: "about ", punch: "a third", suffix: " of your day. plenty of room left.")
        case ..<0.55:
            return ctx.isGlp1
                ? PunchLine(prefix: "roughly ", punch: "half", suffix: " of your day, on the record.")
                : PunchLine(prefix: "roughly ", punch: "half", suffix: " of your day. plan a lighter evening meal.")
        default:
            if ctx.isGlp1 {
                return PunchLine(prefix: "a larger meal, ", punch: "counted", suffix: ". the week matters more than one plate.")
            }
            if ctx.hour < 16 {
                return PunchLine(prefix: "a larger meal, earlier. that usually supports a ", punch: "lighter", suffix: " evening.")
            } else {
                return PunchLine(prefix: "a larger evening meal. the ", punch: "week", suffix: " matters more than one night.")
            }
        }
    }

    // MARK: Module B — crucial details (0...3 rows)

    var details: [DetailRow] {
        if isSafetyNet { return [] }
        var rows: [DetailRow] = []

        // B1 — protein toward today's target (the reborn day bar).
        if ctx.proteinTargetG > 0 {
            let logged = ctx.todayLoggedProtein + protein
            let progress = min(1.0, Double(logged) / Double(max(ctx.proteinTargetG, 1)))
            rows.append(DetailRow(label: "protein today",
                                  value: "\(logged) / \(ctx.proteinTargetG) g",
                                  progress: progress))
        }

        // B2 — macro-balance shape (reads composition, never a verdict).
        rows.append(DetailRow(label: "balance", value: balanceShape, progress: nil))

        // B3 — protein density (moved off slide 1).
        if let d = densityValue {
            rows.append(DetailRow(label: "density", value: d, progress: nil))
        }

        // B4 — timing, only when it genuinely adds something.
        if rows.count < 3, let t = timingValue {
            rows.append(DetailRow(label: "timing", value: t, progress: nil))
        }

        return Array(rows.prefix(3))
    }

    /// "protein-led" / "balanced" / "carb-forward" / "fat-forward"
    /// from each macro's calorie contribution. Descriptive, not a judgment.
    private var balanceShape: String {
        let pK = Double(protein) * 4
        let cK = Double(carbs) * 4
        let fK = Double(fat) * 9
        let total = max(pK + cK + fK, 1)
        let pPct = pK / total, cPct = cK / total, fPct = fK / total
        let spread = [pPct, cPct, fPct].max()! - [pPct, cPct, fPct].min()!
        if spread < 0.18 { return "balanced" }
        if pPct >= cPct && pPct >= fPct { return "protein-led" }
        if cPct >= fPct { return ctx.hour < 12 ? "carb-forward am" : "carb-forward" }
        return "fat-forward"
    }

    private var densityValue: String? {
        guard kcal > 0 else { return nil }
        let perHundred = Double(protein) / Double(kcal) * 100
        let rounded = (perHundred * 10).rounded() / 10
        guard rounded >= 4 else { return nil }
        return "\(String(format: "%.1f", rounded))g / 100 cal"
    }

    private var timingValue: String? {
        if ctx.hour >= 14 && ctx.hour < 17 && protein >= 20 { return "pre-afternoon" }
        if ctx.hour >= 20 && fiber >= 5 { return "evening wind-down" }
        if ctx.hour < 11 && protein >= 20 { return "strong start" }
        return nil
    }

    // MARK: Module C — gentle consideration (0 or 1; never alarming)

    var consideration: Consideration? {
        if isSafetyNet || lowConfidence { return nil }

        // Tier 1 — measured threshold fields, only when present.
        // p54 — the sodium action stated fluid advice ("extra water
        // helps") the E9 law reserves for the label's own authority,
        // and the sugar/carb actions claimed more than the satiety
        // evidence carries ("energy curve", "by hours"). Rewritten to
        // what the record supports: salt reads as water for a day,
        // protein holds.
        if sodium >= 800 {
            return Consideration(ackPrefix: "sodium runs ", ackPunch: "high", ackSuffix: " here",
                                 action: "if tomorrow's scale reads high, that's salt holding water for a day. the trend decides")
        }
        if sugar >= 20 {
            return Consideration(ackPrefix: "a ", ackPunch: "higher-sugar", ackSuffix: " plate",
                                 action: "protein alongside makes it hold longer")
        }
        if satfat >= 7 {
            return Consideration(ackPrefix: "heavier in ", ackPunch: "saturated fat", ackSuffix: "",
                                 action: "a lighter, plant-forward next meal balances the day")
        }

        // Tier 2 — macro-shape, only from measured macros.
        if carbs > protein && carbs > fat && protein < 15 && fiber < 5 {
            return Consideration(ackPrefix: "mostly ", ackPunch: "carbs", ackSuffix: ", little protein or fiber",
                                 action: "adding either makes it hold longer")
        }
        if protein < 10 && kcal >= 350 {
            return Consideration(ackPrefix: "light on ", ackPunch: "protein", ackSuffix: " for its size",
                                 action: "adding some later today keeps your floor in reach")
        }
        let fatKcal = Double(fat) * 9
        if kcal > 0, fatKcal / Double(kcal) > 0.55 {
            return Consideration(ackPrefix: "most calories here come from ", ackPunch: "fat", ackSuffix: "",
                                 action: "a lean protein beside it balances the meal")
        }
        return nil
    }

    // MARK: Module D — Jeni's note (always renders)

    var jeniNote: PunchLine {
        if isSafetyNet {
            let lines = ctx.isGlp1
                ? [PunchLine(prefix: "appetite is low. ", punch: "quality", suffix: " over quantity, and this counts.")]
                : [PunchLine(prefix: "this is below a meal's worth. steady intake protects ", punch: "energy", suffix: " and muscle."),
                   PunchLine(prefix: "a snack on the record. plan a ", punch: "full", suffix: " meal next.")]
            return pick(lines)
        }
        if ctx.isGlp1 {
            return pick([
                PunchLine(prefix: "\(protein)g of protein on a quiet appetite. that's what ", punch: "protects", suffix: " muscle while weight comes down."),
                PunchLine(prefix: "with less appetite, protein-first is the ", punch: "priority", suffix: ". this plate does it."),
                PunchLine(prefix: "small plate, ", punch: "protein-first", suffix: ". the pattern that keeps strength."),
            ])
        }
        if protein >= 25 {
            // v9 P5 — the plate reaches the muscle story (the P4
            // promotion vocabulary, one voice across surfaces).
            // p54 — "blunts later cravings. a practical win" graded
            // her plate; "for hours" claimed a duration the satiety
            // literature doesn't hand out per-plate. Report the
            // pattern, hedge the feeling.
            var lines = [
                PunchLine(prefix: "\(protein)g of protein. that tends to ", punch: "hold", suffix: " fullness."),
                PunchLine(prefix: "a protein-led start. later hunger tends to run ", punch: "quieter", suffix: "."),
                PunchLine(prefix: "a ", punch: "protein-led", suffix: " plate. the pattern that preserves muscle."),
            ]
            if ctx.proteinTargetG > 0 {
                lines.append(PunchLine(
                    prefix: "\(protein)g here. a real step toward your ",
                    punch: "floor",
                    suffix: " today."
                ))
            }
            return pick(lines)
        }
        if kcal < 250 {
            return pick([
                PunchLine(prefix: "a light plate, ", punch: "logged", suffix: ". eat again when hunger returns."),
                PunchLine(prefix: "small and ", punch: "counted", suffix: ". your day's numbers stay honest."),
            ])
        }
        if food.items.count >= 3 {
            // p54 — the "usually brings better fiber" line guessed at
            // a value this plate MEASURES (the fiber sum is two rows
            // up). One honest line instead of a hedge about a number
            // on file.
            return pick([
                PunchLine(prefix: "a ", punch: "composed", suffix: " plate: \(firstItem) and \(food.items.count - 1) more. easier to balance than single-item meals."),
            ])
        }
        if fat >= 15 {
            return pick([
                PunchLine(prefix: "\(fat)g of fat digests ", punch: "slowly", suffix: ". expect later, calmer hunger."),
                PunchLine(prefix: "higher-fat plates sit ", punch: "longer", suffix: ". later, calmer hunger."),
            ])
        }
        return pick([
            PunchLine(prefix: "logged: \(kcal) calories. consistent records make your weekly ", punch: "review", suffix: " reliable."),
            PunchLine(prefix: "counted, not ", punch: "judged", suffix: ". the trend is what your plan reads."),
            PunchLine(prefix: "\(firstItem), on the ", punch: "record", suffix: ". patterns show after a few days."),
        ])
    }

    // MARK: Module E — provenance footnote (optional)

    var provenance: String? {
        // PRINTED TRUTH SKIPS THE HEDGES ENTIRELY. Both branches below
        // describe a model judging a photograph — a kcal range it
        // invented, or a confidence it assigned itself. Neither is what
        // happened when the numbers were transcribed off a package, so
        // neither may speak for one. `isPrintedTruth` has carried this
        // law since E8.1 with no caller; this is its first.
        if food.source.isPrintedTruth { return food.source.provenanceLine }
        if let lo = food.kcalLow, let hi = food.kcalHigh, (hi - lo) / 2 >= 30 {
            return "estimate: about \(kcal), within a range. edit anything that looks off"
        }
        if lowConfidence {
            return "lower confidence on this one. worth a quick check of the items"
        }
        // Was a hardcoded "estimated from the photo", said to typed
        // sentences and restaurant estimates too. The door knows.
        return food.source.provenanceLine
    }

    // MARK: - Deterministic pick

    private func pick(_ options: [PunchLine]) -> PunchLine {
        guard !options.isEmpty else { return PunchLine(prefix: "", punch: "", suffix: "") }
        return options[seed % options.count]
    }
}
