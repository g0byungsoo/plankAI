import SwiftUI

// MARK: - Act II — her food story
// Spec: docs/onboarding_v5/FLOW.md #7-16. GLP-1 status is a PATH-FACT
// asked at the top of the act so everything downstream cohort-routes.
// Compliance floors: no drand names, no dose/timing advice, promises
// reference only shipping surfaces.

struct OV5Glp1StatusScreen: View {
    let flow: OV5Flow
    @State private var showAck = false

    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "any weight meds right now?", italic: ["now"])
            OV5TrustLine(text: "the plan reads differently on, after, or without them. private, always.")
                .padding(.top, Space.sm)
                .ov5Beat2()
            OV5SelectList(
                options: [
                    .init(key: "none", label: "no"),
                    .init(key: "current", label: "yes, i'm on one"),
                    .init(key: "past", label: "i was. not anymore"),
                    .init(key: "considering", label: "thinking about it"),
                    .init(key: "prefer_not_say", label: "prefer not to say", icon: "lock"),
                ],
                selection: $store.glp1Status,
                autoAdvance: false
            )
            if showAck, let line = ackLine {
                ItalicAccentText(
                    line.0, italic: line.1,
                    baseFont: .custom("DMSans-Regular", size: 14),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 16),
                    color: Palette.textSecondary,
                    alignment: .center
                )
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
                .transition(.opacity.combined(with: .offset(y: 6)))
            }
            Spacer()
        }
        .onChange(of: flow.store.glp1Status) { _, _ in
            withAnimation(Motion.entranceSoft) { showAck = true }
        }
        .ov5CTA("continue", isEnabled: !flow.store.glp1Status.isEmpty) {
            flow.advance()
        }
    }

    /// Ship-only acknowledgments — identity noun-phrase, zero feature
    /// promises (glp1_strategy compliance floor).
    private var ackLine: (String, [String])? {
        switch flow.store.glp1Status {
        case "current": return ("we pace for the shot.", ["pace"])
        case "past": return ("the first goal is keeping what you built.", ["keeping"])
        case "considering": return ("med or no med, the daily piece is the same.", ["same"])
        case "none", "prefer_not_say": return ("noted. your plan, your way.", ["your"])
        default: return nil
        }
    }
}

struct OV5Glp1PhaseScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "how long on it?", italic: ["it"])
            OV5SelectList(
                options: [
                    .init(key: "just_started", label: "just started"),
                    .init(key: "few_months", label: "a few months in"),
                    .init(key: "established", label: "6+ months, steady"),
                    .init(key: "prefer_not", label: "prefer not to say", icon: "lock"),
                ],
                selection: $store.glp1Phase,
                autoAdvance: false
            )
            Spacer()
        }
        .ov5CTA("continue", isEnabled: !flow.store.glp1Phase.isEmpty) {
            flow.advance()
        }
    }
}

struct OV5AppetiteRhythmScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(
                title: "when is eating hardest right now?",
                italic: ["hardest"],
                sub: "your lived rhythm. we pace week one around it."
            )
            OV5SelectList(
                options: [
                    .init(key: "after_shot", label: "the day or two after my shot"),
                    .init(key: "late_week", label: "late week, appetite creeps back"),
                    .init(key: "most_days", label: "most days right now"),
                    .init(key: "varies", label: "it varies"),
                ],
                selection: $store.appetiteRhythm,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5MuscleMathScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5TeachView(
            title: "a share of what's lost on the shot is muscle.",
            titleItalic: ["muscle."],
            points: [
                .init(numeral: "i", punch: "appetite down means protein down, quietly.",
                      gloss: "smaller meals crowd protein out first, without you choosing it."),
                .init(numeral: "ii", punch: "protein + movement decide what you keep.",
                      gloss: "the two levers that protect lean mass while the scale moves."),
            ],
            closing: "that's the work we do beside it.",
            closingItalic: ["beside"],
            citation: "lean-mass findings · nejm step 1",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5StopWindowScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "how long since you stopped?", italic: ["stopped"])
            OV5SelectList(
                options: [
                    .init(key: "under3", label: "under 3 months"),
                    .init(key: "three6", label: "3 to 6 months"),
                    .init(key: "six12", label: "6 to 12 months"),
                    .init(key: "overyear", label: "over a year"),
                    .init(key: "prefer_not", label: "prefer not to say", icon: "lock"),
                ],
                selection: $store.stopWindow,
                autoAdvance: false
            )
            Spacer()
        }
        .ov5CTA("continue", isEnabled: !flow.store.stopWindow.isEmpty) {
            flow.advance()
        }
    }
}

