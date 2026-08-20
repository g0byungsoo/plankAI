import SwiftUI

// MARK: - V8Node — one entry in the consult
//
// The flow is a single ordered walk of nodes: talk beats (the paper
// conversation), chapters (ink declarations) and structured moments
// (demo, gate, signature, health, hold). The router is pure over the
// store, so cohort branches re-resolve live — the OV5 law, kept.

enum V8Node: Identifiable {
    case talk(V8Beat)
    case chapter(V8ChapterKind)
    case structured(V8StructuredKind)

    var id: String {
        switch self {
        case .talk(let beat): return beat.id
        case .chapter(let kind): return "ch_\(kind.rawValue)"
        case .structured(let kind): return "s_\(kind.rawValue)"
        }
    }
}

// MARK: - The script

enum V8Script {

    // MARK: registry

    static func node(for id: String, store: OV5Store) -> V8Node? {
        switch id {
        case "ch_arrival": return .chapter(.arrival)
        case "ch_mirror": return .chapter(.mirror)
        case "ch_evidence": return .chapter(.evidence)
        case "ch_file": return .chapter(.file)
        case "s_snapDemo": return .structured(.snapDemo)
        case "s_safetyGate": return .structured(.safetyGate)
        case "s_signature": return .structured(.signature)
        case "s_healthKit": return .structured(.healthKit)
        case "s_hold": return .structured(.hold)
        default: return beat(for: id).map { .talk($0) }
        }
    }

    // MARK: router (pure; the OV5 branch logic, re-ordered per v8 law)

    static func next(after id: String, store: OV5Store) -> String? {
        let clinic = store.door == "clinic"
        switch id {
        case "ch_arrival": return "door"
        case "door":
            return clinic ? "clinicCode" : "hello"
        case "clinicCode":
            return clinic ? "clinicWelcome" : "hello"
        case "clinicWelcome": return "name"
        case "hello": return "name"
        case "name": return clinic ? "glp1Status" : "outcome"
        case "outcome": return "history"
        case "history": return "foodRelationship"
        case "foodRelationship": return "ch_mirror"
        case "ch_mirror": return "glp1Status"

        // ONE cohort question on both doors — except the CURRENT
        // cohort on the consumer door, whose consult sets up her
        // medication in four short beats (v24 THE REGIMEN,
        // docs/app_v24 §7; supersedes the v8 "regimen depth lives
        // post-purchase" call for this cohort only). The clinic
        // door still skips everything: her clinician's plan
        // arrives at connect — nothing to configure.
        case "glp1Status":
            if clinic { return "numbersLine" }
            return store.glp1Status == "current" ? "medRoute" : "demoIntro"
        case "medRoute":
            return "medOne"
        case "medOne":
            // No product → no ladder to offer; the rhythm still
            // matters.
            if store.medProduct.isEmpty || store.medProduct == "not_sure"
                || store.medProduct == "other" {
                return medCadenceIsDaily(store) ? "medHour" : "medDay"
            }
            return "medDose"
        case "medDose":
            return medCadenceIsDaily(store) ? "medHour" : "medDay"
        case "medDay":
            return "medHour"
        case "medHour":
            return "demoIntro"
        case "demoIntro": return "s_snapDemo"
        case "s_snapDemo": return "ch_evidence"
        case "ch_evidence": return "numbersLine"

        case "numbersLine": return "gender"
        case "gender": return "age"
        case "age": return "height"
        case "height": return "weight"
        case "weight": return clinic ? "goalDirection" : "weightTrend"
        case "weightTrend": return "goalDirection"
        case "goalDirection":
            switch store.goalDirection {
            case "maintain", "maintain_kept": return "movement"
            default: return "goalWeight"
            }
        case "goalWeight": return "movement"
        case "movement": return "sleep"
        case "sleep": return "stress"
        case "stress": return "medication"
        case "medication": return "s_safetyGate"
        case "s_safetyGate":
            if store.persona == .male {
                return clinic ? "ch_file" : "attribution"
            }
            return "hormonal"
        case "hormonal": return clinic ? "ch_file" : "attribution"
        case "attribution": return "ch_file"
        case "ch_file": return "s_signature"
        case "s_signature": return "s_healthKit"
        case "s_healthKit": return "s_hold"
        case "s_hold": return nil
        default: return nil
        }
    }

    /// v24 — the cadence the picked product implies (daily pills +
    /// daily injectables skip the weekday beat). Route "pills"
    /// without a product is daily; everything else defaults weekly.
    static func medCadenceIsDaily(_ store: OV5Store) -> Bool {
        if let product = MedicationCatalog.product(id: store.medProduct) {
            return product.defaultCadence == .daily
        }
        return store.medRoute == "pills"
    }

    static func orderedIDs(store: OV5Store) -> [String] {
        var out: [String] = []
        var cursor: String? = "ch_arrival"
        var guardCount = 0
        while let id = cursor, guardCount < 80 {
            out.append(id)
            cursor = next(after: id, store: store)
            guardCount += 1
        }
        return out
    }

