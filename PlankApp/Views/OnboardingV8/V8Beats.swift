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
        switch id {
        case "ch_arrival": return "hello"
        case "hello": return "name"
        case "name": return "outcome"
        case "outcome": return "history"
        case "history": return "foodRelationship"
        case "foodRelationship": return "ch_mirror"
        case "ch_mirror": return "glp1Status"

        case "glp1Status":
            switch store.glp1Status {
            case "current": return "glp1Phase"
            case "past": return "stopWindow"
            case "considering": return "considering"
            default: return "cadence"
            }
        case "glp1Phase": return "appetiteRhythm"
        case "appetiteRhythm": return "shotDay"
        case "shotDay": return "muscleMath"
        case "muscleMath": return "cadence"
        case "stopWindow": return "appetiteReturn"
        case "appetiteReturn": return "cadence"
        case "considering": return "cadence"

        case "cadence": return "dietary"
        case "dietary": return "cuisine"
        case "cuisine": return "supports"
        case "supports": return "demoIntro"
        case "demoIntro": return "s_snapDemo"
        case "s_snapDemo":
            return store.isCurrentGlp1 ? "ch_evidence" : "proteinRule"
        case "proteinRule": return "ch_evidence"
        case "ch_evidence": return "numbersLine"

        case "numbersLine": return "gender"
        case "gender": return "age"
        case "age": return "height"
        case "height": return "weight"
        case "weight": return "weightTrend"
        case "weightTrend": return "goalDirection"
        case "goalDirection":
            switch store.goalDirection {
            case "maintain", "maintain_kept": return "movement"
            default: return "goalWeight"
            }
        case "goalWeight": return "movement"
        case "movement": return "sleep"
        case "sleep": return "stress"
        case "stress": return "nsv"
        case "nsv": return "medication"
        case "medication": return "s_safetyGate"
        case "s_safetyGate":
            return store.persona == .male ? "identity" : "hormonal"
        case "hormonal": return "identity"
        case "identity": return "fears"
        case "fears": return "attribution"
        case "attribution": return "ch_file"
        case "ch_file": return "s_signature"
        case "s_signature": return "s_healthKit"
        case "s_healthKit": return "s_hold"
        case "s_hold": return nil
        default: return nil
        }
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

        // MARK: act i — the consult opens

        case "hello":
            return V8Beat(
                "hello",
                lines: { _ in [
                    L("hi, i'm jeni."),
                    L("let's find out what your body needs. a few honest questions, then your plan.", ["honest"]),
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
                        return [L("\(name.lowercased()). good to meet you.", [name.lowercased() + "."])]
                    }
                    return [L("that's fine. this works either way.")]
                }
            )

        case "outcome":
            return V8Beat(
                "outcome",
                lines: { _ in [L("what are you here to change, mostly?", ["change,"])] },
                input: { _ in .options([
                    V8Option("myself", "feel like myself again"),
                    V8Option("noise", "quiet around food"),
                    V8Option("energy", "steady energy"),
                    V8Option("clothes", "clothes that fit right"),
                    V8Option("keep", "keep off what i lost"),
                ]) },
                preselected: { s in s.outcome.isEmpty ? [] : [s.outcome] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.outcome = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "myself":
                        return [L("that's the real one. the scale is just how we measure it.", ["real"])]
                    case "noise":
                        return [L("then you already know the hard part isn't the plate. it's the volume.", ["volume."])]
                    case "energy":
                        return [L("good. energy comes back weeks before the mirror changes. you'll see it first.", ["first."])]
                    case "clothes":
                        return [L("concrete. clothes tell the truth earlier than the scale does.", ["truth"])]
                    case "keep":
                        return [L("keeping it off is the harder skill. it's also the one i'm built around.", ["harder"])]
                    default: return []
                    }
                }
            )

        case "history":
            return V8Beat(
                "history",
                lines: { _ in [L("have you done this before?")] },
                input: { _ in .options([
                    V8Option("none", "this is my first real plan"),
                    V8Option("one_two", "once or twice"),
                    V8Option("three_five", "3 to 5 times"),
                    V8Option("many", "lost count"),
                ]) },
                preselected: { s in s.priorAttempts.isEmpty ? [] : [s.priorAttempts] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.priorAttempts = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "none":
                        return [L("then we start clean. no bad habits to unlearn.", ["clean."])]
                    case "one_two":
                        return [L("so you know how week three feels. this time, week three is designed for.", ["designed"])]
                    case "three_five":
                        return [L("three to five starts is not a willpower problem. it's a systems problem.", ["systems"]),
                                L("systems, we can fix.")]
                    case "many":
                        return [L("then you've done the hardest part over and over: starting.", ["starting."]),
                                L("the missing piece was never effort.")]
                    default: return []
                    }
                }
            )

        case "foodRelationship":
            return V8Beat(
                "foodRelationship",
                lines: { _ in [L("and food. what is it for you, mostly?", ["food."])] },
                input: { _ in .options([
                    V8Option("fuel", "fuel", sub: "i eat to function"),
                    V8Option("comfort", "comfort", sub: "food is how i decompress"),
                    V8Option("love", "love", sub: "cooking + sharing is joy"),
                    V8Option("control", "control", sub: "i track it closely"),
                    V8Option("complicated", "complicated", sub: "not a clean answer"),
                ]) },
                preselected: { s in s.foodRelationship.isEmpty ? [] : [s.foodRelationship] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.foodRelationship = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "fuel":
                        return [L("practical. the plan stays that way too.")]
                    case "comfort":
                        return [L("honest answer. the plan never takes that away. it stops the spiral after, that's all.", ["after,"])]
                    case "love":
                        return [L("good. anything that asks you to stop loving food fails by week two. this one cooks.", ["cooks."])]
                    case "control":
                        return [L("then you'll like the numbers here. they'll work for you, not against you.")]
                    case "complicated":
                        return [L("most true answers are. the loud part has a name: food cue reactivity. biology, not discipline.", ["biology,"])]
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
                        return [L("good to know. the plan works with it: protein first, dose days planned around.", ["with"])]
                    case "past":
                        return [L("important. the months after stopping are exactly what i'm built for.", ["after"])]
                    case "considering":
                        return [L("either way works. the daily piece is the same, med or no med.", ["daily"])]
                    case "none":
                        return [L("then we do it the straightforward way. food, movement, rhythm.", ["rhythm."])]
                    default:
                        return [L("understood. everything here works either way.")]
                    }
                }
            )

        case "glp1Phase":
            return V8Beat(
                "glp1Phase",
                lines: { _ in [L("how long have you been on it?")] },
                input: { _ in .chips([
                    V8Option("just_started", "just started"),
                    V8Option("few_months", "a few months in"),
                    V8Option("established", "6+ months, steady"),
                    V8Option("prefer_not", "prefer not to say"),
                ]) },
                preselected: { s in s.glp1Phase.isEmpty ? [] : [s.glp1Phase] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.glp1Phase = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    if v == "just_started" {
                        return [L("early is the right time. the first weeks decide what you keep.", ["keep."])]
                    }
                    return []
                }
            )

        case "appetiteRhythm":
            return V8Beat(
                "appetiteRhythm",
                lines: { _ in [L("how does appetite move across your week?")] },
                input: { _ in .options([
                    V8Option("after_shot", "quietest the day or two after my shot"),
                    V8Option("late_week", "late week, it creeps back"),
                    V8Option("most_days", "present most days right now"),
                    V8Option("varies", "it varies"),
                ]) },
                preselected: { s in s.appetiteRhythm.isEmpty ? [] : [s.appetiteRhythm] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.appetiteRhythm = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "after_shot":
                        return [L("then protein leads on the quiet days, while eating is easy to keep small.")]
                    case "late_week":
                        return [L("the late-week creep is the pattern we plan for, not against.")]
                    default: return []
                    }
                }
            )

        case "shotDay":
            return V8Beat(
                "shotDay",
                lines: { _ in [L("which day is your shot?")] },
                caption: { _ in "your plan shapes dose days around it. optional, change anytime." },
                input: { _ in .weekday(skip: "i'd rather not say") },
                preselected: { s in s.shotDay.isEmpty ? [] : [s.shotDay] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.shotDay = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload, !v.isEmpty else {
                        return [L("no problem. you can add it later, or never.")]
                    }
                    let names = ["mon": "monday", "tue": "tuesday", "wed": "wednesday",
                                 "thu": "thursday", "fri": "friday", "sat": "saturday",
                                 "sun": "sunday"]
                    return [L("\(names[v] ?? v). dose days will shape around it.")]
                }
            )

        case "muscleMath":
            return V8Beat(
                "muscleMath",
                lines: { _ in [
                    L("one thing the prescription never mentions: a share of what's lost on the shot is muscle.", ["muscle."]),
                    V8Line("appetite down means protein down, quietly. protein and movement decide what you keep.",
                           italic: ["keep."], citation: "lean-mass findings · nejm step 1"),
                    L("that's the work we do beside it.", ["beside"]),
                ] }
            )

        case "stopWindow":
            return V8Beat(
                "stopWindow",
                lines: { _ in [L("how long since you stopped?")] },
                input: { _ in .chips([
                    V8Option("under3", "under 3 months"),
                    V8Option("three6", "3 to 6 months"),
                    V8Option("six12", "6 to 12 months"),
                    V8Option("overyear", "over a year"),
                    V8Option("prefer_not", "prefer not to say"),
                ]) },
                preselected: { s in s.stopWindow.isEmpty ? [] : [s.stopWindow] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.stopWindow = v }
                }
            )

        case "appetiteReturn":
            return V8Beat(
                "appetiteReturn",
                lines: { _ in [L("is your appetite finding its way back?", ["back?"])] },
                input: { _ in .options([
                    V8Option("fully", "fully back"),
                    V8Option("creeping", "creeping back"),
                    V8Option("notyet", "not yet"),
                    V8Option("waves", "it comes in waves"),
                ]) },
                preselected: { s in s.appetiteReturn.isEmpty ? [] : [s.appetiteReturn] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.appetiteReturn = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "fully":
                        return [V8Line("that's physiology doing what it does. not failure.",
                                       italic: ["not failure."], citation: "discontinuation data · jama 2025"),
                                L("the plan feeds it, not fights it.")]
                    case "creeping":
                        return [V8Line("right on schedule, and nobody warns you. about half stop within a year, and the appetite comes back for most.",
                                       citation: "discontinuation data · jama 2025"),
                                L("we plan for it.")]
                    case "notyet":
                        return [L("then we build the rhythm now, before it wakes.", ["now,"])]
                    case "waves":
                        return [L("waves are the honest pattern. the plan holds through both halves.")]
                    default: return []
                    }
                }
            )

        case "considering":
            return V8Beat(
                "considering",
                lines: { _ in [
                    L("while you decide: the daily piece is the same, med or no med.", ["daily"]),
                    L("if you start one, this fits. if you never do, this is the whole plan.", ["whole"]),
                ] }
            )

        case "cadence":
            return V8Beat(
                "cadence",
                lines: { _ in [L("how do meals usually happen for you?")] },
                input: { _ in .chips([
                    V8Option("one_meal", "one meal"),
                    V8Option("two_meals", "2 + snacks"),
                    V8Option("three_meals", "3 steady meals"),
                    V8Option("grazing", "grazing all day"),
                    V8Option("chaotic", "no real pattern"),
                ]) },
                preselected: { s in s.eatingCadence.isEmpty ? [] : [s.eatingCadence] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.eatingCadence = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "chaotic":
                        return [L("then the plan brings the pattern. you bring the appetite you actually have.", ["actually"])]
                    case "grazing":
                        return [L("we'll work with the grazing, protein forward.")]
                    default: return []
                    }
                }
            )

        case "dietary":
            return V8Beat(
                "dietary",
                lines: { _ in [L("anything off the table?")] },
                caption: { _ in "allergies, rules, preferences. all respected." },
                input: { _ in .multi([
                    V8Option("vegetarian", "vegetarian"),
                    V8Option("vegan", "vegan"),
                    V8Option("pescatarian", "pescatarian"),
                    V8Option("dairy_free", "dairy-free"),
                    V8Option("gluten_free", "gluten-free"),
                    V8Option("nut_allergy", "nut allergy"),
                    V8Option("shellfish_allergy", "shellfish allergy"),
                    V8Option("egg_allergy", "egg allergy"),
                    V8Option("halal", "halal"),
                    V8Option("kosher", "kosher"),
                    V8Option("low_carb", "low-carb"),
                ], min: 0, cta: "continue", skip: "nothing off the table") },
                preselected: { s in s.dietary.subtracting(["none"]) },
                commit: { store, payload in
                    if case .set(let v) = payload {
                        store.dietary = v.isEmpty ? ["none"] : v
                    }
                }
            )

        case "cuisine":
            return V8Beat(
                "cuisine",
                lines: { _ in [L("and what's actually on it, most weeks?", ["actually"])] },
                caption: { _ in "pick what you eat. the plate reader learns it." },
                input: { _ in .multi([
                    V8Option("korean", "korean"),
                    V8Option("japanese", "japanese"),
                    V8Option("chinese", "chinese"),
                    V8Option("thai", "thai"),
                    V8Option("vietnamese", "vietnamese"),
                    V8Option("indian", "indian"),
                    V8Option("italian", "italian"),
                    V8Option("french", "french"),
                    V8Option("greek", "greek"),
                    V8Option("mexican", "mexican"),
                    V8Option("american", "american"),
                    V8Option("everything", "a bit of everything"),
                ], min: 0, cta: "continue", skip: nil) },
                preselected: { s in s.cuisines },
                commit: { store, payload in
                    if case .set(let v) = payload { store.cuisines = v }
                }
            )

        case "supports":
            return V8Beat(
                "supports",
                lines: { _ in [L("taking anything alongside?")] },
                caption: { _ in "so the plan fits your real days. nothing gets recommended here." },
                input: { _ in .multi([
                    V8Option("protein_powder", "protein powder"),
                    V8Option("multivitamin", "a multivitamin"),
                    V8Option("vitamin_d", "vitamin d"),
                    V8Option("fiber", "fiber"),
                    V8Option("magnesium", "magnesium"),
                    V8Option("electrolytes", "electrolytes"),
                ], min: 0, cta: "continue", skip: "none of these") },
                preselected: { s in s.supports.subtracting(["none"]) },
                commit: { store, payload in
                    if case .set(let v) = payload {
                        store.supports = v.isEmpty ? ["none"] : v
                    }
                }
            )

        case "demoIntro":
            return V8Beat(
                "demoIntro",
                lines: { _ in [
                    L("enough questions for a minute."),
                    L("let me show you something instead.", ["show"]),
                ] }
            )

        case "proteinRule":
            return V8Beat(
                "proteinRule",
                lines: { _ in [
                    L("the number one number in your plan: protein.", ["protein."]),
                    V8Line("in a deficit, some of what the scale drops is muscle. protein protects it, and it quiets hunger on the same calories.",
                           italic: ["protects"], citation: "higher-protein diets · wycherley 2012, ajcn"),
                    L("your floor gets computed from your body, not a template. you'll see it at the reveal.", ["your"]),
                ] }
            )

        // MARK: act iii — the numbers

        case "numbersLine":
            return V8Beat(
                "numbersLine",
                lines: { _ in [
                    L("now the part that makes it yours.", ["yours."]),
                    L("two minutes of numbers. nothing here is judged."),
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
                        range: usesFtIn ? 48...84 : 122...214,
                        step: 1,
                        majorEvery: usesFtIn ? 12 : 10,
                        initial: usesFtIn ? (cm / 2.54).rounded() : cm.rounded(),
                        unitTabs: ["ft · in", "cm"],
                        initialUnit: usesFtIn ? 0 : 1,
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
                caption: { _ in "a starting point, nothing more." },
                input: { s in
                    let kg = s.currentWeightKg
                    let usesLb = s.usesLb
                    return .ruler(V8RulerSpec(
                        range: usesLb ? 80...440 : 36...200,
                        step: 1,
                        majorEvery: usesLb ? 10 : 5,
                        initial: usesLb ? (kg * 2.20462).rounded() : kg.rounded(),
                        unitTabs: ["lb", "kg"],
                        initialUnit: usesLb ? 0 : 1,
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
                    [L("thank you. that number is where we start, not where we end.", ["start,"])]
                }
            )

        case "weightTrend":
            return V8Beat(
                "weightTrend",
                lines: { _ in [L("lately, it's been…", ["lately,"])] },
                input: { _ in .chips([
                    V8Option("climbing", "climbing"),
                    V8Option("stable", "about the same"),
                    V8Option("declining", "slowly coming down"),
                    V8Option("cycling", "up and down"),
                ]) },
                preselected: { s in s.weightTrend.isEmpty ? [] : [s.weightTrend] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.weightTrend = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "cycling":
                        return [L("up and down usually means the last plan was too sharp. this one is built steadier.", ["steadier."])]
                    case "climbing":
                        return [L("good that you're here now. trends bend fastest when you catch them early.", ["early."])]
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
                        return [L("maintenance is its own skill. the plan holds your line, and your muscle.", ["skill."])]
                    case "recomp":
                        return [L("then the scale matters less than the mirror here. protein and movement lead.")]
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
                        range: usesLb ? 80...440 : 36...200,
                        step: 1,
                        majorEvery: usesLb ? 10 : 5,
                        initial: usesLb ? (seeded * 2.20462).rounded() : seeded.rounded(),
                        anchor: current,
                        cta: "set it",
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
                        return [L("close to home already. we'll make the line steady, then hold it.")]
                    }
                    let lb = Int((delta * 2.20462).rounded())
                    if let weeks = ProjectionMath.projectedWeeks(
                        currentKg: store.currentWeightKg,
                        goalKg: store.goalWeightKg,
                        paceKey: UserDefaults.standard.string(forKey: ProjectionMath.paceDefaultsKey)
                    ) {
                        return [V8Line("\(lb) lb. at the safe pace, that's about \(weeks) weeks. an estimate, not a promise.",
                                       italic: ["estimate,"], citation: "calibrated to acsm 0.5-1%/wk")]
                    }
                    return [V8Line("\(lb) lb, at a pace your body can actually keep.",
                                   italic: ["actually"], citation: "calibrated to acsm 0.5-1%/wk")]
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
                        return [L("honest is what the plan needs. we start where you are, not where apps pretend you are.", ["are,"])]
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
                        return [L("noted. short sleep changes appetite math, so the plan pads for it instead of pretending.", ["pads"])]
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
                        return [L("then the plan flexes on the days that are too much. it adapts to you, never the reverse.", ["adapts"])]
                    }
                    return []
                }
            )

        case "nsv":
            return V8Beat(
                "nsv",
                lines: { _ in [L("beyond the scale, what do you want back?", ["beyond"])] },
                caption: { _ in "pick everything that's true." },
                input: { s in
                    var lead: [V8Option] = []
                    if s.isCurrentGlp1 {
                        lead = [V8Option("muscle", "keeping muscle while i lose")]
                    } else if s.isPastGlp1 {
                        lead = [V8Option("trust", "trusting food again")]
                    } else {
                        lead = [V8Option("quiet", "quiet around food")]
                    }
                    return .multi(lead + [
                        V8Option("core", "a core that holds"),
                        V8Option("energy", "energy that lasts"),
                        V8Option("clothes", "clothes that fit right"),
                        V8Option("sleep", "sleep that resets"),
                    ], min: 1, cta: "that's the list")
                },
                preselected: { s in s.nsvPriority },
                commit: { store, payload in
                    if case .set(let v) = payload { store.nsvPriority = v }
                },
                ack: { _, payload in
                    guard case .set(let v) = payload, !v.isEmpty else { return [] }
                    return [L("kept. these ride with your file to the plan. the scale is one line, not the story.", ["one"])]
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
                    [L("last piece of the medical picture. thirty seconds, and it's for your safety, not our curiosity.", ["your"])]
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
                        return [L("then the plan uses the gentler floor your physiology asks for. built in, not bolted on.", ["built"])]
                    case "postpartum":
                        return [L("noted. the pace floor stays protective. no plan should sprint here.", ["protective."])]
                    default: return []
                    }
                }
            )

        case "identity":
            return V8Beat(
                "identity",
                lines: { _ in [L("which version of you is this for?", ["version"])] },
                input: { _ in .chips([
                    V8Option("powerful", "powerful"),
                    V8Option("calm", "calm"),
                    V8Option("light", "light"),
                    V8Option("strong", "strong"),
                    V8Option("radiant", "radiant"),
                ]) },
                preselected: { s in s.identityFeeling.isEmpty ? [] : [s.identityFeeling] },
                commit: { store, payload in
                    if case .choice(let v) = payload { store.identityFeeling = v }
                },
                ack: { _, payload in
                    guard case .choice(let v) = payload else { return [] }
                    switch v {
                    case "powerful": return [L("powerful. strength-forward it is.", ["powerful."])]
                    case "calm": return [L("calm. then the plan stays quiet and steady, like the goal.", ["calm."])]
                    case "light": return [L("light. less carried, more moved.", ["light."])]
                    case "strong": return [L("strong. muscle stays. that's the whole design.", ["strong."])]
                    case "radiant": return [L("radiant. the outside follows the inside numbers.", ["radiant."])]
                    default: return []
                    }
                }
            )

        case "fears":
            return V8Beat(
                "fears",
                lines: { _ in [L("people carry fears into this. tap any that are yours.", ["fears"])] },
                caption: { _ in "it stays between us." },
                input: { s in
                    var rows = [
                        V8Option("quick", "i'm scared of apps that promise quick results."),
                        V8Option("diet", "i'm scared this turns into another diet."),
                    ]
                    if s.isCurrentGlp1 {
                        rows.append(V8Option("offramp", "i'm afraid of what happens when i stop."))
                    } else if s.isPastGlp1 {
                        rows.append(V8Option("regain", "i'm afraid it all comes back now that i've stopped."))
                    } else {
                        rows.append(V8Option("prior", "i've given up after the first hard day."))
                    }
                    return .multi(rows, min: 0, cta: "that's mine", skip: "none of these")
                },
                preselected: { s in
                    var out = Set<String>()
                    if s.fearQuickResults == "yes" { out.insert("quick") }
                    if s.fearAnotherDiet == "yes" { out.insert("diet") }
                    if s.fearOfframp == "yes" { out.insert("offramp") }
                    if s.fearRegain == "yes" { out.insert("regain") }
                    if s.fearPriorAttempt == "yes" { out.insert("prior") }
                    return out
                },
                commit: { store, payload in
                    guard case .set(let v) = payload else { return }
                    store.fearQuickResults = v.contains("quick") ? "yes" : "no"
                    store.fearAnotherDiet = v.contains("diet") ? "yes" : "no"
                    if store.isCurrentGlp1 {
                        store.fearOfframp = v.contains("offramp") ? "yes" : "no"
                    } else if store.isPastGlp1 {
                        store.fearRegain = v.contains("regain") ? "yes" : "no"
                    } else {
                        store.fearPriorAttempt = v.contains("prior") ? "yes" : "no"
                    }
                },
                ack: { _, payload in
                    guard case .set(let v) = payload else { return [] }
                    if v.isEmpty {
                        return [L("clean slate. even better.")]
                    }
                    return [L("kept. your plan answers each of these, and you'll see how at the reveal.", ["answers"])]
                },
                strikes: true
            )

        case "attribution":
            return V8Beat(
                "attribution",
                lines: { _ in [L("one for our team. where did you find us?")] },
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
                lines: [
                    L("i'm jeni.", ["jeni."]),
                    L("i build body transformations that hold.", ["hold."]),
                ],
                cta: "begin",
                secondary: "i already have an account"
            )

        case .mirror:
            var lines: [V8Line] = []
            let name = store.name.lowercased()
            let outcomes: [String: String] = [
                "myself": "you want to feel like yourself again.",
                "noise": "you want quiet around food.",
                "energy": "you want energy that holds through the day.",
                "clothes": "you want your clothes to fit the way they should.",
                "keep": "you want what you lost to stay lost.",
            ]
            if let o = outcomes[store.outcome] {
                lines.append(V8Line(name.isEmpty ? o : "\(name). \(o)", italic: name.isEmpty ? [] : ["\(name)."]))
            }
            switch store.priorAttempts {
            case "many", "three_five":
                lines.append(L("you've started this before. what failed wasn't effort. it was the system around it.", ["system"]))
            case "one_two":
                lines.append(L("you've been here before. this time the plan carries the load, not the motivation.", ["plan"]))
            default:
                lines.append(L("first real plan. we'll build it right the first time.", ["right"]))
            }
            lines.append(L("none of this is a willpower problem."))
            lines.append(L("here's how i work.", ["how"]))
            return V8ChapterContent(
                eyebrow: "what we know so far",
                lines: lines,
                cta: "show me"
            )

        case .evidence:
            var pages: [V8EvidencePage] = []
            if store.isCurrentGlp1 {
                pages.append(V8EvidencePage(
                    headline: "what you lose should be fat, not muscle.",
                    headlineItalic: ["fat,"],
                    caption: "on medication, appetite down means protein down. your plan computes a protein floor and holds it, so the loss is the right kind.",
                    citation: "lean-mass findings · nejm step 1"
                ))
            } else if store.isPastGlp1 {
                pages.append(V8EvidencePage(
                    headline: "stopping is the norm, not the exception.",
                    headlineItalic: ["norm,"],
                    caption: "about half of medication users stop within the first year. what carries after is the daily rhythm. that's the part we build.",
                    citation: "discontinuation data · jama 2025"
                ))
            } else {
                pages.append(V8EvidencePage(
                    headline: "food noise is measurable biology.",
                    headlineItalic: ["biology."],
                    caption: "researchers call it food cue reactivity: appetite signals and learned cues keep the loop running. the plan is built to turn the volume down.",
                    citation: "food-cue reactivity · hayashi 2023"
                ))
            }
            pages.append(V8EvidencePage(
                headline: "higher protein, same calories, more kept muscle.",
                headlineItalic: ["kept"],
                caption: "your plan computes a protein floor from your body weight and holds it while you lose.",
                citation: "higher-protein diets · wycherley 2012, ajcn"
            ))
            pages.append(V8EvidencePage(
                numeral: "5-7%",
                caption: "the sustainable-loss benchmark clinical programs are held to. your pace stays inside the safe band, always.",
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
                rows.append(("the distance", "\(Int((store.deltaKg * 2.20462).rounded())) lb, honest pace"))
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
            case "past": rows.append(("path", "the after. keeping it"))
            case "considering": rows.append(("path", "deciding, covered either way"))
            default: break
            }
            let cuisine = store.cuisines.filter { $0 != "everything" }.sorted().prefix(2)
            if !cuisine.isEmpty { rows.append(("the table", cuisine.joined(separator: " + "))) }
            rows.append(("on record", "\(store.answeredCount) answers"))
            if rows.count > 7 { rows = Array(rows.prefix(7)) }

            let name = store.name.lowercased()
            return V8ChapterContent(
                eyebrow: "the consult, closed",
                lines: [
                    V8Line(name.isEmpty ? "your file, ready." : "\(name)'s file, ready.",
                           italic: ["file,"]),
                ],
                rows: rows,
                cta: "sign it"
            )
        }
    }
}
