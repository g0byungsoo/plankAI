import Foundation

// MARK: - JeniToolCatalog
//
// v25 E3 ONE JENI (docs/app_v25/12_E3_ONE_JENI.md §2).
//
// The tool surface, declared HERE and sent on the wire. It used to
// live server-side in the edge function, which meant every new tool
// was a founder-gated deploy — and five eras have now queued behind
// those. The function validates each entry against its own allowlist
// and drops anything it doesn't recognise, so the client can grow the
// surface but never invent one.
//
// TWO KINDS, and the difference is the whole era:
//
//   READ  — returns the user's own stored record and CONTINUES the
//           turn. Jeni asks a question of the record, gets an answer,
//           and writes her reply from it. Nothing is mutated, nothing
//           needs confirming, and the user sees a quiet "reading your
//           record" line rather than a card full of plumbing.
//   ACT   — changes or opens something. Mutating acts show a confirm
//           card first (jeni proposes, the user disposes); navigation
//           acts fire immediately.
//
// The descriptions ARE prompt engineering: they are the only thing
// telling the model when a lookup is worth a round trip. Keep them
// concrete, keep them honest about what is NOT in the record, and
// never describe a tool as more certain than the data behind it.

enum JeniToolKind {
    case read
    /// Opens or renders something; no confirmation, no continuation.
    case actImmediate
    /// Changes stored state; renders a confirm card, then continues.
    case actConfirmed
}

struct JeniTool {
    let name: String
    let kind: JeniToolKind
    let description: String
    /// JSON Schema for the arguments object.
    let parameters: [String: Any]

    var wireForm: [String: Any] {
        [
            "type": "function",
            "function": [
                "name": name,
                "description": description,
                "parameters": parameters,
            ] as [String: Any],
        ]
    }
}

enum JeniToolCatalog {

    private static let noArgs: [String: Any] = [
        "type": "object",
        "properties": [String: Any](),
        "additionalProperties": false,
    ]

    private static func object(
        _ properties: [String: Any],
        required: [String] = []
    ) -> [String: Any] {
        var out: [String: Any] = [
            "type": "object",
            "properties": properties,
            "additionalProperties": false,
        ]
        if !required.isEmpty { out["required"] = required }
        return out
    }

    // MARK: - The reads

