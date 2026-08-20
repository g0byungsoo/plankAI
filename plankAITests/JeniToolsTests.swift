import XCTest
import SwiftData
@testable import plankAI
import PlankSync

// MARK: - JeniToolsTests (v25 E3 ONE JENI)
//
// The era's laws, pinned. In the order they matter:
//
//   1. A read that has nothing says so. The whole value of giving the
//      coach a record is lost the moment she fills a gap with
//      plausible prose, so "no plates that day" must survive as a
//      REFUSAL to answer, not as zero.
//   2. A prescribed fact refuses a chat proposal. The S4/E1 authority
//      law does not weaken because the door changed.
//   3. Memory keeps out what a model must never write down about a
//      person, and keeps itself small.
//   4. The catalog and the router agree, always. Two lists that can
//      drift are a bug waiting for a release.

@MainActor
final class JeniToolsTests: XCTestCase {

    private var context: ModelContext { TestModelContainer.shared.mainContext }
    private let user = "E3-TOOLS-USER"
    private let otherUser = "E3-TOOLS-USER-B"

    override func setUp() {
        super.setUp()
        JeniMemoryStore.forgetAll(userId: user, in: context)
        JeniMemoryStore.forgetAll(userId: otherUser, in: context)
        for kind in ProgramFactKind.allCases {
            for record in ProgramFactStore.history(kind, userId: user, in: context) {
                context.delete(record)
            }
        }
        try? context.save()
    }

    // MARK: - 1 · The catalog and the router agree

    func testEveryReadToolIsPrefixedAndClassifiedAsRead() {
        for tool in JeniToolCatalog.reads {
            XCTAssertTrue(
                tool.name.hasPrefix("read_"),
                "\(tool.name) is a read but isn't named like one"
            )
            XCTAssertTrue(JeniToolCatalog.isRead(tool.name))
            XCTAssertTrue(ChatToolRouter.isRead(tool.name))
            XCTAssertFalse(
                ChatToolRouter.needsConfirmation(tool.name),
                "a read must never ask for confirmation"
            )
        }
    }

    func testNoActToolIsMistakenForARead() {
        for tool in JeniToolCatalog.acts {
            XCTAssertFalse(JeniToolCatalog.isRead(tool.name), tool.name)
            XCTAssertFalse(tool.name.hasPrefix("read_"), tool.name)
        }
    }

    func testEveryStateChangingToolAsksFirst() {
        // The ones that write to a store or a plan. Opening a screen
        // does not need a card; changing a fact always does.
        for name in ["log_weight", "log_food_text", "propose_program_fact",
                     "remember", "set_reminder_hour"] {
            XCTAssertTrue(
                ChatToolRouter.needsConfirmation(name),
                "\(name) changes something and must show a card"
            )
        }
    }

    func testEveryToolHasAWireFormWithASchema() {
        for tool in JeniToolCatalog.all {
            let wire = tool.wireForm
            let fn = wire["function"] as? [String: Any]
            XCTAssertNotNil(fn?["name"] as? String, tool.name)
            XCTAssertNotNil(fn?["description"] as? String, tool.name)
            XCTAssertNotNil(fn?["parameters"] as? [String: Any], tool.name)
            XCTAssertFalse(
                (fn?["description"] as? String ?? "").contains("—"),
                "\(tool.name)'s description carries an em-dash (voice law)"
            )
        }
        XCTAssertEqual(
            JeniToolCatalog.wireTools.count, JeniToolCatalog.all.count
        )
    }

    func testCardLabelsNeverCarryAnEmDash() {
        // The card is user-facing copy; the ban applies (feedback law).
        let calls: [ChatToolCall] = [
            .init(id: "1", name: "log_weight", arguments: ["kg": 74.2]),
            .init(id: "2", name: "log_food_text",
                  arguments: ["description": "chicken burrito"]),
            .init(id: "3", name: "propose_program_fact",
                  arguments: ["kind": "stepGoal", "steps": 6000]),
            .init(id: "4", name: "remember",
                  arguments: ["note": "doesn't eat before 11am", "topic": "food"]),
            .init(id: "5", name: "open_dose_sheet", arguments: [:]),
        ]
        for call in calls {
            let label = ChatToolRouter.cardLabel(for: call)
            XCTAssertFalse(label.contains("—"), label)
            XCTAssertFalse(label.contains("--"), label)
            XCTAssertEqual(label, label.lowercased(), label)
        }
    }

    // MARK: - 2 · A read with nothing says nothing