    static func fraction(at id: String, store: OV5Store) -> Double {
        let walk = orderedIDs(store: store)
        guard let idx = walk.firstIndex(of: id), walk.count > 1 else { return 0 }
        return Double(idx) / Double(walk.count - 1)
    }

    // MARK: talk beats

    // Small helpers keep the script readable.
    private static func L(_ t: String, _ i: [String] = []) -> V8Line { V8Line(t, italic: i) }

    static func beat(for id: String) -> V8Beat? {
        switch id {

        // MARK: act 0 — the door (docs/onboarding_v8 §9.3)

        case "door":
            return V8Beat(
                "door",
                lines: { _ in [L("quick check. are you here through a clinic?")] },
                input: { _ in .options([
                    V8Option("consumer", "no, i'm here on my own"),
                    V8Option("clinic", "i have a clinician code"),
                ]) },
                preselected: { s in s.door.isEmpty ? [] : [s.door] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.door = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    if v == "consumer" {
                        return [L("perfect. let's get into it.")]
                    }
                    return []
                }
            )

        case "clinicCode":
            return V8Beat(
                "clinicCode",
                lines: { _ in [V8Line("what's the code your clinic gave you?",
                                      citation: "it links your plan to your care team. you control what they see.")] },
                input: { _ in .code(placeholder: "your code", skip: "i don't have a code") },
                commit: { _, _ in },
                ack: { store, payload in
                    if case .text(let code) = payload, code.isEmpty {
                        return [L("no problem. we'll do this the regular way, and you can add a code later in settings.")]
                    }
                    return [L("connected to \(store.clinicOrgName.isEmpty ? "your clinic" : store.clinicOrgName.lowercased()).", ["connected"]),
                            L("they see what you choose to share. you can change that anytime.")]
                }
            )

        case "clinicWelcome":
            return V8Beat(
                "clinicWelcome",
                lines: { store in
                    let org = store.clinicOrgName.isEmpty ? "your clinic" : store.clinicOrgName.lowercased()
                    return [
                        L("you're set up with \(org)."),
                        L("your clinician leads the medical side. i handle the everyday: food, movement, the numbers between visits.", ["everyday:"]),
                    ]
                }
            )

        // MARK: act i — the consult opens

        case "hello":
            return V8Beat(
                "hello",
                // She said hello on the arrival, three seconds ago.
                // This beat's real job is the expectation — the line
                // that keeps people from abandoning a form of unknown
                // length — so it opens with that.
                lines: { _ in [
                    L("quick questions first, then your plan. takes about 4 minutes.", ["4 minutes."]),
                ] }
            )

        case "name":
            return V8Beat(
                "name",
                lines: { _ in [L("first. what should i call you?")] },
                input: { _ in .name(placeholder: "your name", skip: "i'd rather not say") },
                preselected: { _ in [] },
                commit: { store, payload in
                    if case .text(let name) = payload { store.name = name }
                },
                ack: { _, payload in
                    if case .text(let name) = payload, !name.isEmpty {
                        return [L("\(name.lowercased()). nice to meet you.", [name.lowercased() + "."])]
                    }
                    return [L("no problem.")]
                }
            )

        case "outcome":
            return V8Beat(
                "outcome",
                lines: { _ in [L("what do you want to change most?", ["change"])] },
                input: { _ in .quiz([
                    V8QuizItem(glyph: .mirrorSelf, option: V8Option("myself", "feel like myself again")),
                    V8QuizItem(glyph: .quietWave, option: V8Option("noise", "quiet around food")),
                    V8QuizItem(glyph: .energyRise, option: V8Option("energy", "steady energy")),
                    V8QuizItem(glyph: .hanger, option: V8Option("clothes", "clothes that fit right")),
                    V8QuizItem(glyph: .holdLine, option: V8Option("keep", "keep off what i lost")),
                ]) },
                preselected: { s in s.outcome.isEmpty ? [] : [s.outcome] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.outcome = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "myself":
                        return [L("makes sense. the scale is only one part of that.")]
                    case "noise":
                        return [V8Line("got it. the constant food chatter is the main thing we work on.",
                                       italic: ["main"], figure: .noiseWave)]
                    case "energy":
                        return [L("good one. energy usually improves first, before the scale moves.", ["first,"])]
                    case "clothes":
                        return [L("concrete goal. clothes show change before the scale does.")]
                    case "keep":
                        return [L("the hardest part, honestly. it's exactly what this plan is built for.", ["exactly"])]
                    default: return []
                    }
                }
            )

        case "history":
            return V8Beat(
                "history",
                lines: { _ in [L("have you tried this before?")] },
                input: { _ in .quiz([
                    V8QuizItem(glyph: .tallyNone, option: V8Option("none", "first real plan")),
                    V8QuizItem(glyph: .tallyTwo, option: V8Option("one_two", "once or twice")),
                    V8QuizItem(glyph: .tallyFive, option: V8Option("three_five", "3 to 5 times")),
                    V8QuizItem(glyph: .tallyMany, option: V8Option("many", "lost count")),
                ]) },
                preselected: { s in s.priorAttempts.isEmpty ? [] : [s.priorAttempts] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.priorAttempts = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "none":
                        return [L("clean start. good.")]
                    case "one_two":
                        return [L("then you know week three is where it usually breaks. we plan for that.", ["plan"])]
                    case "three_five":
                        return [V8Line("3 to 5 tries isn't a willpower problem. you were missing a system.",
                                       italic: ["system."], figure: .reboundCurve)]
                    case "many":
                        return [V8Line("then you're already good at starting. the plan handles the keeping-going part.",
                                       italic: ["starting."], figure: .reboundCurve)]
                    default: return []
                    }
                }
            )

