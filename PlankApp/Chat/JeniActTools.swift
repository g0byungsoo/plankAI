import Foundation
import SwiftData
import PlankSync
import PlankFood

// MARK: - JeniActTools (v25 E3 ONE JENI)
//
// docs/app_v25/12_E3_ONE_JENI.md §5. THE PLAN IS NEGOTIABLE IN WORDS.
//
// E1 built the program's memory with a full authority law — prescribed
// › preferred › recommended › defaulted, consent-gated, iOS never
// writes prescribed, supersede-never-mutate. And it gave that memory
// exactly ONE door: the weekly read, which needs a week. 82% of people
// who finish onboarding never have a second day, let alone a seventh.
//
// So the plan gets a second door, and it is the one people already
// use: sentences. "make my step goal 6000." "stop asking me to weigh
// so often." "keep it quieter." Those land as real, recorded,
// superseding facts — through the SAME chokepoint the read uses, with
// the same authority, the same clamps and the same history.
//
// THE LAWS THAT DO NOT BEND:
//
//  1. A CHAT PROPOSAL IS A PREFERENCE, NEVER A PRESCRIPTION. The S4
//     law (iOS writes authority=self alone) is structural here: the
//     store is called with `.preferred` and nothing else can be
//     passed in.
//  2. A PRESCRIBED HEAD REFUSES. If the resolved head for that kind
//     came from their clinician, the tool does not write, does not
//     "add a preference underneath", and returns a refusal the model
//     must route on. Their clinician's plan is not overridable by
//     talking to a coach.
//  3. NOTHING WRITES WITHOUT A TAP. Every act here that changes state
//     is `.actConfirmed` in the catalog, so the card comes first.
//     This file is only ever reached after the user pressed yes.
//  4. VALUE COHERENCE IS CHECKED HERE, NOT TRUSTED. A model that
//     sends `walkTiming` with `softened` gets a refusal, not a
//     corrupted fact chain.

@MainActor
enum JeniActTools {

    // MARK: - Program facts

    /// The closed set chat may touch. Deliberately EXCLUDES
    /// proteinAdjust and movesAdjust (clinical advisory bands the
    /// weekly read composes from rules — a coach doing dietary maths
    /// in a chat turn is the shape of the never-dose-advice redline)
    /// and readAnchor (structural).
    static let proposableKinds: Set<ProgramFactKind> = [
        .stepGoal, .weighCadence, .loggingMode, .notificationPosture, .walkTiming,
    ]

    struct ProposalOutcome {
        let applied: Bool
        let payload: [String: Any]
    }

    /// Parse + validate a proposal without touching the store, so the
    /// confirm card can render the real sentence and the refusals are
    /// pinnable. Returns nil when the arguments are incoherent.
    static func parseProposal(
        _ arguments: [String: Any]
    ) -> (kind: ProgramFactKind, value: ProgramFactValue)? {
        guard
            let raw = arguments["kind"] as? String,
            let kind = ProgramFactKind(rawValue: raw),
            proposableKinds.contains(kind)
        else { return nil }

        if kind.isWordKind {
            guard let word = arguments["setting"] as? String,
                  ProgramFacts.isValidWord(word, kind: kind)
            else { return nil }
            return (kind, .word(word))
        }
        let steps: Int?
        if let n = arguments["steps"] as? Int { steps = n }
        else if let d = arguments["steps"] as? Double { steps = Int(d) }
        else if let n = arguments["value"] as? Int { steps = n }
        else if let d = arguments["value"] as? Double { steps = Int(d) }
        else { steps = nil }
        guard let steps, steps > 0 else { return nil }
        return (kind, .int(steps))
    }

    /// The line the confirm card shows. It states what will be true,
    /// not what the model asked for.
    static func proposalLabel(
        _ arguments: [String: Any]
    ) -> String? {
        guard let (kind, value) = parseProposal(arguments) else { return nil }
        switch (kind, value) {
        case (.stepGoal, .int(let steps)):
            return "make your step goal \(steps.formatted(.number.grouping(.automatic)))?"
        case (.weighCadence, .word(let w)):
            return w == "softened"
                ? "weigh in less often?"
                : "go back to the usual weigh-in rhythm?"
        case (.loggingMode, .word(let w)):
            return w == "lighter"
                ? "switch to lighter logging?"
                : "go back to full logging?"
        case (.notificationPosture, .word(let w)):
            return w == "quieter"
                ? "keep your notifications quieter?"
                : "go back to the usual notifications?"
        case (.walkTiming, .word(let w)):
            switch w {
            case "afterMeals": return "put your walk after meals?"
            case "anytime":    return "walk whenever suits you?"
            default:           return "stop suggesting walks?"
            }
        default:
            return nil
        }
    }