    func testReadsOnAnEmptyRecordRefuseRatherThanInvent() {
        for name in ["read_food_day", "read_food_week", "read_weight_trend",
                     "read_dose_history", "read_symptoms", "read_patterns",
                     "read_program"] {
            let args: [String: Any] = name == "read_food_day" ? ["days_ago": 3] : [:]
            let result = JeniReadTools.execute(
                .init(id: "t", name: name, arguments: args),
                userId: otherUser, in: context
            )
            XCTAssertEqual(
                result["have"] as? Bool, false,
                "\(name) claimed data on an empty record"
            )
            XCTAssertNotNil(
                result["why"] as? String,
                "\(name) refused without saying why"
            )
        }
    }

    func testAnUnloggedDayIsNotAZeroCalorieDay() {
        let result = JeniReadTools.execute(
            .init(id: "t", name: "read_food_day", arguments: ["days_ago": 5]),
            userId: otherUser, in: context
        )
        XCTAssertEqual(result["have"] as? Bool, false)
        XCTAssertNil(result["kcal_total"], "an unlogged day must carry no total")
        XCTAssertTrue(
            (result["why"] as? String ?? "").contains("not the same as not eaten"),
            "the unrecorded-is-not-skipped law must reach the model"
        )
    }

    /// The standing body-privacy floor, at the newest surface it could
    /// leak from. A suppressed cohort sees no kcal and no weight
    /// anywhere on screen; a tool result is a screen the model reads,
    /// and it must obey the same law.
    func testNumericSuppressionStripsTheNumbersFromEveryRead() {
        let d = UserDefaults.standard
        d.set(true, forKey: "safety_numeric_suppression")
        defer { d.set(false, forKey: "safety_numeric_suppression") }

        let weight = JeniReadTools.execute(
            .init(id: "t", name: "read_weight_trend", arguments: [:]),
            userId: user, in: context
        )
        XCTAssertEqual(weight["have"] as? Bool, false)
        XCTAssertNil(weight["latest"])
        XCTAssertNil(weight["trend"])
        XCTAssertNil(weight["weekly_change"])

        let day = JeniReadTools.execute(
            .init(id: "t", name: "read_food_day", arguments: ["days_ago": 1]),
            userId: user, in: context
        )
        XCTAssertNil(day["kcal_total"])
        XCTAssertNil(day["protein_total_g"])
        XCTAssertNil(day["kcal_target"])
        for plate in (day["plates"] as? [[String: Any]]) ?? [] {
            XCTAssertNil(plate["kcal"], "a suppressed cohort's plate carried kcal")
            XCTAssertNil(plate["protein_g"])
        }

        let week = JeniReadTools.execute(
            .init(id: "t", name: "read_food_week", arguments: [:]),
            userId: user, in: context
        )
        XCTAssertNil(week["avg_kcal_on_logged_days"])
        XCTAssertNil(week["avg_protein_g_on_logged_days"])
    }

    /// The v8 privacy line: the compound, never the brand — inside a
    /// tool result exactly as in copy.
    func testNoReadEverReturnsADrugBrandName() {
        let brands = ["ozempic", "wegovy", "mounjaro", "zepbound",
                      "saxenda", "trulicity", "rybelsus"]
        let dose = JeniReadTools.execute(
            .init(id: "t", name: "read_dose_history", arguments: [:]),
            userId: user, in: context
        )
        let dumped = String(describing: dose).lowercased()
        for brand in brands {
            XCTAssertFalse(dumped.contains(brand), "read_dose_history leaked \(brand)")
        }
    }

    func testAnUnknownReadIsInertRatherThanGuessed() {
        let result = JeniReadTools.execute(
            .init(id: "t", name: "read_horoscope", arguments: [:]),
            userId: user, in: context
        )
        XCTAssertEqual(result["have"] as? Bool, false)
    }

    func testWeekdayResolutionNeverReturnsTodayOrTheFuture() {
        let cal = Calendar.current
        let now = Date(timeIntervalSince1970: 1_786_000_000)   // a fixed wednesday-ish
        for day in ["monday", "tuesday", "wednesday", "thursday",
                    "friday", "saturday", "sunday"] {
            guard let resolved = JeniReadTools.resolveDay(
                ["weekday": day], calendar: cal, now: now
            ) else {
                XCTFail("\(day) didn't resolve")
                continue
            }
            XCTAssertLessThan(
                resolved, now, "\(day) resolved to today or later"
            )
            XCTAssertGreaterThan(
                resolved, cal.date(byAdding: .day, value: -8, to: now)!,
                "\(day) resolved further back than one week"
            )
        }
    }