struct OV5AppetiteReturnScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "is your appetite finding its way back?", italic: ["back"])
            OV5SelectList(
                options: [
                    .init(key: "fully", label: "fully back"),
                    .init(key: "creeping", label: "creeping back"),
                    .init(key: "notyet", label: "not yet"),
                    .init(key: "waves", label: "it comes in waves"),
                ],
                selection: $store.appetiteReturn,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5RegainTruthScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5TeachView(
            title: "and then the volume came back.",
            titleItalic: ["back."],
            lead: "appetite returning is physiology, not failure.",
            points: [
                .init(numeral: "i", punch: "about half stop within the first year.",
                      gloss: "coverage, cost, side effects, life. stopping is the norm, not the exception."),
                .init(numeral: "ii", punch: "the rhythm is the part nobody prescribed.",
                      gloss: "protein, steps, the daily pattern. the medication never built those for you."),
            ],
            closing: "that's the part we're built for.",
            closingItalic: ["built"],
            citation: "discontinuation data · jama 2025",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5ConsideringScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5TeachView(
            title: "med or no med, the daily piece is the same.",
            titleItalic: ["same."],
            lead: "if you ever start one, this still fits. if you never do, this is the whole plan.",
            ctaLabel: "continue",
            onContinue: { flow.advance() }
        )
    }
}

// MARK: food questions