    static let reads: [JeniTool] = [
        JeniTool(
            name: "read_food_day",
            kind: .read,
            description: """
            look up what they logged on ONE past day. use for "what did i eat \
            on friday", "was yesterday enough protein", or any question about \
            a specific day that is not today (today's plates are already in \
            coach_context). returns the plates with their calories and \
            macros, the day's totals against that day's targets, and says \
            plainly when nothing was logged. an unlogged day is not a day \
            they did not eat.
            """,
            parameters: object([
                "days_ago": [
                    "type": "integer",
                    "minimum": 1,
                    "maximum": 60,
                    "description": "1 = yesterday. use this for relative days.",
                ] as [String: Any],
                "weekday": [
                    "type": "string",
                    "enum": ["monday", "tuesday", "wednesday", "thursday",
                             "friday", "saturday", "sunday"],
                    "description": "the most recent past day with this name.",
                ] as [String: Any],
            ]),
        ),
        JeniTool(
            name: "read_food_week",
            kind: .read,
            description: """
            look up the last 7 or 14 days of eating as a whole. use for "how \
            was my week", "am i getting enough protein", "what do i eat most", \
            or before offering any change to how they eat. returns days \
            logged (not days eaten), average calories and protein across the \
            days that HAVE a record, how many days met the protein floor, \
            fiber, and their repeated dishes. sparse records come back marked \
            sparse: say so instead of averaging two days into a verdict.
            """,
            parameters: object([
                "days": [
                    "type": "integer",
                    "enum": [7, 14],
                    "description": "window length; defaults to 7.",
                ] as [String: Any],
            ]),
        ),
        JeniTool(
            name: "read_weight_trend",
            kind: .read,
            description: """
            look up the weight trend: the smoothed line, the direction over \
            the last week, how many weigh-ins it rests on, and whether that \
            is enough to speak. use for "am i actually losing", "why am i up", \
            plateau questions. the answer may come back insufficient or \
            stale, which is a real answer: one weigh-in never has a \
            direction. never state a direction the tool did not.
            """,
            parameters: noArgs
        ),
        JeniTool(
            name: "read_dose_history",
            kind: .read,
            description: """
            look up the medication record: the current regimen and how long \
            it has been the current one, the eras before it, how the recent \
            slots resolved (taken, late, skipped, still open), and the \
            position in this dose week. use for "when did my dose change", \
            "have i been consistent", "what week am i in". facts only. never \
            turn the answer into dosing advice.
            """,
            parameters: noArgs
        ),
        JeniTool(
            name: "read_symptoms",
            kind: .read,
            description: """
            look up the symptoms they have recorded and when, including food \
            noise. use for "has the nausea been getting better", "when did \
            this start", or when they describe something they may have logged \
            before. returns the timeline with severities. it is their record, \
            not a diagnosis, and it never becomes one.
            """,
            parameters: object([
                "days": [
                    "type": "integer",
                    "minimum": 7,
                    "maximum": 120,
                    "description": "lookback window; defaults to 30.",
                ] as [String: Any],
            ]),
        ),
        JeniTool(
            name: "read_patterns",
            kind: .read,
            description: """
            look up the observations the app has actually earned from their \
            record. these are floor-gated (they only exist after enough \
            repeats) and they are about TIMING, never cause. use when they \
            ask "have you noticed anything" or "why does this keep \
            happening". an empty answer is common and honest early on: say \
            there is not enough yet rather than inventing a pattern.
            """,
            parameters: noArgs
        ),
        JeniTool(
            name: "read_activity",
            kind: .read,
            description: """
            look up movement: steps today, the recent daily record, their own \
            typical day, and any workouts health has handed over. use for "am \
            i moving more", "what's a normal day for me", or before \
            suggesting a walking change. compares them to themselves, never \
            to a population.
            """,
            parameters: noArgs
        ),
        JeniTool(
            name: "read_program",
            kind: .read,
            description: """
            look up the program's facts and WHO SET EACH ONE: the step goal, \
            protein floor, calorie target, weigh cadence and the rest, each \
            with its authority (prescribed by their clinician, preferred by \
            them, recommended by you and accepted, or a default), and when it \
            last changed. use before proposing any change, and for "why is my \
            target this", "who decided this", "what changed". a prescribed \
            fact is their clinician's and you never propose over it.
            """,
            parameters: noArgs
        ),
    ]

    // MARK: - The acts