    func testDaysAgoIsBoundedAndBeatsWeekday() {
        let cal = Calendar.current
        let now = Date()
        XCTAssertNil(JeniReadTools.resolveDay(["days_ago": 0], calendar: cal, now: now))
        XCTAssertNil(JeniReadTools.resolveDay(["days_ago": 999], calendar: cal, now: now))
        XCTAssertNil(JeniReadTools.resolveDay([:], calendar: cal, now: now))
        let both = JeniReadTools.resolveDay(
            ["days_ago": 2, "weekday": "monday"], calendar: cal, now: now
        )
        XCTAssertEqual(
            cal.dateComponents([.day], from: both!, to: now).day, 2,
            "days_ago must win when both are sent"
        )
    }

    // MARK: - 3 · The authority law holds through the new door

    func testProposalParsingRejectsIncoherentValues() {
        // a word where an int belongs
        XCTAssertNil(JeniActTools.parseProposal(
            ["kind": "stepGoal", "setting": "softened"]
        ))
        // a vocabulary word from the WRONG kind
        XCTAssertNil(JeniActTools.parseProposal(
            ["kind": "walkTiming", "setting": "softened"]
        ))
        // a clinical kind chat may never touch
        XCTAssertNil(JeniActTools.parseProposal(
            ["kind": "proteinAdjust", "steps": 5]
        ))
        XCTAssertNil(JeniActTools.parseProposal(
            ["kind": "movesAdjust", "steps": 1]
        ))
        // structural
        XCTAssertNil(JeniActTools.parseProposal(["kind": "readAnchor", "setting": "auto"]))
        // and the good ones parse
        XCTAssertNotNil(JeniActTools.parseProposal(["kind": "stepGoal", "steps": 6000]))
        XCTAssertNotNil(JeniActTools.parseProposal(
            ["kind": "weighCadence", "setting": "softened"]
        ))
    }

    func testAcceptedProposalLandsAsPreferredNeverPrescribed() {
        let outcome = JeniActTools.proposeProgramFact(
            ["kind": "stepGoal", "steps": 6000], userId: user, in: context
        )
        XCTAssertTrue(outcome.applied)
        let head = ProgramFactStore.head(.stepGoal, userId: user, in: context)
        XCTAssertEqual(head?.authority, .preferred)
        XCTAssertEqual(head?.value, .int(6000))
        XCTAssertEqual(outcome.payload["authority"] as? String, "preferred")
    }

    func testAPrescribedFactRefusesAndRoutes() {
        // Only sync may author a prescription, so build the record the
        // way hydrate does rather than through the (correctly refusing)
        // write chokepoint.
        let prescribed = ProgramFactRecord(
            userId: user,
            kind: ProgramFactKind.stepGoal.rawValue,
            value: ProgramFactValue.int(4000).encoded,
            authority: ProgramFactAuthority.prescribed.rawValue,
            basis: ProgramFactBasis.assigned.rawValue,
            source: "clinic"
        )
        context.insert(prescribed)
        try? context.save()

        let outcome = JeniActTools.proposeProgramFact(
            ["kind": "stepGoal", "steps": 9000], userId: user, in: context
        )
        XCTAssertFalse(outcome.applied, "a clinician's fact was overwritten from chat")
        XCTAssertEqual(outcome.payload["reason"] as? String, "prescribed")
        XCTAssertNotNil(outcome.payload["say"], "the refusal must tell jeni where to route")
        // and nothing was written underneath it
        let head = ProgramFactStore.head(.stepGoal, userId: user, in: context)
        XCTAssertEqual(head?.authority, .prescribed)
        XCTAssertEqual(head?.value, .int(4000))
        XCTAssertNil(
            ProgramFactStore.history(.stepGoal, userId: user, in: context)
                .first(where: { $0.source == "chat" }),
            "a refused proposal must leave no chat-authored row at all"
        )
    }

    func testProposalReportsTheStoredValueNotTheRequestedOne() {
        // Preference rails are wide but real (1,000…30,000).
        let outcome = JeniActTools.proposeProgramFact(
            ["kind": "stepGoal", "steps": 400_000], userId: user, in: context
        )
        XCTAssertTrue(outcome.applied)
        XCTAssertEqual(
            outcome.payload["value"] as? Int, 30_000,
            "jeni must acknowledge what the store kept, not what she asked for"
        )
    }

    func testProposalIsScopedToItsOwnUser() {
        _ = JeniActTools.proposeProgramFact(
            ["kind": "weighCadence", "setting": "softened"],
            userId: user, in: context
        )
        XCTAssertNil(
            ProgramFactStore.head(.weighCadence, userId: otherUser, in: context)
        )
    }

    // MARK: - 4 · Memory keeps out what it must