struct OV5FoodRelationshipScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "what is food, mostly?", italic: ["food"])
            OV5SelectList(
                options: [
                    .init(key: "fuel", label: "fuel", sub: "i eat to function"),
                    .init(key: "comfort", label: "comfort", sub: "food is how i decompress"),
                    .init(key: "love", label: "love", sub: "cooking + sharing is joy"),
                    .init(key: "control", label: "control", sub: "i track it closely"),
                    .init(key: "complicated", label: "complicated", sub: "not a clean answer"),
                ],
                selection: $store.foodRelationship,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5FoodNoiseScreen: View {
    let flow: OV5Flow
    var body: some View {
        let store = flow.store
        if store.isCurrentGlp1 {
            OV5TeachView(
                title: "you know food noise because it went quiet.",
                titleItalic: ["quiet."],
                points: [
                    .init(numeral: "i", punch: "the shot turns the volume down.",
                          gloss: "that hush you noticed in week one? that was the noise, leaving."),
                    .init(numeral: "ii", punch: "the habits decide what stays.",
                          gloss: "protein, rhythm, movement. the quiet is the window to build them."),
                ],
                closing: "we're the part that stays.",
                closingItalic: ["stays."],
                onContinue: { flow.advance() }
            )
        } else if store.isPastGlp1 {
            OV5TeachView(
                title: "quieter hunger still deserves a plan.",
                titleItalic: ["plan."],
                lead: "you've heard the noise loud and heard it quiet. the plan works either way.",
                points: [
                    .init(numeral: "i", punch: "it's biology, not willpower.",
                          gloss: "hunger hormones and habit loops keep the thought running in the background."),
                ],
                closing: "we build the rhythm that holds.",
                closingItalic: ["holds."],
                onContinue: { flow.advance() }
            )
        } else {
            OV5TeachView(
                title: "that's called food noise.",
                titleItalic: ["food noise."],
                lead: "the chatter that never quite quiets. what to eat, when, how much. the bargaining at 9pm.",
                points: [
                    .init(numeral: "i", punch: "it's not willpower.",
                          gloss: "you're not failing at discipline. for some bodies the signal is simply louder."),
                    .init(numeral: "ii", punch: "it's biology.",
                          gloss: "hunger hormones and habit loops keep the thought running in the background."),
                ],
                closing: "your plan is built to turn the volume down.",
                closingItalic: ["volume"],
                onContinue: { flow.advance() }
            )
        }
    }
}

struct OV5PreEatScreen: View {
    let flow: OV5Flow
    var body: some View {
        OV5TeachView(
            title: "you can decide before you eat.",
            titleItalic: ["before"],
            lead: "snap it first. see if it fits. no shame either way.",
            ctaLabel: "show me",
            onContinue: { flow.advance() }
        )
    }
}

struct OV5EatingCadenceScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "how do you usually eat?", italic: ["usually"])
            OV5SelectList(
                options: [
                    .init(key: "one_meal", label: "one meal"),
                    .init(key: "two_meals", label: "2 + snacks"),
                    .init(key: "three_meals", label: "3 steady meals"),
                    .init(key: "grazing", label: "grazing all day"),
                    .init(key: "chaotic", label: "no real pattern"),
                ],
                selection: $store.eatingCadence,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5PriorWinScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(title: "what worked, even briefly?", italic: ["worked"])
            OV5SelectList(
                options: [
                    .init(key: "moving_daily", label: "daily movement"),
                    .init(key: "eating_window", label: "an eating window"),
                    .init(key: "cutting_sugar", label: "less sugar"),
                    .init(key: "logging_food", label: "tracking food"),
                    .init(key: "nothing_yet", label: "still figuring it out"),
                ],
                selection: $store.priorWin,
                onCommit: { flow.advance() }
            )
        }
    }
}

struct OV5CuisineScreen: View {
    let flow: OV5Flow

    // Round 2 trim: 12 chips, not a tag manager. The long tail lives in
    // the in-app food preferences; the CSV key + vision-prompt contract
    // is unchanged.
    private static let cuisines: [(String, String)] = [
        ("korean", "korean"), ("japanese", "japanese"), ("chinese", "chinese"),
        ("thai", "thai"), ("vietnamese", "vietnamese"), ("indian", "indian"),
        ("italian", "italian"), ("french", "french"), ("greek", "greek"),
        ("mexican", "mexican"), ("american", "american"),
        ("everything", "a bit of everything"),
    ]

    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(
                title: "what's on your table?",
                italic: ["your"],
                sub: "pick what you actually eat. the plate reader learns it."
            )
            ScrollView {
                OV5ChipCloud(
                    options: Self.cuisines,
                    selection: $store.cuisines
                )
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.md)
                .padding(.bottom, Space.lg)
                .ov5Beat2()
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollEdgeFade()
        }
        .ov5CTA("continue", isEnabled: !flow.store.cuisines.isEmpty) {
            flow.advance()
        }
    }
}

struct OV5DietaryScreen: View {
    let flow: OV5Flow
    var body: some View {
        @Bindable var store = flow.store
        OV5Screen {
            OV5Header(
                title: "anything the kitchen should know?",
                italic: ["kitchen"],
                sub: "patterns, allergies, rules. multi-pick."
            )
            OV5MultiList(
                options: [
                    .init(key: "vegetarian", label: "vegetarian"),
                    .init(key: "vegan", label: "vegan"),
                    .init(key: "pescatarian", label: "pescatarian"),
                    .init(key: "dairy_free", label: "dairy-free"),
                    .init(key: "gluten_free", label: "gluten-free"),
                    .init(key: "nut_allergy", label: "nut allergy"),
                    .init(key: "shellfish_allergy", label: "shellfish allergy"),
                    .init(key: "egg_allergy", label: "egg allergy"),
                    .init(key: "halal", label: "halal"),
                    .init(key: "kosher", label: "kosher"),
                    .init(key: "low_carb", label: "low-carb"),
                    .init(key: "none", label: "none of these"),
                ],
                selection: $store.dietary,
                exclusiveKeys: ["none"]
            )
        }
        .ov5CTA("continue", isEnabled: !flow.store.dietary.isEmpty) {
            flow.advance()
        }
    }
}