    static func proposeProgramFact(
        _ arguments: [String: Any],
        userId: String,
        in context: ModelContext,
        now: Date = .now
    ) -> ProposalOutcome {
        guard !userId.isEmpty else {
            return .init(applied: false, payload: [
                "applied": false, "reason": "no account",
            ])
        }
        guard let (kind, value) = parseProposal(arguments) else {
            return .init(applied: false, payload: [
                "applied": false,
                "reason": "that isn't something you can change here",
            ])
        }

        // LAW 2 — a prescribed head refuses, loudly and usefully.
        if let head = ProgramFactStore.head(kind, userId: userId, in: context),
           head.authority == .prescribed {
            return .init(applied: false, payload: [
                "applied": false,
                "reason": "prescribed",
                "say": "that one is set by their care team, so it isn't yours or theirs to change here. tell them it's their clinician's, and that the correction door in their medication settings is how they flag it.",
            ])
        }

        let applied = ProgramFactStore.apply(
            kind,
            value: value,
            authority: .preferred,
            basis: .stated,
            source: "chat",
            userId: userId,
            now: now,
            in: context
        )
        guard applied != nil else {
            return .init(applied: false, payload: [
                "applied": false, "reason": "couldn't record that",
            ])
        }
        Analytics.track(
            .jeniProgramProposalAccepted,
            properties: ["kind": kind.rawValue]
        )
        var payload: [String: Any] = ["applied": true, "kind": kind.rawValue]
        // Report the STORED value, not the requested one: the clamp
        // may have moved it and jeni must acknowledge what is true.
        if let stored = ProgramFactStore.headValue(kind, userId: userId, in: context) {
            switch stored {
            case .int(let v): payload["value"] = v
            case .word(let w): payload["value"] = w
            }
        }
        payload["authority"] = "preferred"
        payload["note"] = "recorded as their own preference. it beats anything you recommend from now on."
        return .init(applied: true, payload: payload)
    }

    // MARK: - Memory

    static func rememberLabel(_ arguments: [String: Any]) -> String? {
        guard
            let note = arguments["note"] as? String,
            let topic = arguments["topic"] as? String,
            case let .accept(clean, _) = MemoryGuard.screen(note: note, topic: topic)
        else { return nil }
        return "remember: \(clean)"
    }

    static func remember(
        _ arguments: [String: Any],
        userId: String,
        in context: ModelContext,
        now: Date = .now
    ) -> [String: Any] {
        guard
            let note = arguments["note"] as? String,
            let topic = arguments["topic"] as? String
        else { return ["remembered": false, "reason": "malformed"] }

        switch MemoryGuard.screen(note: note, topic: topic) {
        case .refuse(let reason):
            return [
                "remembered": false,
                "reason": reason,
                "say": "don't tell them you wrote it down. that isn't something to keep a note about.",
            ]
        case .accept:
            guard let record = JeniMemoryStore.remember(
                note: note, topic: topic, userId: userId, now: now, in: context
            ) else {
                return ["remembered": false, "reason": "couldn't store it"]
            }
            Analytics.track(
                .jeniMemoryWritten, properties: ["topic": record.topic]
            )
            return [
                "remembered": true,
                "note": record.note,
                "topic": record.topic,
                "say": "acknowledge it in half a sentence and move on. don't make a ceremony of it.",
            ]
        }
    }

    // MARK: - Food from words

    /// Jeni never writes a food log herself: she hands the words to
    /// the same describe pipeline the app's own "describe it" door
    /// uses, and the user sees the estimate before it lands. An
    /// LLM-authored plate that skipped the reading would be a number
    /// with no provenance, which is the one thing food may not be.
    static func logFoodText(
        _ arguments: [String: Any]
    ) -> [String: Any] {
        guard let description = (arguments["description"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            description.count >= 3
        else { return ["opened": false, "reason": "nothing to log"] }
        AppRouter.shared.openFoodDescribe(text: description)
        return [
            "opened": true,
            "note": "the describe sheet is open with their words in it. they will see the estimate and confirm. do not state calories yourself.",
        ]
    }
}