    static let acts: [JeniTool] = [
        JeniTool(
            name: "open_snap_camera",
            kind: .actImmediate,
            description:
                "open the food camera so they can snap a meal right now. use when they want to log food and have it in front of them.",
            parameters: noArgs
        ),
        JeniTool(
            name: "log_food_text",
            kind: .actConfirmed,
            description: """
            log a meal they DESCRIBED in words, when there is no photo. pass \
            their own description as plainly as they said it. the app \
            estimates it and shows them the result to confirm. use this \
            instead of the camera when the food is already eaten or not in \
            front of them.
            """,
            parameters: object([
                "description": [
                    "type": "string",
                    "description": "what they ate, in their words.",
                ] as [String: Any],
            ], required: ["description"]),
        ),
        JeniTool(
            name: "log_weight",
            kind: .actConfirmed,
            description:
                "propose logging a weight they just told you (kilograms). the app shows a confirm card.",
            parameters: object([
                "kg": ["type": "number", "description": "weight in kilograms"] as [String: Any],
            ], required: ["kg"]),
        ),
        JeniTool(
            name: "propose_program_fact",
            kind: .actConfirmed,
            description: """
            propose a change to ONE fact in their program. this is how the \
            plan changes in conversation: "make my step goal 6000", "stop \
            asking me to weigh so often", "keep it quieter", "i want to walk \
            after dinner", "logging is too much right now". the app shows a \
            confirm card and nothing moves until they accept; accepted \
            changes are recorded as THEIR preference, with a history they can \
            see. call read_program first so you know the current value and \
            who set it. NEVER propose over a fact their clinician prescribed. \
            at most one proposal per conversation, and only when they have \
            asked for it or clearly want it. this cannot change calorie or \
            protein targets: those are the weekly read's, and yours to \
            explain, not to set.
            """,
            parameters: object([
                "kind": [
                    "type": "string",
                    "enum": ["stepGoal", "weighCadence", "loggingMode",
                             "notificationPosture", "walkTiming"],
                ] as [String: Any],
                "steps": [
                    "type": "integer",
                    "minimum": 1000,
                    "maximum": 30000,
                    "description": "steps per day. ONLY for kind=stepGoal.",
                ] as [String: Any],
                "setting": [
                    "type": "string",
                    "enum": ["standard", "softened", "lighter", "quieter",
                             "afterMeals", "anytime", "off"],
                    "description":
                        "weighCadence: standard|softened. loggingMode: standard|lighter. notificationPosture: standard|quieter. walkTiming: afterMeals|anytime|off.",
                ] as [String: Any],
            ], required: ["kind"]),
        ),
        JeniTool(
            name: "remember",
            kind: .actConfirmed,
            description: """
            remember something they told you about themselves that will still \
            matter next week: how they eat, what they can and cannot do, what \
            they want you to stop doing, what a normal day looks like for \
            them. the app shows them what you are writing down and they can \
            delete it later. do NOT remember passing moods, one-off events, \
            numbers the app already tracks, or anything about their body, \
            their diagnoses or their medication. keep the note short and in \
            their own terms, and write it with NO pronoun at all: "doesn't eat \
            before 11am", "works nights on weekends", "hates being told to push \
            through". they read these back in a list, so a note starting with \
            "they" or "you" reads like a report about a stranger.
            """,
            parameters: object([
                "note": [
                    "type": "string",
                    "description": "one short fact, lowercase, in their terms.",
                ] as [String: Any],
                "topic": [
                    "type": "string",
                    "enum": ["food", "movement", "schedule", "coaching", "life"],
                ] as [String: Any],
            ], required: ["note", "topic"]),
        ),
        JeniTool(
            name: "show_today_plan",
            kind: .actImmediate,
            description: "render today's plan beats inline. use when they ask what to do today.",
            parameters: noArgs
        ),
        JeniTool(
            name: "show_weight_trend",
            kind: .actImmediate,
            description: "render their weight trend inline and link to the full chart.",
            parameters: noArgs
        ),
        JeniTool(
            name: "open_dose_sheet",
            kind: .actImmediate,
            description: """
            open the dose sheet, which is where a dose is marked and where \
            their medication's own label facts about a late dose live. use \
            when they say they took it, forgot it, or are late. you never \
            mark a dose for them and you never restate the label rules \
            yourself.
            """,
            parameters: noArgs
        ),
        JeniTool(
            name: "open_weekly_read",
            kind: .actImmediate,
            description:
                "open the weekly read, the ritual where the plan changes. use when they want the whole week rather than one fact.",
            parameters: noArgs
        ),
        JeniTool(
            name: "open_lesson",
            kind: .actImmediate,
            description: "open today's method lesson (CBT-style read).",
            parameters: noArgs
        ),
        JeniTool(
            name: "start_breathwork",
            kind: .actImmediate,
            description: "start a breath session. style: calming or energizing.",
            parameters: object([
                "style": ["type": "string", "enum": ["calming", "energizing"]] as [String: Any],
            ], required: ["style"]),
        ),
        JeniTool(
            name: "set_reminder_hour",
            kind: .actConfirmed,
            description:
                "propose moving their daily reminder to a new hour (0-23, their local time). the app confirms first.",
            parameters: object([
                "hour": ["type": "integer", "minimum": 0, "maximum": 23] as [String: Any],
            ], required: ["hour"]),
        ),
    ]

    // MARK: - Lookup

    static let all: [JeniTool] = reads + acts

    private static let byName: [String: JeniTool] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.name, $0) }
    )

    static func tool(named name: String) -> JeniTool? { byName[name] }

    static func kind(of name: String) -> JeniToolKind {
        // An unknown name can only have come from a model that saw a
        // tool list we did not send. Treat it as inert.
        byName[name]?.kind ?? .actImmediate
    }

    static func isRead(_ name: String) -> Bool { kind(of: name) == .read }

    /// True when the tool must show a confirm card before it runs.
    /// The router reads THIS rather than keeping a second list, so
    /// the catalog and the router can never disagree.
    static func needsConfirmation(_ name: String) -> Bool {
        kind(of: name) == .actConfirmed
    }

    /// What goes on the wire.
    static var wireTools: [[String: Any]] { all.map(\.wireForm) }
}