struct OV5FoodReceiptScreen: View {
    let flow: OV5Flow

    var body: some View {
        let store = flow.store
        OV5ReceiptView(
            title: "your food story, heard.",
            titleItalic: ["heard."],
            rows: rows(store),
            footnote: "tomorrow morning, we start quieting it.",
            onContinue: { flow.advance() }
        )
    }

    private func rows(_ store: OV5Store) -> [OV5ReceiptRowData] {
        var out: [OV5ReceiptRowData] = []
        let relationship: [String: String] = [
            "fuel": "food is fuel", "comfort": "food is comfort",
            "love": "food is love", "control": "food is control",
            "complicated": "food is complicated",
        ]
        if let r = relationship[store.foodRelationship] {
            out.append(.init(lead: "you said", punch: r, punchItalic: [String(r.split(separator: " ").last ?? "")]))
        }
        let cadence: [String: String] = [
            "one_meal": "one meal a day", "two_meals": "two meals + snacks",
            "three_meals": "three steady meals", "grazing": "grazing days",
            "chaotic": "no fixed pattern",
        ]
        if let c = cadence[store.eatingCadence] {
            out.append(.init(lead: "your rhythm", punch: c, punchItalic: []))
        }
        let cuisineWords = store.cuisines
            .filter { $0 != "everything" }
            .sorted()
            .prefix(2)
            .joined(separator: " + ")
        if !cuisineWords.isEmpty {
            out.append(.init(lead: "your table", punch: cuisineWords, punchItalic: []))
        } else if store.cuisines.contains("everything") {
            out.append(.init(lead: "your table", punch: "a bit of everything", punchItalic: ["everything"]))
        }
        return out
    }
}

// MARK: - OV5ChipCloud (wrapping chip layout, text-only)

struct OV5ChipCloud: View {
    let options: [(String, String)]
    @Binding var selection: Set<String>

    var body: some View {
        OV5FlowLayout(hSpacing: 8, vSpacing: 10) {
            ForEach(options, id: \.0) { key, label in
                let isOn = selection.contains(key)
                Button {
                    Haptics.soft()
                    withAnimation(Motion.tap) {
                        if isOn { selection.remove(key) } else { selection.insert(key) }
                    }
                } label: {
                    Text(label)
                        .font(Typo.heroSubpill)
                        .kerning(0.2)
                        .foregroundStyle(isOn ? Palette.textInverse : Palette.textPrimary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 10)
                        .background(
                            Capsule().fill(isOn ? Palette.cocoaPrimary : Palette.bgElevated)
                        )
                        .overlay(
                            Capsule().strokeBorder(
                                isOn ? Color.clear : Palette.hairlineCocoa, lineWidth: 1
                            )
                        )
                }
                .buttonStyle(PressFeedbackStyle())
            }
        }
    }
}

/// Greedy left-aligned wrap layout for chips (iOS 16+ Layout).
struct OV5FlowLayout: Layout {
    var hSpacing: CGFloat = 8
    var vSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? UIScreen.main.bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 { x = 0; y += rowH + vSpacing; rowH = 0 }
            x += size.width + hSpacing
            rowH = max(rowH, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for s in subviews {
            let size = s.sizeThatFits(.unspecified)
            if x - bounds.minX + size.width > bounds.width && x > bounds.minX {
                x = bounds.minX; y += rowH + vSpacing; rowH = 0
            }
            s.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: ProposedViewSize(size))
            x += size.width + hSpacing
            rowH = max(rowH, size.height)
        }
    }
}
