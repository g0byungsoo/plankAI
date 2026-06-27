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
            return PunchLine(prefix: "this is around \(kcal). wherever it lands today, it ", punch: "counts", suffix: ".")
        }
        let share = Double(kcal) / Double(ctx.kcalTarget)
        switch share {
        case ..<0.35:
            return PunchLine(prefix: "this ", punch: "fits", suffix: " easy. about a third of your day, plenty of room left.")
        case ..<0.55:
            return PunchLine(prefix: "a solid ", punch: "anchor", suffix: " meal. sits right in the middle of your day.")
        default:
            if ctx.hour < 16 {
                return PunchLine(prefix: "a fuller plate earlier ", punch: "frees up", suffix: " a lighter evening. good trade.")
            } else {
                return PunchLine(prefix: "a generous one tonight, and that's ", punch: "allowed", suffix: ". tomorrow resets \u{2661}")
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
                                  value: "\(logged) / \(ctx.proteinTargetG)g",
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
        if sodium >= 800 {
            return Consideration(ackPrefix: "salt runs a little ", ackPunch: "high", ackSuffix: " here",
                                 action: "a glass of water alongside evens it out \u{2661}")
        }
        if sugar >= 20 {
            return Consideration(ackPrefix: "a ", ackPunch: "sweeter", ackSuffix: " plate",
                                 action: "pairing it with protein keeps your energy level. no notes otherwise \u{2661}")
        }
        if satfat >= 7 {
            return Consideration(ackPrefix: "rich and ", ackPunch: "buttery", ackSuffix: "",
                                 action: "lovely as is. a veg-forward next meal balances the day \u{2661}")
        }

        // Tier 2 — macro-shape, only from measured macros.
        if carbs > protein && carbs > fat && protein < 15 && fiber < 5 {
            return Consideration(ackPrefix: "mostly ", ackPunch: "carbs", ackSuffix: " on their own",
                                 action: "a little protein or fiber next time stretches the fullness. still a yes \u{2661}")
        }
        if protein < 10 && kcal >= 350 {
            return Consideration(ackPrefix: "light on ", ackPunch: "protein", ackSuffix: " for its size",
                                 action: "an egg or some yogurt later tops it off nicely \u{2661}")
        }
        let fatKcal = Double(fat) * 9
        if kcal > 0, fatKcal / Double(kcal) > 0.55 {
            return Consideration(ackPrefix: "fat's doing most of the ", ackPunch: "work", ackSuffix: " here",
                                 action: "a lean protein beside it rounds it out \u{2661}")
        }
        return nil
    }

    // MARK: Module D — Jeni's note (always renders)

    var jeniNote: PunchLine {
        if isSafetyNet {
            let lines = ctx.isGlp1
                ? [PunchLine(prefix: "you don't need to eat much right now, you need to eat ", punch: "well", suffix: ". this counts \u{2661}")]
                : [PunchLine(prefix: "make sure you're getting ", punch: "enough", suffix: " today. your body does better fed \u{2661}"),
                   PunchLine(prefix: "this is a snack, not the whole day. eat a bit ", punch: "more", suffix: " when you can \u{2661}")]
            return pick(lines)
        }
        if ctx.isGlp1 {
            return pick([
                PunchLine(prefix: "\(protein)g of protein here is exactly what keeps your ", punch: "strength", suffix: " while the rest gets easier \u{2661}"),
                PunchLine(prefix: "appetite's quieter these days. getting protein in like this ", punch: "protects", suffix: " what matters."),
                PunchLine(prefix: "small plate, strong choice. protein first does the ", punch: "muscle", suffix: "-keeping work today."),
            ])
        }
        if protein >= 25 {
            return pick([
                PunchLine(prefix: "\(protein)g of protein before your afternoon? that's the ", punch: "move", suffix: " \u{2661}"),
                PunchLine(prefix: "ok this one ", punch: "holds", suffix: " you. you'll feel good about it in three hours."),
                PunchLine(prefix: "protein like this is the quiet reason cravings stay ", punch: "soft", suffix: " later."),
            ])
        }
        if kcal < 250 {
            return pick([
                PunchLine(prefix: "soft and ", punch: "intentional", suffix: ". when you're hungry again, just listen. no rules."),
                PunchLine(prefix: "a little moment of food. you don't have to ", punch: "earn", suffix: " the next thing \u{2661}"),
            ])
        }
        if food.items.count >= 3 {
            return pick([
                PunchLine(prefix: "look at this plate. \(firstItem) plus everything else is ", punch: "exactly", suffix: " it."),
                PunchLine(prefix: "real food, real care. this is what looking after yourself ", punch: "looks", suffix: " like \u{2661}"),
            ])
        }
        if fat >= 15 {
            return pick([
                PunchLine(prefix: "the fats in here are so ", punch: "underrated", suffix: ". steady energy, no crash."),
                PunchLine(prefix: "this'll feel really good. healthy fats slow it all down in the ", punch: "best", suffix: " way \u{2661}"),
            ])
        }
        return pick([
            PunchLine(prefix: "you ate, and you ", punch: "noticed", suffix: ". that's the whole thing today \u{2661}"),
            PunchLine(prefix: "not every plate needs to be ", punch: "optimized", suffix: ". this is just fine."),
            PunchLine(prefix: "\(firstItem) counts. soft week, soft choices, soft ", punch: "you", suffix: "."),
        ])
    }

    // MARK: Module E — provenance footnote (optional)

    var provenance: String? {
        if let lo = food.kcalLow, let hi = food.kcalHigh, (hi - lo) / 2 >= 30 {
            return "around \(kcal), give or take. close enough to trust \u{2661}"
        }
        if lowConfidence {
            return "wasn't totally sure on this one. tweak it on the last screen if it's off \u{2661}"
        }
        return "based on what's on your plate \u{00B7} ranges, not exact"
    }

    // MARK: - Deterministic pick

    private func pick(_ options: [PunchLine]) -> PunchLine {
        guard !options.isEmpty else { return PunchLine(prefix: "", punch: "", suffix: "") }
        return options[seed % options.count]
    }
}