        case "foodRelationship":
            return V8Beat(
                "foodRelationship",
                lines: { _ in [L("and your relationship with food?", ["food?"])] },
                input: { _ in .quiz([
                    V8QuizItem(glyph: .plateMorsel, option: V8Option("fuel", "fuel")),
                    V8QuizItem(glyph: .warmBowl, option: V8Option("comfort", "comfort")),
                    V8QuizItem(glyph: .sharedPlates, option: V8Option("love", "love")),
                    V8QuizItem(glyph: .checklist, option: V8Option("control", "control")),
                    V8QuizItem(glyph: .tangle, option: V8Option("complicated", "complicated")),
                ]) },
                preselected: { s in s.foodRelationship.isEmpty ? [] : [s.foodRelationship] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.foodRelationship = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "fuel":
                        return [L("practical. the plan stays practical too.")]
                    case "comfort":
                        return [L("honest answer. the plan won't take that away.")]
                    case "love":
                        return [L("good. plans that ban good food fail fast. this one doesn't.", ["doesn't."])]
                    case "control":
                        return [L("then you'll like the numbers here.")]
                    case "complicated":
                        return [V8Line("fair. constant food thoughts have a name: food cue reactivity. it's biology, not discipline.",
                                       italic: ["biology,"], citation: "food-cue reactivity · hayashi 2023", figure: .noiseWave)]
                    default: return []
                    }
                }
            )

        // MARK: act ii — method + cohort

        case "glp1Status":
            return V8Beat(
                "glp1Status",
                lines: { _ in [L("one important question. are you using a weight loss medication?", ["important"])] },
                input: { _ in .options([
                    V8Option("none", "no"),
                    V8Option("current", "yes, i'm on one"),
                    V8Option("past", "i was. not anymore"),
                    V8Option("considering", "thinking about it"),
                    V8Option("prefer_not_say", "prefer not to say"),
                ]) },
                preselected: { s in s.glp1Status.isEmpty ? [] : [s.glp1Status] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.glp1Status = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "current":
                        return [L("good to know. let's set it up. thirty seconds, all skippable.", ["skippable."])]
                    case "past":
                        return [L("important info. the months after stopping are the risky part. the plan covers them.", ["covers"])]
                    case "considering":
                        return [L("either way works. the daily part is the same with or without it.")]
                    case "none":
                        return [L("got it. we do it with food, movement, and routine.", ["routine."])]
                    default:
                        return [L("no problem. everything works either way.")]
                    }
                }
            )

        // v24 THE REGIMEN — the consult's medication beats
        // (docs/app_v24 §7). Current cohort, consumer door only.
        // Every beat has an out; the completion bridge builds ONE
        // regimen version from the answers. Register: plain,
        // everyday, clinic-safe — a nurse asking, not a form.

        case "medRoute":
            return V8Beat(
                "medRoute",
                lines: { _ in [L("shots, or pills?")] },
                caption: { _ in "so your days match your rhythm." },
                input: { _ in .options([
                    V8Option("shots", "shots"),
                    V8Option("pills", "pills"),
                    V8Option("not_sure", "not sure yet"),
                ]) },
                preselected: { s in s.medRoute.isEmpty ? [] : [s.medRoute] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.medRoute = v }
                }
            )

        case "medOne":
            return V8Beat(
                "medOne",
                lines: { s in
                    s.medRoute == "pills"
                        ? [L("which pill?")]
                        : [L("which one?")]
                },
                caption: { _ in "compounded counts the same here. change it any time." },
                input: { s in
                    let route: MedicationProduct.Route =
                        s.medRoute == "pills" ? .oral : .injection
                    var options = MedicationCatalog.products(route: route).map {
                        V8Option($0.id, $0.displayName)
                    }
                    options.append(V8Option("other", "something else"))
                    options.append(V8Option("not_sure", "not sure yet"))
                    return .options(options)
                },
                preselected: { s in s.medProduct.isEmpty ? [] : [s.medProduct] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.medProduct = v }
                }
            )

        case "medDose":
            return V8Beat(
                "medDose",
                lines: { _ in [L("your current dose, if you know it.")] },
                caption: { _ in "your pen knows. you can fix this any time." },
                input: { s in
                    guard let product = MedicationCatalog.product(id: s.medProduct)
                    else { return .chips([V8Option("not_sure", "not sure")]) }
                    var chips = product.doseLadder.map {
                        V8Option(
                            MedicationProduct.doseWord($0),
                            "\(MedicationProduct.doseWord($0)) \(product.doseUnit)"
                        )
                    }
                    chips.append(V8Option("not_sure", "not sure"))
                    return .chips(chips)
                },
                preselected: { s in s.medDose.isEmpty ? [] : [s.medDose] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.medDose = v }
                }
            )

        case "medDay":
            return V8Beat(
                "medDay",
                lines: { _ in [L("which day is your shot, usually?")] },
                caption: { _ in "your week shapes itself around it." },
                input: { _ in .weekday(skip: "not settled yet") },
                preselected: { s in s.shotDay.isEmpty ? [] : [s.shotDay] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.shotDay = v }
                }
            )

        case "medHour":
            return V8Beat(
                "medHour",
                lines: { s in
                    s.medRoute == "pills"
                        ? [L("want a quiet reminder, mornings?")]
                        : [L("want a quiet reminder on the day?")]
                },
                caption: { _ in "one nudge. your medication is never named in it." },
                input: { _ in .options([
                    V8Option("morning", "morning"),
                    V8Option("midday", "midday"),
                    V8Option("evening", "evening"),
                    V8Option("none", "no reminders, please"),
                ]) },
                preselected: { s in s.medHour.isEmpty ? [] : [s.medHour] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.medHour = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    return v == "none"
                        ? [L("quiet it is. you can turn them on any time.")]
                        : [L("done. that's the medication part, handled.", ["handled."])]
                }
            )

        case "demoIntro":
            return V8Beat(
                "demoIntro",
                lines: { _ in [
                    L("enough questions for a sec."),
                    L("let me show you something.", ["show"]),
                ] }
            )

        case "numbersLine":
            return V8Beat(
                "numbersLine",
                lines: { _ in [
                    L("now the quick numbers.", ["quick"]),
                    L("they set your calories, protein, and pace. two minutes."),
                ] }
            )

        case "gender":
            return V8Beat(
                "gender",
                lines: { _ in [L("which formula should i use for your calorie math?")] },
                caption: { _ in "the equation differs by body. this sets nothing else." },
                input: { _ in .chips([
                    V8Option("female", "female"),
                    V8Option("male", "male"),
                    V8Option("nonbinary", "non-binary"),
                    V8Option("private", "prefer not to say"),
                ]) },
                preselected: { s in s.gender.isEmpty ? [] : [s.gender] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.gender = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    if v == "nonbinary" || v == "private" {
                        return [L("we'll use the more conservative equation. you can change this anytime.")]
                    }
                    return []
                }
            )

        case "age":
            return V8Beat(
                "age",
                lines: { _ in [L("how old are you?")] },
                input: { s in .ruler(V8RulerSpec(
                    range: 16...80,
                    step: 1,
                    majorEvery: 5,
                    initial: Double(s.ageYears),
                    readout: { v, _ in "\(Int(v))" },
                    readoutUnit: { _ in "years" }
                )) },
                commit: { store, payload in
                    if case .value(let v, _) = payload { store.ageYears = Int(v) }
                }
            )

        case "height":
            return V8Beat(
                "height",
                lines: { _ in [L("your height?")] },
                input: { s in
                    let cm = s.heightCm
                    let usesFtIn = s.usesFtIn
                    return .ruler(V8RulerSpec(
                        range: V8Scale.heightIn,
                        step: 1,
                        majorEvery: 12,
                        initial: usesFtIn ? (cm / 2.54).rounded() : cm.rounded(),
                        unitTabs: ["ft · in", "cm"],
                        initialUnit: usesFtIn ? 0 : 1,
                        unitRanges: [V8Scale.heightIn, V8Scale.heightCm],
                        unitSteps: [1, 1],
                        unitMajors: [12, 10],
                        readout: { v, unit in
                            if unit == 0 {
                                let inches = Int(v.rounded())
                                return "\(inches / 12)'\(inches % 12)\""
                            }
                            return "\(Int(v.rounded()))"
                        },
                        readoutUnit: { unit in unit == 0 ? nil : "cm" },
                        convert: { v, from, to in
                            guard from != to else { return v }
                            return to == 1 ? (v * 2.54).rounded() : (v / 2.54).rounded()
                        }
                    ))
                },
                commit: { store, payload in
                    if case .value(let v, let unit) = payload {
                        store.usesFtIn = unit == 0
                        store.heightCm = unit == 0 ? v * 2.54 : v
                    }
                }
            )

        case "weight":
            return V8Beat(
                "weight",
                lines: { _ in [L("and your weight, today?", ["today?"])] },
                caption: { _ in "just a starting point." },
                input: { s in
                    let kg = s.currentWeightKg
                    let usesLb = s.usesLb
                    return .ruler(V8RulerSpec(
                        range: V8Scale.weightLb,
                        step: 1,
                        majorEvery: 10,
                        initial: usesLb ? (kg * 2.20462).rounded() : kg.rounded(),
                        unitTabs: ["lb", "kg"],
                        initialUnit: usesLb ? 0 : 1,
                        unitRanges: [V8Scale.weightLb, V8Scale.weightKg],
                        unitSteps: [1, 1],
                        unitMajors: [10, 5],
                        readout: { v, _ in "\(Int(v.rounded()))" },
                        readoutUnit: { unit in unit == 0 ? "lb" : "kg" },
                        convert: { v, from, to in
                            guard from != to else { return v }
                            return to == 1 ? (v / 2.20462).rounded() : (v * 2.20462).rounded()
                        }
                    ))
                },
                commit: { store, payload in
                    if case .value(let v, let unit) = payload {
                        store.usesLb = unit == 0
                        store.currentWeightKg = unit == 0 ? v / 2.20462 : v
                    }
                },
                ack: { _, _ in
                    [L("logged. connect health later and you'll never type it again.", ["never"])]
                }
            )

        case "weightTrend":
            return V8Beat(
                "weightTrend",
                lines: { _ in [L("lately, it's been…", ["lately,"])] },
                // The answer to this question IS a shape, so it is
                // drawn (founder: some screens need more decoration).
                input: { _ in .quiz([
                    V8QuizItem(glyph: .trendUp,
                               option: V8Option("climbing", "climbing")),
                    V8QuizItem(glyph: .trendFlat,
                               option: V8Option("stable", "about the same")),
                    V8QuizItem(glyph: .trendDown,
                               option: V8Option("declining", "slowly coming down")),
                    V8QuizItem(glyph: .trendCycle,
                               option: V8Option("cycling", "up and down")),
                ]) },
                preselected: { s in s.weightTrend.isEmpty ? [] : [s.weightTrend] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.weightTrend = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "cycling":
                        return [L("up and down usually means the last approach was too aggressive. this one is steadier.", ["steadier."])]
                    case "climbing":
                        return [L("good timing then. trends are easiest to turn early.", ["early."])]
                    default: return []
                    }
                }
            )

        case "goalDirection":
            return V8Beat(
                "goalDirection",
                lines: { _ in [L("what are we working toward?", ["toward?"])] },
                input: { s in
                    let lose = V8Option("lose", "lose weight")
                    let maintain = V8Option("maintain", "maintain where i am")
                    let kept = V8Option("maintain_kept", "keep off what i've lost")
                    let recomp = V8Option("recomp", "tone up and get stronger")
                    return .options(s.isPastGlp1
                        ? [kept, lose, maintain, recomp]
                        : [lose, maintain, kept, recomp])
                },
                preselected: { s in s.goalDirection.isEmpty ? [] : [s.goalDirection] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.goalDirection = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "maintain", "maintain_kept":
                        return [L("keeping steady is its own skill. the plan covers it too.", ["skill."])]
                    case "recomp":
                        return [L("then we focus on muscle and protein more than the scale.", ["muscle"])]
                    default: return []
                    }
                }
            )

        case "goalWeight":
            return V8Beat(
                "goalWeight",
                lines: { _ in [L("where would you like to land?", ["land?"])] },
                input: { s in
                    let usesLb = s.usesLb
                    let current = usesLb ? (s.currentWeightKg * 2.20462).rounded() : s.currentWeightKg.rounded()
                    let seeded = s.goalWeightKg > 0 ? s.goalWeightKg : s.currentWeightKg * 0.9
                    return .ruler(V8RulerSpec(
                        range: V8Scale.weightLb,
                        step: 1,
                        majorEvery: 10,
                        initial: usesLb ? (seeded * 2.20462).rounded() : seeded.rounded(),
                        anchor: current,
                        unitTabs: ["lb", "kg"],
                        initialUnit: usesLb ? 0 : 1,
                        cta: "set it",
                        unitRanges: [V8Scale.weightLb, V8Scale.weightKg],
                        unitSteps: [1, 1],
                        unitMajors: [10, 5],
                        unitAnchors: [
                            (s.currentWeightKg * 2.20462).rounded(),
                            s.currentWeightKg.rounded(),
                        ],
                        readout: { v, _ in "\(Int(v.rounded()))" },
                        readoutUnit: { unit in unit == 0 ? "lb" : "kg" },
                        convert: { v, from, to in
                            guard from != to else { return v }
                            return to == 1 ? (v / 2.20462).rounded() : (v * 2.20462).rounded()
                        }
                    ))
                },
                commit: { store, payload in
                    if case .value(let v, let unit) = payload {
                        store.goalWeightKg = unit == 0 ? v / 2.20462 : v
                    }
                },
                ack: { store, _ in
                    let delta = store.deltaKg
                    guard delta >= 1 else {
                        return [L("close already. we keep it steady from here.")]
                    }
                    // p55 — the figure speaks her unit too (it said
                    // "−29 lb" beside a sentence saying "13 kg").
                    let distance = store.deltaWords
                    let weeks = ProjectionMath.projectedWeeks(
                        currentKg: store.currentWeightKg,
                        goalKg: store.goalWeightKg,
                        paceKey: UserDefaults.standard.string(forKey: ProjectionMath.paceDefaultsKey)
                    )
                    if let weeks {
                        return [V8Line("\(distance). at a safe pace, that's about \(weeks) weeks. an estimate, not a promise.",
                                       italic: ["estimate,"], citation: "calibrated to acsm 0.5-1%/wk",
                                       figure: .projection(deltaText: distance, weeks: weeks))]
                    }
                    return [V8Line("\(distance), at a pace you can actually keep.",
                                   italic: ["actually"], citation: "calibrated to acsm 0.5-1%/wk",
                                   figure: .projection(deltaText: distance, weeks: nil))]
                }
            )

        case "movement":
            return V8Beat(
                "movement",
                lines: { _ in [L("how does movement fit, most weeks?")] },
                input: { _ in .chips([
                    V8Option("barely", "barely, honestly"),
                    V8Option("walks", "walks here and there"),
                    V8Option("regular_ish", "regular-ish"),
                    V8Option("very_active", "very active"),
                ]) },
                preselected: { s in s.movementBaseline.isEmpty ? [] : [s.movementBaseline] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.movementBaseline = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    if v == "barely" {
                        return [L("honest answer, which is what works. we start where you actually are.", ["actually"])]
                    }
                    return []
                }
            )

        case "sleep":
            return V8Beat(
                "sleep",
                lines: { _ in [L("how much sleep, honestly?", ["honestly?"])] },
                input: { _ in .chips([
                    V8Option("under5", "under 5 hours"),
                    V8Option("five6", "5 to 6"),
                    V8Option("six7", "6 to 7"),
                    V8Option("seven8", "7 to 8"),
                    V8Option("eightPlus", "8 or more"),
                ]) },
                preselected: { s in s.sleepHours.isEmpty ? [] : [s.sleepHours] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.sleepHours = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    if v == "under5" || v == "five6" {
                        return [L("noted. short sleep raises appetite, so the plan accounts for it.", ["accounts"])]
                    }
                    return []
                }
            )

        case "stress":
            return V8Beat(
                "stress",
                lines: { _ in [L("and stress?")] },
                input: { _ in .chips([
                    V8Option("low", "low"),
                    V8Option("manageable", "manageable"),
                    V8Option("heavy", "heavy"),
                    V8Option("overwhelmed", "overwhelmed"),
                ]) },
                preselected: { s in s.stressLevel.isEmpty ? [] : [s.stressLevel] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.stressLevel = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    if v == "heavy" || v == "overwhelmed" {
                        return [L("then the plan eases up on the rough days. it adapts to you.", ["adapts"])]
                    }
                    return []
                }
            )

        case "medication":
            return V8Beat(
                "medication",
                lines: { _ in [L("any blood-sugar medication?")] },
                caption: { _ in "changes how we pace you. nothing else." },
                input: { _ in .options([
                    V8Option("insulin_or_sulfonylurea", "insulin, or a daily pill for blood sugar"),
                    V8Option("other_glucose", "another blood-sugar medication"),
                    V8Option("none", "no"),
                    V8Option("prefer_not_say", "prefer not to say"),
                ]) },
                preselected: { s in s.medicationStatus.isEmpty ? [] : [s.medicationStatus] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.medicationStatus = v }
                },
                ack: { _, _ in
                    [L("last medical bit. thirty seconds, for safety.", ["safety."])]
                }
            )

        // MARK: act iv — the part nobody asks

        case "hormonal":
            return V8Beat(
                "hormonal",
                lines: { _ in [L("where is your body, hormonally?", ["hormonally?"])] },
                caption: { _ in "this sets real floors in your plan. answer or don't, both fine." },
                input: { _ in .chips([
                    V8Option("cycling", "cycling regularly"),
                    V8Option("irregular", "irregular cycle"),
                    V8Option("postpartum", "postpartum"),
                    V8Option("perimenopause", "perimenopause"),
                    V8Option("postmenopause", "postmenopause"),
                    V8Option("prefer_not_say", "prefer not to say"),
                ]) },
                preselected: { s in s.hormonalStage.isEmpty ? [] : [s.hormonalStage] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.hormonalStage = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "perimenopause", "postmenopause":
                        return [L("noted. the plan uses the gentler pace your body needs here.", ["gentler"])]
                    case "postpartum":
                        return [L("noted. the pace stays protective here.", ["protective."])]
                    default: return []
                    }
                }
            )

        case "attribution":
            return V8Beat(
                "attribution",
                lines: { _ in [L("quick one for our team: where'd you find us?")] },
                input: { _ in .chips([
                    V8Option("tiktok", "tiktok"),
                    V8Option("instagram", "instagram"),
                    V8Option("friend", "a friend told me"),
                    V8Option("app_store", "app store"),
                    V8Option("google", "google"),
                    V8Option("other", "somewhere else"),
                ]) },
                preselected: { s in s.acquisitionSource.isEmpty ? [] : [s.acquisitionSource] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.acquisitionSource = v }
                }
            )

        default:
            return nil
        }
    }

    // MARK: chapter content

    static func chapterContent(_ kind: V8ChapterKind, store: OV5Store) -> V8ChapterContent {
        switch kind {
        case .arrival:
            return V8ChapterContent(
                // THE HERO, researched (2026-08-07). Four findings
                // decided it:
                //
                //  1. "i'm jeni." was a DUPLICATE — the very next beat
                //     opens "hi, i'm jeni.", about three seconds later.
                //     The mark above already says whose room this is.
                //     Cutting it spends the whole hero on the value and
                //     keeps the block at two lines (the demo's size).
                //  2. Our funnel: 31% never advance past this screen,
                //     and those who do advance in a MEDIAN OF 6s. The
                //     line gets six seconds, so it must be plain on
                //     first read. An aphorism ("lose it for good") is
                //     a slogan, and §9.1 of the direction bans exactly
                //     that: everyday, succinct, not poetic.
                //  3. The category anchors durability — Noom "build
                //     healthy habits that last", Simple "a healthy body
                //     for life". Table stakes, so say it PLAINLY and
                //     let the demo do the differentiating (Cal AI's
                //     real lever is perceived effort, which our device
                //     shows rather than claims).
                //  4. Screen one is a TRUST surface, not a promise
                //     surface (locked research: front-loaded claims
                //     read as brand claims and suppress trust; our
                //     TikTok-acquired cohort needs more scaffolding,
                //     not louder pitch). So: the job to be done, in
                //     the user's own words, and nothing louder.
                //
                //  5. THE B2B TEST (founder, and the deciding one).
                //     This screen is the front door for clinic
                //     patients too, and "lose the weight" is consumer
                //     weight-loss language — narrow for someone sent
                //     here by a clinician for metabolic care. The line
                //     has to be universal (§3 of the direction).
                //
                // So: not a promise about the outcome, a statement
                // about how the plan is BUILT — the one thing that is
                // never a claim, and the exact thing a clinic is
                // buying (adherence; cf. the jama 2025 discontinuation
                // evidence the consult cites). "keep" carries both
                // halves at once: keep the plan, keep the result.
                // One line, so the demo takes the rest of the page.
                //  6. THE GREETING STAYS (founder, and right). The
                //     mark is a logo; "hi, i'm jeni." is a PERSON, and
                //     the whole consult that follows only works if you
                //     have met her. It also belongs on the one screen
                //     every visitor sees — a third never reach the
                //     next beat. So the duplicate died at the OTHER
                //     end: the hello beat below no longer re-greets.
                //  7. IT HAS TO READ AS ONE UTTERANCE (founder). With
                //     the greeting restored, "hi, i'm jeni." followed
                //     by "a plan you can keep." is a person saying
                //     hello and then a HEADLINE answering — two stubs,
                //     not a sentence. Read the two lines aloud and the
                //     voice breaks between them. The statement moves
                //     into first person (the founder's own verb, from
                //     "i build body transformations that last"), so
                //     the greeting and the declaration are one thing
                //     she says. The registers still differ — she
                //     speaks small, the promise lands large.
                greeting: "hi, i'm jeni.",
                greetingItalic: ["jeni."],
                lines: [
                    // The break is authored, not left to the wrap:
                    // measured at 34pt it fell as "i build plans you /
                    // can keep.", splitting the phrase mid-verb. A
                    // display line breaks where the sentence does.
                    L("i help you lose weight,\nand keep it off.", ["keep it off."]),
                ],
                cta: "begin",
                secondary: "i already have an account",
                display: true
            )

        case .mirror:
            var lines: [V8Line] = []
            let name = store.name.lowercased()
            let outcomes: [String: String] = [
                "myself": "you want to feel like yourself again.",
                "noise": "you want food to take up less headspace.",
                "energy": "you want steady energy through the day.",
                "clothes": "you want your clothes to fit right.",
                "keep": "you want to keep the weight off.",
            ]
            if let o = outcomes[store.outcome] {
                lines.append(V8Line(name.isEmpty ? o : "\(name). \(o)", italic: name.isEmpty ? [] : ["\(name)."]))
            }
            switch store.priorAttempts {
            case "many", "three_five":
                lines.append(L("you've done the starting part before. what was missing is a system.", ["system."]))
            case "one_two":
                lines.append(L("you've tried before. this time the plan does more of the work.", ["plan"]))
            default:
                lines.append(L("first real plan. let's do it properly.", ["properly."]))
            }
            lines.append(L("none of this is a willpower problem.", ["willpower"]))
            lines.append(L("here's how i work.", ["how"]))
            return V8ChapterContent(
                eyebrow: "what we know so far",
                lines: lines,
                cta: "show me",
                display: true
            )

        case .evidence:
            var pages: [V8EvidencePage] = []
            if store.isCurrentGlp1 {
                pages.append(V8EvidencePage(
                    headline: "the weight you lose should be fat, not muscle.",
                    headlineItalic: ["fat,"],
                    caption: "on medication, appetite drops and protein drops with it. your plan sets a protein target and holds it.",
                    citation: "lean-mass findings · nejm step 1",
                    figure: .muscleBar
                ))
            } else if store.isPastGlp1 {
                pages.append(V8EvidencePage(
                    headline: "stopping is normal. regaining doesn't have to be.",
                    headlineItalic: ["normal."],
                    caption: "about half of users stop within the first year. what protects the result is the daily routine. that's what we build.",
                    citation: "discontinuation data · jama 2025",
                    figure: .halfDots
                ))
            } else {
                pages.append(V8EvidencePage(
                    headline: "food noise is real, measurable biology.",
                    headlineItalic: ["biology."],
                    caption: "constant food thoughts have a name: food cue reactivity. the plan is built to turn it down.",
                    citation: "food-cue reactivity · hayashi 2023",
                    figure: .noiseWave
                ))
            }
            pages.append(V8EvidencePage(
                headline: "more protein, same calories, more muscle kept.",
                headlineItalic: ["muscle"],
                caption: "your protein target comes from your body weight. the plan holds it while you lose.",
                citation: "higher-protein diets · wycherley 2012, ajcn",
                figure: .muscleBar
            ))
            pages.append(V8EvidencePage(
                numeral: "5-7%",
                caption: "the weight-loss benchmark clinical programs aim for. your pace stays in the safe range.",
                citation: "fda benchmark · dpp"
            ))
            return V8ChapterContent(
                eyebrow: "why this works",
                lines: [],
                pages: pages,
                cta: "make it mine"
            )

        case .file:
            var rows: [(String, String)] = []
            let outcomes: [String: String] = [
                "myself": "feel like myself again", "noise": "quiet around food",
                "energy": "steady energy", "clothes": "clothes that fit right",
                "keep": "keep off what i lost",
            ]
            if let o = outcomes[store.outcome] { rows.append(("here for", o)) }
            if store.deltaKg >= 1 {
                rows.append(("the distance", "\(store.deltaWords), safe pace"))
            } else {
                rows.append(("the mode", "maintenance rhythm"))
            }
            let identity: [String: String] = [
                "powerful": "the powerful one", "calm": "the calm one",
                "light": "the light one", "strong": "the strong one",
                "radiant": "the radiant one",
            ]
            if let i = identity[store.identityFeeling] { rows.append(("becoming", i)) }
            let nsvWords: [String: String] = [
                "core": "core", "energy": "energy", "clothes": "fit",
                "sleep": "sleep", "muscle": "muscle", "trust": "trust",
                "quiet": "quiet",
            ]
            let nsv = store.nsvPriority.compactMap { nsvWords[$0] }.sorted().prefix(2)
            if !nsv.isEmpty { rows.append(("beyond the scale", nsv.joined(separator: " + "))) }
            switch store.glp1Status {
            case "current": rows.append(("path", "alongside the medication"))
            case "past": rows.append(("path", "after medication. keeping it"))
            case "considering": rows.append(("path", "deciding. covered either way"))
            default: break
            }
            let cuisine = store.cuisines.filter { $0 != "everything" }.sorted().prefix(2)
            if !cuisine.isEmpty { rows.append(("the table", cuisine.joined(separator: " + "))) }
            if !store.clinicOrgName.isEmpty {
                rows.append(("care team", store.clinicOrgName.lowercased()))
            }
            rows.append(("on record", "\(store.answeredCount) answers"))
            if rows.count > 7 { rows = Array(rows.prefix(7)) }

            let name = store.name.lowercased()
            return V8ChapterContent(
                eyebrow: "the consult, closed",
                lines: [
                    V8Line(name.isEmpty ? "your file, ready." : "\(name)'s file, ready.",
                           italic: ["ready."]),
                ],
                rows: rows,
                cta: "sign it"
            )
        }
    }


    // MARK: async validators (STATIC registry)
    //
    // Stored-on-struct async closures arrive corrupted through
    // SwiftUI's value plumbing on the iOS 26.2 sim toolchain (the
    // probe read a garbage payload, then a nil closure). Validators
    // therefore resolve fresh from here at call time.

    static func validator(for beatID: String) -> ((OV5Store, String) async -> V8Validation)? {
        guard beatID == "clinicCode" else { return nil }
        return { store, code in

                    // DEBUG path-marker: which branch resolved the code
                    // (read from the sim plist by the QA loop).
                    func mark(_ v: String) {
                        #if DEBUG
                        UserDefaults.standard.set(v, forKey: "onb_v8_code_path")
                        #endif
                    }
                    mark("text:\(code.prefix(8))")
                    if code.isEmpty {
                        // Skipping the code = the regular flow.
                        mark("skip")
                        store.door = "consumer"
                        return .proceed
                    }
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--uitest-clinic-code-accept") {
                        mark("qa")
                        store.clinicOrgName = "demo clinic"
                        UserDefaults.standard.set(true, forKey: "care_entitlement_active")
                        return .proceed
                    }
                    #endif
                    do {
                        let result = try await CareConnectionService.accept(
                            code: code, lookbackDays: 28,
                            scopes: [.visitPacket, .observations, .assignment]
                        )
                        if result.ok {
                            mark("rpc-ok")
                            store.clinicOrgName = result.orgName ?? "your clinic"
                            // The provider connection carries the app
                            // entitlement (founder: B2B users access the
                            // app when the code connects; B2C stays
                            // hard-walled). Server truth re-verifies at
                            // every sync.
                            UserDefaults.standard.set(true, forKey: "care_entitlement_active")
                            return .proceed
                        }
                        mark("rpc-denied")
                        return .retry([V8Line("that code didn't land. double-check it with your clinic, or skip for now.")])
                    } catch {
                        mark("rpc-error")
                        return .retry([V8Line("couldn't reach the clinic system just now. try once more, or skip and add it later.")])
                    }
                }
    }
}
