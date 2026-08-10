import Foundation

// MARK: - AnalyticsHygiene (v25 E2 — B1)
//
// The hygiene law (00_THE_SYSTEM §13/§14), finally a mechanism instead
// of a convention: analytics payloads are counts, choices and
// categoricals ONLY — never a dose, a product name, a site, a weight,
// a timestamp beyond the wrapper's own, or free text. Events in this
// registry are validated on every DEBUG track() call; a violation is
// an assertion failure, so a leaking payload cannot survive a debug
// run of its surface. Growing the registry with every new event
// family is the law; the unit suite pins the spine + medication
// families as present.

enum AnalyticsHygiene {

    struct Rule {
        /// The complete set of allowed payload keys for the event.
        let keys: Set<String>
        /// Closed vocabularies for keys whose words are stable law.
        /// Keys absent here are pattern-checked only.
        let words: [String: Set<String>]

        init(keys: Set<String>, words: [String: Set<String>] = [:]) {
            self.keys = keys
            self.words = words
        }
    }

    /// Keys the wrapper stamps on every event after validation.
    static let stampedKeys: Set<String> = [
        "app_version", "timestamp", "environment", "is_test_user",
    ]

    /// A categorical word: a machine token, never prose. (Spaces are
    /// the free-text tell; units ride digits+letters and fail the
    /// length/shape gate in practice.)
    private static let wordChars = CharacterSet(
        charactersIn: "abcdefghijklmnopqrstuvwxyz"
            + "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.:-"
    )

    static func isCategoricalWord(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 40
            && s.unicodeScalars.allSatisfy { wordChars.contains($0) }
    }

    static let doseStatusWords: Set<String> = ["taken", "skipped", "unmarked"]
    static let doseSourceWords: Set<String> = ["checklist", "sheet", "notification", "evening"]
    static let routeWords: Set<String> = ["injection", "oral", "unknown", "none"]
    static let cadenceWords: Set<String> = ["weeklyAnchor", "daily", "asNeeded", "unknown", "none"]
    static let regimenChangeWords: Set<String> = [
        "created", "reminder_toggle", "dose_changed", "medication_changed",
        "schedule_changed", "paused", "ended", "care_team_assigned",
    ]
    static let authorityWords: Set<String> = ["self", "care_team", "none"]

    /// The registry. Every v25-spine + v24-medication event carries a
    /// rule; legacy funnels join as they're touched.
    static let rules: [String: Rule] = [
        AnalyticsEvent.doseMarked.rawValue: Rule(
            keys: ["status", "source", "route", "cadence", "late"],
            words: [
                "status": doseStatusWords,
                "source": doseSourceWords,
                "route": routeWords,
                "cadence": cadenceWords,
            ]
        ),
        AnalyticsEvent.doseReminderAction.rawValue: Rule(
            keys: ["action"],
            words: ["action": ["taken", "snooze", "log_later"]]
        ),
        AnalyticsEvent.regimenChanged.rawValue: Rule(
            keys: ["change", "route", "cadence", "authority"],
            words: [
                "change": regimenChangeWords,
                "route": routeWords,
                "cadence": cadenceWords,
                "authority": authorityWords,
            ]
        ),
        AnalyticsEvent.sideEffectLogged.rawValue: Rule(
            keys: ["symptom", "severity", "action"],
            words: ["action": ["logged", "cleared"]]
        ),
        AnalyticsEvent.walkActionShown.rawValue: Rule(keys: []),
        AnalyticsEvent.walkGoalHit.rawValue: Rule(keys: []),
        AnalyticsEvent.healthkitRequested.rawValue: Rule(
            keys: ["source", "action"],
            words: [
                "source": ["onboarding", "settings"],
                "action": ["completed", "skipped"],
            ]
        ),
        AnalyticsEvent.weeklyReadShown.rawValue: Rule(
            keys: ["anchor", "offer", "signals"],
            words: ["anchor": ["preference", "doseDay", "enrollment"]]
        ),
        AnalyticsEvent.weeklyReadDecision.rawValue: Rule(
            keys: ["anchor", "offer", "decision", "fact_written"],
            words: [
                "anchor": ["preference", "doseDay", "enrollment"],
                "decision": ["accepted", "declined", "kept"],
            ]
        ),
        AnalyticsEvent.programFactChanged.rawValue: Rule(
            keys: ["kind", "authority", "source"],
            words: [
                "authority": ["prescribed", "preferred", "recommended", "defaulted"],
                "source": ["onboarding", "migration", "user", "weekly_read", "clinic", "sync"],
            ]
        ),
        AnalyticsEvent.notifCandidate.rawValue: Rule(
            keys: ["category", "admitted", "why"],
            words: ["why": ["silenced", "ok", "budget"]]
        ),
        AnalyticsEvent.notifDelivered.rawValue: Rule(keys: ["category", "actioned"]),
        AnalyticsEvent.notifSilenced.rawValue: Rule(keys: ["category"]),
    ]

    /// Empty = clean. Unregistered events return no violations (the
    /// registry is grown deliberately, not inferred).
    static func violations(event: String, properties: [String: Any]) -> [String] {
        guard let rule = rules[event] else { return [] }
        var found: [String] = []
        for (key, value) in properties {
            if stampedKeys.contains(key) { continue }
            guard rule.keys.contains(key) else {
                found.append("unregistered key '\(key)'")
                continue
            }
            switch value {
            case let s as String:
                if !isCategoricalWord(s) {
                    found.append("'\(key)' carries a non-categorical string")
                } else if let vocab = rule.words[key], !vocab.contains(s) {
                    found.append("'\(key)' word '\(s)' outside its closed vocabulary")
                }
            case is Int, is Bool:
                break
            default:
                found.append("'\(key)' carries a non-categorical type")
            }
        }
        return found
    }
}