    func testMemoryRefusesWhatAModelMustNotWriteDown() {
        let refusals: [(String, String)] = [
            ("takes 1.0 mg of semaglutide on tuesdays", "food"),
            ("was diagnosed with pcos", "life"),
            ("weighs 210 and looks heavier than that", "life"),
            ("has bad nausea after the shot", "food"),
            ("thinks she is fat", "life"),
            ("purges after big meals", "food"),
            ("their calorie target is 1400", "food"),
            ("ok", "food"),                                   // too short
            (String(repeating: "a", count: 200), "food"),     // too long
            ("eats late", "astrology"),                       // unknown topic
        ]
        for (note, topic) in refusals {
            guard case .refuse = MemoryGuard.screen(note: note, topic: topic) else {
                XCTFail("accepted a note it must refuse: \(note)")
                continue
            }
        }
    }

    func testMemoryAcceptsTheThingsAPersonActuallySays() {
        let accepts: [(String, String)] = [
            ("doesn't eat before 11am", "food"),
            ("works nights on weekends", "schedule"),
            ("hates being told to just push through", "coaching"),
            ("can't do anything on their knees", "movement"),
            ("cooks for four every evening", "life"),
        ]
        for (note, topic) in accepts {
            guard case .accept = MemoryGuard.screen(note: note, topic: topic) else {
                XCTFail("refused a legitimate note: \(note)")
                continue
            }
        }
    }

    func testRefusedNotesNeverReachTheStore() {
        let result = JeniActTools.remember(
            ["note": "takes 2.4 mg every tuesday", "topic": "life"],
            userId: user, in: context
        )
        XCTAssertEqual(result["remembered"] as? Bool, false)
        XCTAssertTrue(JeniMemoryStore.active(userId: user, in: context).isEmpty)
        XCTAssertNotNil(
            result["say"], "jeni must be told not to claim she wrote it down"
        )
    }

    func testARestatedFactSupersedesRatherThanContradicts() {
        JeniMemoryStore.remember(
            note: "doesn't eat before 11am", topic: "food",
            userId: user, in: context
        )
        JeniMemoryStore.remember(
            note: "doesn't eat before noon", topic: "food",
            userId: user, in: context
        )
        let active = JeniMemoryStore.active(userId: user, in: context)
        XCTAssertEqual(active.count, 1, "two versions of one fact are both live")
        XCTAssertEqual(active.first?.note, "doesn't eat before noon")
    }

    func testTheSameNoteTwiceDoesNotDuplicate() {
        JeniMemoryStore.remember(
            note: "works nights", topic: "schedule", userId: user, in: context
        )
        JeniMemoryStore.remember(
            note: "works nights", topic: "schedule", userId: user, in: context
        )
        XCTAssertEqual(JeniMemoryStore.active(userId: user, in: context).count, 1)
    }

    func testATopicStaysSmallEnoughToRead() {
        for i in 0..<(JeniMemoryStore.maxNotesPerTopic + 3) {
            JeniMemoryStore.remember(
                note: "likes food number \(i) very much indeed",
                topic: "food", userId: user, in: context
            )
        }
        let food = JeniMemoryStore.active(userId: user, in: context)
            .filter { $0.topic == "food" }
        XCTAssertLessThanOrEqual(food.count, JeniMemoryStore.maxNotesPerTopic)
    }

    func testMemoryIsScopedToItsOwnUser() {
        JeniMemoryStore.remember(
            note: "cooks for four every evening", topic: "life",
            userId: user, in: context
        )
        XCTAssertTrue(JeniMemoryStore.active(userId: otherUser, in: context).isEmpty)
        XCTAssertTrue(JeniMemoryStore.envelope(userId: otherUser, in: context).isEmpty)
    }

    func testForgettingIsReal() {
        let record = JeniMemoryStore.remember(
            note: "hates the word deficit", topic: "coaching",
            userId: user, in: context
        )
        XCTAssertNotNil(record)
        JeniMemoryStore.forget(id: record!.id, userId: user, in: context)
        XCTAssertTrue(JeniMemoryStore.active(userId: user, in: context).isEmpty)
    }

    // p53 RE-PIN: verbatim, DATED. Her words still arrive unaltered
    // — the age rides as a delimited parenthetical, because a note
    // from february and a note from yesterday were reaching jeni as
    // the same undated string (a stale fact spoken with fresh
    // confidence). The pin caught the copy change exactly as a pin
    // should; the words themselves stay hers.
    func testTheEnvelopeCarriesNotesVerbatimAndDated() {
        JeniMemoryStore.remember(
            note: "hates the word deficit", topic: "coaching",
            userId: user, in: context
        )
        let envelope = JeniMemoryStore.envelope(userId: user, in: context)
        XCTAssertEqual(envelope["coaching"], ["hates the word deficit (told today)"])
    }
}
