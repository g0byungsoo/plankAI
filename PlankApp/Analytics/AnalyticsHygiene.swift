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
    // p53: "intervalDays" joins the closed set — the N itself is a
    // schedule fact and never travels (categorical only).
    static let cadenceWords: Set<String> = ["weeklyAnchor", "daily", "asNeeded", "intervalDays", "unknown", "none"]
    static let regimenChangeWords: Set<String> = [
        "created", "reminder_toggle", "dose_changed", "medication_changed",
        "schedule_changed", "paused", "ended", "care_team_assigned",
    ]
    static let authorityWords: Set<String> = ["self", "care_team", "none"]

    /// The registry. Every v25-spine + v24-medication event carries a
    /// rule; legacy funnels join as they're touched.
    /// v25 E8 — the entry-method vocabulary, mirroring PlankFood's
    /// `EntryMethod`. The two lists are asserted equal by
    /// AnalyticsHygieneTests so the registry cannot drift behind a new
    /// input mode.
    /// E8.1 — `restaurant_estimate` and `quick_add` keep the spelling
    /// already present in `food_logs.source`. This vocabulary is now
    /// shared verbatim by the column, the enum and this property, so a
    /// rename would break historical insights for no gain.
    static let entryMethodWords: Set<String> = [
        "photo", "label", "words", "barcode", "again",
        "restaurant_estimate", "quick_add", "unknown",
    ]
    /// The `mode` vocabulary already in the field (photo/label/library/
    /// barcode) plus E8's `words`, which E7 shipped uninstrumented.
    static let scanModeWords: Set<String> = [
        "photo", "label", "library", "barcode", "words",
    ]

    /// E8.1 — the Method's trigger vocabulary, mirroring
    /// `MethodTrigger`. Asserted equal by MethodEngineTests so a new
    /// trigger cannot ship analytics-dark (the exact defect E8 spent an
    /// era working around on the words door).
    static let methodTriggerWords: Set<String> = [
        "proteinUnderFloorRepeatedly", "weightJumpedAgainstTrend",
        "trendFlatWhileLogging", "returnedAfterGap", "lateInDoseWeek",
        "weekendRecordDisappears", "movementBelowOwnBaseline",
        "firstPlateOnFile", "trendJustReadable",
        "proteinFloorMetFirstTime", "losingWithoutResistanceWork",
        "firstWeekClosing", "enteringMaintenance",
        // p53 — the breakfast gap + the salty-day bump join the
        // closed set (values of an existing categorical, additive).
        "morningProteinGap", "saltyDinnerScaleBump",
        // v25 E9 — additive only: two new VALUES of an existing
        // categorical property. `24_MEASUREMENT_CONTRACT.md` Q6 reports
        // `method_note_shown` broken down by `trigger`, so a new trigger
        // is a new row in an existing read, not a redefinition of one.
        // No event, no key and no existing word changed.
        "fluidsOnAQueasyDay", "constipationWithLowFiber",
        // p54 — the cycle bump and the deliberate end join the closed
        // set, same additive rule as above.
        "mensesOnsetScaleBump", "medicationRecentlyEnded",
    ]
    /// p54 — the evidence spine finally reaches the measurement: the
    /// tier's three raw values, so `method_note_shown` can report which
    /// grade of claim was on screen. Values, never sentences.
    static let methodTierWords: Set<String> = ["s", "rp", "a"]
    static let methodKindWords: Set<String> = [
        "vulnerability", "opportunity", "expectation",
    ]
    static let methodAuthorityWords: Set<String> = ["jeni", "care_team"]
    static let methodDoorWords: Set<String> = [
        "describePlate", "againSheet", "weightTrend", "breath", "move",
        "doseSheet", "askJeni", "none",
    ]

    static let rules: [String: Rule] = [
        AnalyticsEvent.methodNoteShown.rawValue: Rule(
            keys: ["note_id", "trigger", "kind", "authority", "has_action",
                   "evidence_tier"],
            words: [
                "trigger": methodTriggerWords,
                "kind": methodKindWords,
                "authority": methodAuthorityWords,
                "evidence_tier": methodTierWords,
            ]
        ),
        AnalyticsEvent.methodNoteAction.rawValue: Rule(
            keys: ["note_id", "trigger", "door", "authority"],
            words: [
                "trigger": methodTriggerWords,
                "door": methodDoorWords,
                "authority": methodAuthorityWords,
            ]
        ),
        AnalyticsEvent.methodNoteDismissed.rawValue: Rule(
            keys: ["note_id", "trigger"],
            words: ["trigger": methodTriggerWords]
        ),
        AnalyticsEvent.methodFollowUp.rawValue: Rule(
            keys: ["note_id", "trigger", "follow_up", "met"],
            words: ["trigger": methodTriggerWords]
        ),
        // v25 E8 — the food family joins the registry, per the law that
        // legacy funnels enrol as they are touched. These three carry
        // the only numbers that can falsify E7, so pinning their
        // vocabulary matters more than usual: a typo in `mode` would
        // read as "the words door was never used".
        AnalyticsEvent.foodLogSaved.rawValue: Rule(
            keys: ["items_count", "source", "entry_method"],
            words: ["entry_method": entryMethodWords]
        ),
        AnalyticsEvent.foodScanStarted.rawValue: Rule(
            keys: ["mode"],
            words: ["mode": scanModeWords]
        ),
        // `source` rides alongside `mode` on the older call sites and
        // carries its own words there ("barcode" / "library"), so it is
        // permitted but not pinned — `mode` is the key funnels group by.
        // p53: `from_usual` marks a words submit answered from her own
        // record instead of the estimate round trip (a Bool, no text).
        AnalyticsEvent.foodScanCompleted.rawValue: Rule(
            keys: ["mode", "source", "items_count", "has_restaurant_range",
                   "from_usual"],
            words: ["mode": scanModeWords]
        ),
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
                "source": [
                    "onboarding", "migration", "user", "weekly_read", "clinic",
                    "sync", "chat",
                ],
            ]
        ),
        // v25 E4 DAY TWO. The clause is the cascade's closed id set;
        // has_receipt is the era's headline metric (did the morning
        // have a record to read). Nothing the receipt CONTAINS may
        // ever be a property.
        AnalyticsEvent.morningReadShown.rawValue: Rule(
            keys: ["clause", "has_receipt", "has_intention"],
            words: [
                "clause": [
                    "break", "promise_kept", "day_one", "comeback_long",
                    "comeback_mid", "comeback_short", "tender", "day_two",
                    "yesterday_read", "rapid_loss", "band_reset",
                    "band_drifting", "first_down_week", "trend_down",
                    "trend_up", "band_held", "weigh_day", "short_sleep",
                    "season_luteal", "season_menstrual", "synthesis",
                    "steps_passed", "week_opens", "tonight_plan",
                    "archetype",
                ],
            ]
        ),
        AnalyticsEvent.foodRelogUsed.rawValue: Rule(
            keys: ["surface"],
            words: ["surface": ["camera", "chooser", "book", "plate_page", "reading"]]
        ),
        // v25 ship — the evening close's two moments. Booleans only:
        // what stood on the screen, never what the record contained.
        AnalyticsEvent.eveningCloseShown.rawValue: Rule(
            keys: ["protein_met", "has_intention"]
        ),
        AnalyticsEvent.eveningIntentionSet.rawValue: Rule(keys: []),
        AnalyticsEvent.foodPriorApplied.rawValue: Rule(
            keys: ["kind", "action"],
            words: [
                "kind": ["dish_numbers"],
                "action": ["applied", "reverted"],
            ]
        ),
        // v25 E3 ONE JENI. The tool NAME is a categorical, and
        // `had_data` is the era's honesty metric: how often the record
        // was actually there when jeni went looking. Nothing the read
        // RETURNED may ever be a property.
        AnalyticsEvent.jeniReadToolCalled.rawValue: Rule(
            keys: ["tool", "had_data"],
            words: [
                "tool": [
                    "read_food_day", "read_food_week", "read_weight_trend",
                    "read_dose_history", "read_symptoms", "read_patterns",
                    "read_activity", "read_program",
                ],
            ]
        ),
        // The TOPIC only. The note itself is the user's own sentence
        // about themselves and never leaves the device.
        AnalyticsEvent.jeniMemoryWritten.rawValue: Rule(
            keys: ["topic"],
            words: ["topic": ["food", "movement", "schedule", "coaching", "life"]]
        ),
        AnalyticsEvent.jeniProgramProposalAccepted.rawValue: Rule(
            keys: ["kind"],
            words: [
                "kind": [
                    "stepGoal", "weighCadence", "loggingMode",
                    "notificationPosture", "walkTiming",
                ],
            ]
        ),
        // v25 §45 — the structural sync refusal. `family` and `reason`
        // are closed vocabularies; `code` is a machine token (SQLSTATE
        // or PGRSTnnn) that `SyncHealth.safeCode` flattens to "other"
        // unless it is 5-9 alphanumerics. THE SERVER'S MESSAGE AND HINT
        // ARE NEVER PROPERTIES: PostgREST's 42501 hint prints the exact
        // GRANT statement and names the table.
        AnalyticsEvent.syncStructuralFailure.rawValue: Rule(
            keys: ["family", "reason", "code"],
            words: [
                "family": ["program_facts", "weekly_reads"],
                "reason": [
                    "permission_denied", "schema_mismatch", "authorization",
                    "constraint_rejected", "unclassified",
                ],
            ]
        ),
        AnalyticsEvent.notifCandidate.rawValue: Rule(
            keys: ["category", "admitted", "why"],
            words: ["why": ["silenced", "ok", "budget"]]
        ),
        AnalyticsEvent.notifDelivered.rawValue: Rule(keys: ["category", "actioned"]),
        AnalyticsEvent.notifSilenced.rawValue: Rule(keys: ["category"]),

        // pass 52 — THE DAY-ONE CONTRACT (the notification moment).
        // Shown/answered flags and one boolean; never a record detail.
        "day_one_contract_shown": Rule(keys: []),
        "day_one_contract_accepted": Rule(keys: []),
        "day_one_contract_declined": Rule(keys: []),
        "day_one_contract_permission": Rule(keys: ["granted"]),
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
