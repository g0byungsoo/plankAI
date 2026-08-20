import Foundation

// MARK: - MethodCatalog — the default B2C content
//
// One note per detectable state — never a library. The count grows
// only when a NEW state becomes detectable in her own record, and a
// pass-53 header that said "thirteen" while the file held seventeen
// is why the number no longer lives in this comment.
//
// Every one had to pass the same five questions before it was written:
//
//   WHO does it help · WHEN should it appear · WHY does it matter ·
//   WHAT should she understand afterwards · WHEN should Jeni stay quiet
//
// and one more that killed several candidates: WHAT ACTION FOLLOWS. A
// note with no next move is an article, and this file is not allowed to
// contain articles.
//
// ─── WHAT WAS CONSIDERED AND LEFT OUT, AND WHY ──────────────────────
//
// The brief listed thirty candidate domains. These were rejected, each
// for a reason, because a thing that ships without a reason is content:
//
//   emotional eating · body image · identity · motivation
//     Real, and the old corpus' actual subject. Left out because the
//     product cannot DETECT them. A note that fires on a guess about
//     someone's feelings is worse than silence, and this cohort has
//     been guessed at enough. If a signal ever exists (she says it, in
//     chat, and it is remembered), the note can be written then.
//
//   restaurants · travel · alcohol · social eating · shopping · meal
//   prep · portion awareness
//     Situational, and the product has no situation signal. These are
//     what a person asks Jeni about, and chat answers from the same
//     evidence — which is the right surface for a question, where a
//     note is the right surface for an observation.
//
//   coming off medication · weight regain after stopping
//     The single highest-value teaching in the whole domain: one year
//     after stopping semaglutide people had regained two thirds of
//     what they lost, steeply in the first 12-16 weeks, with the
//     cardiometabolic gains reverting (Wilding et al 2022, STEP 1
//     extension). It is NOT here because the product cannot yet tell
//     "stopped" from "hasn't logged a dose lately", and getting that
//     wrong means telling someone who is still on the drug that she is
//     about to regain everything. Recorded as the first note to write
//     once `RegimenPlanRecord` exposes an ended state.
//
//   sleep · stress
//     Signals exist (HealthKit sleep, no stress). Left out this pass
//     because the honest teaching for both is "this makes the day
//     harder, be gentler", which the day composer already does without
//     a lesson attached.
//
//   goal setting · habit formation · problem solving
//     These are not content. They are what the weekly read and the
//     program facts already DO. Writing lessons about them would be
//     the product explaining its own mechanics to someone using them.
//
// ─── WHAT THE WRITING IS NOT ALLOWED TO DO ──────────────────────────
//
// No food is good or bad. No day damaged anything. No dosing guidance,
// no diagnosis, no medical certainty the evidence does not carry. No
// motivational filler, no therapy cosplay, no wellness prose. Nothing
// is strengthened because stronger copy reads better. Observed, never
// prescribed. And the register is the product's: lowercase, plain
// verbs, no em-dash between words, warmth in the tone rather than in
// the vocabulary.

enum MethodCatalog {

    /// Bumped when any note in this file changes. The ledger stores the
    /// catalog version alongside each shown note, so a later rewrite can
    /// never silently re-date what someone was actually told.
    /// p54 — 2: the evidence spine earned its tiers (four notes whose
    /// mechanism made an external claim on an arithmetic tier), the
    /// plateau note stopped repeating the adaptation myth, the
    /// late-cycle note learned interval rhythms, and three states
    /// became detectable (the cycle bump, the salty pattern, the
    /// deliberate end). `MethodSpineTests` pins a content hash per
    /// note so the NEXT rewrite cannot ship without touching the
    /// version fields deliberately.
    static let version = 2

    static let notes: [MethodNote] = [

        // ───────────────────────────────────────────────────────────
        // 1 · PROTEIN IS A PER-MEAL HABIT, NOT A DAILY TOTAL
        //
        // WHO   anyone whose record shows the floor missed repeatedly.
        // WHEN  ≥3 of her last 5 logged days under the floor.
        // WHY   lean mass is 25-39% of the weight lost on semaglutide
        //       and tirzepatide, and the 2025/26 consensus is not just
        //       a daily number: 1.2-1.6 g/kg spread over 3-4 meals at
        //       25-40 g each. Her record can show a daily total met by
        //       one dinner, which is the same number and not the same
        //       stimulus.
        // AFTER she should understand that WHEN the protein arrives
        //       matters, and that breakfast is where the gap usually is.
        // QUIET one day under the floor is a day, not a pattern. And the
        //       evening close already speaks to today's gap — this note
        //       is about the WEEK, and never fires in the evening.
        MethodNote(
            id: "protein_per_meal_v1",
            trigger: .proteinUnderFloorRepeatedly,
            noticed: "{days} of your last {window} logged days came in under {floor} g.",
            noticedItalic: ["under {floor} g."],
            because: "protein is the part that holds muscle while the weight comes off, and the body can only use so much at once. three meals of 30 g does more than one dinner of 90.",
            evidence: "2025 lean-mass guidance for glp-1 therapy: 1.2 to 1.6 g/kg, spread across 3 to 4 meals",
            action: .init(label: "add something with protein", door: .describePlate),
            followUp: .proteinFloorMetToday,
            cooldownDays: 10,
            suppressedForm: "your protein has been landing light most days lately.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 2 · THE MORNING THE SCALE LIES
        //
        // WHO   anyone who weighs and saw a jump.
        // WHEN  a weigh-in ≥0.8 kg above her own trend, while the trend
        //       itself is flat or falling.
        // WHY   this is the most common reason people stop weighing, and
        //       the thing that changed overnight cannot be fat: a kilo
        //       of fat is roughly 7,700 kcal.
        // AFTER she should read the line, not the dot.
        // QUIET if the trend is genuinely rising, this note would be a
        //       lie. It requires the trend to disagree with the dot.
        MethodNote(
            id: "scale_vs_trend_v1",
            trigger: .weightJumpedAgainstTrend,
            noticed: "the scale is up {jump} since last time. your line is still {direction}.",
            noticedItalic: ["still {direction}."],
            because: "a kilo of fat is about 7,700 calories, so a jump overnight is water, salt and glycogen moving, not tissue. the week decides; the morning never does.",
            // p54 — the 7,700-calorie constant and the water-swing claim
            // are external physiology, and until this pass they rode an
            // arithmetic tier with no attribution — the spine graded the
            // citation line, not the claim.
            evidence: "classic daily-weighing studies: day-to-day water swings reach about one percent of body weight; a kilo of fat holds roughly 7,700 calories",
            action: .init(label: "look at the line", door: .weightTrend),
            followUp: .weighedInWithinThreeDays,
            version: 2,
            cooldownDays: 21,
            suppressedForm: "the scale moved up, and your line has not.",
            evidenceTier: .strong
        ),

        // ───────────────────────────────────────────────────────────
        // 3 · THE FLAT WEEKS
        //
        // WHO   someone still doing the work with nothing to show.
        // WHEN  trend established, |7-day change| under a threshold for
        //       ≥3 weeks, AND she is still logging. The last clause is
        //       load-bearing: a flat trend with an empty record is not a
        //       plateau, it is an unlogged fortnight, and calling it a
        //       plateau would teach her something false.
        // WHY   p54 rewrite on the evidence: the old mechanism said the
        //       body "settles at a new weight before it moves again" —
        //       the adaptation story. Metabolic-ward measurements say
        //       adaptation at a stall is small (~40-90 kcal/day) and
        //       does not predict regain; validated energy models
        //       reproduce the plateau from quiet intake drift alone.
        //       The honest, kind mechanics: nothing is broken, the
        //       corners of the record drifted, and the guideline
        //       response is a tighter week of records — which is also
        //       the one action this product can hand her a door for.
        // AFTER she should know the flat stretch is findable, not a
        //       verdict about her body.
        // QUIET never when the record is thin.
        MethodNote(
            id: "flat_stretch_v1",
            trigger: .trendFlatWhileLogging,
            noticed: "{weeks} weeks of the same number, and you kept filing plates anyway.",
            noticedItalic: ["kept filing plates anyway."],
            because: "a flat stretch is rarely the body breaking: measured metabolic slowdown at a stall is small. the usual cause is quiet drift in the corners the record doesn't see, and a tighter week of records is how you find it.",
            evidence: "metabolic-ward studies: adaptation at a plateau is small and does not predict regain; intake drift explains most stalls",
            action: .init(label: "keep the record tight this week", door: .describePlate),
            followUp: .plateLoggedToday,
            version: 2,
            cooldownDays: 28,
            suppressedForm: "a steady stretch is usually quiet drift, not a stalled body. a tighter week of records finds it.",
            evidenceTier: .strong
        ),

        // ───────────────────────────────────────────────────────────
        // 4 · COMING BACK
        //
        // WHO   the returning user, which on this base is most of them.
        // WHEN  ≥3 days since the last open.
        // WHY   the re-entry cost is the whole retention problem. Any
        //       feedback that points at the person here ("you missed 4
        //       days") is the variety of feedback that measurably makes
        //       performance worse (Kluger & DeNisi 1996). So this one
        //       points only at the next action, and names no number of
        //       days at all.
        // AFTER she should understand nothing is owed.
        // QUIET never fires twice in a week; never counts the gap out
        //       loud.
        MethodNote(
            id: "no_catch_up_v1",
            trigger: .returnedAfterGap,
            noticed: "you're back. nothing is owed for the days in between.",
            noticedItalic: ["nothing is owed"],
            because: "there is no catch-up in this. the record picks up wherever you do, and one plate today is a complete re-entry.",
            evidence: nil,
            action: .init(label: "add your next meal", door: .describePlate),
            followUp: .plateLoggedToday,
            cooldownDays: 7,
            suppressedForm: "you're back. nothing is owed for the days in between."
        ),

        // ───────────────────────────────────────────────────────────
        // 5 · THE END OF THE DOSE RHYTHM
        //
        // WHO   injectable users late in their own cycle — weekly OR
        //       interval (p54: pass 53 gave the record q2d-q90d
        //       rhythms and this note kept assuming a week).
        // WHEN  the schedule engine's own waning band (edge =
        //       ceil(2·length/7): days 6-7 of a week, 8-10 of a
        //       ten-day rhythm), event-anchored to her last injection.
        // WHY   appetite returning before the next dose does is
        //       pharmacology, not a lapse, and people read it as the
        //       drug failing or themselves failing. p54: "usually"
        //       became "often" — the within-cycle appetite pattern is
        //       PK-derivable, not a documented population study, and
        //       the hedge is the honest register (no published diary
        //       study quantifies a day-6 pattern; the trough itself is
        //       label pharmacokinetics).
        // AFTER she should recognise the pattern as a shape of the
        //       rhythm.
        // QUIET never for daily, as-needed or split regimens — no
        //       single arc exists, so `cyclePosition` hands this note
        //       nothing; never as dosing advice.
        MethodNote(
            id: "late_dose_week_v1",
            trigger: .lateInDoseWeek,
            noticed: "day {cycle_day} of {cycle_word}. often the hungry end of it.",
            noticedItalic: ["the hungry end of it."],
            because: "the medicine runs lowest just before the next dose, so appetite often comes back for a day or two. it is the shape of the rhythm, not the plan slipping.",
            evidence: "the labels' own pharmacokinetics: weekly and interval injectables run lowest just before the next dose",
            action: .init(label: "put protein first today", door: .describePlate),
            followUp: .proteinFloorMetToday,
            version: 2,
            cooldownDays: 21,
            suppressedForm: "you're near the end of your dose rhythm. appetite often returns here.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 6 · THE WEEKEND HOLE
        //
        // WHO   the weekday logger.
        // WHEN  logged on ≥3 of the last 5 weekdays and 0 of the last 2
        //       weekend days.
        // WHY   self-monitoring frequency is one of the most consistent
        //       predictors of maintenance, and dietary self-monitoring
        //       has a documented within-week shape: it falls at the
        //       weekend. The fix is not discipline, it is a cheaper
        //       door — which this product already built (E7's words,
        //       E4's again).
        // AFTER she should know the weekend record does not have to be
        //       accurate to be useful.
        // QUIET never on a weekday; never if she has never logged.
        MethodNote(
            id: "weekend_record_v1",
            trigger: .weekendRecordDisappears,
            noticed: "your record keeps stopping on saturday.",
            noticedItalic: ["stopping on saturday."],
            because: "the weekend is where almost everyone's logging goes quiet, and a rough note beats a blank day by a long way. a sentence is enough. it does not have to be careful.",
            evidence: "in weight-maintenance studies, self-monitoring frequency is one of the steadier predictors of keeping weight off",
            action: .init(label: "say what you ate", door: .describePlate),
            followUp: .plateLoggedToday,
            cooldownDays: 21,
            suppressedForm: "your record tends to go quiet at the weekend.",
            evidenceTier: .strong
        ),

        // ───────────────────────────────────────────────────────────
        // 7 · WHEN THE WALKING STOPS
        //
        // WHO   anyone whose own movement has dropped.
        // WHEN  7-day step mean ≤60% of her own 28-day baseline, with
        //       enough days to have a baseline at all.
        // WHY   movement here is not repayment for food. On a large,
        //       fast weight loss the reason to keep moving is what it
        //       protects: muscle, function, and the floor of energy the
        //       day runs on.
        // AFTER she should understand movement as protection, not
        //       arithmetic against a plate.
        // QUIET never against a population average, only against HER
        //       baseline; never with a calorie figure attached.
        MethodNote(
            id: "movement_dropped_v1",
            trigger: .movementBelowOwnBaseline,
            noticed: "your walking is about {pct}% of your own usual this week.",
            noticedItalic: ["your own usual"],
            because: "movement here is not paying anything back. it is what keeps the muscle and the energy while the weight comes down, and the days it matters most are the ones it feels least available.",
            evidence: nil,
            action: .init(label: "see the week", door: .move),
            followUp: .movementRecordedWithinTwoDays,
            cooldownDays: 21,
            suppressedForm: "your walking is quieter than your own usual this week."
        ),

        // ───────────────────────────────────────────────────────────
        // 8 · THE FIRST PLATE
        //
        // WHO   a brand-new payer, at the only moment the record can
        //       explain itself with something she just did.
        // WHEN  exactly one plate on file, ever.
        // WHY   day-0 food loggers return at 76% versus 17% (E4). This
        //       is the highest-leverage sentence in the product.
        // AFTER she should know what the record is FOR: not calories
        //       counted, a line that becomes readable.
        // QUIET never again after the first.
        MethodNote(
            id: "first_plate_v1",
            trigger: .firstPlateOnFile,
            noticed: "that's one plate on file. it is already doing something.",
            noticedItalic: ["already doing something."],
            because: "a record is not a report card. it is the only way anything here can tell you something true later, and it starts working from the first entry.",
            evidence: nil,
            action: .init(label: "add the next one when it happens", door: .none),
            followUp: .plateLoggedToday,
            cooldownDays: 3650,
            suppressedForm: "that's one plate on file. it is already doing something."
        ),

        // ───────────────────────────────────────────────────────────
        // 9 · THE LINE BECOMES READABLE
        //
        // WHO   anyone who has weighed enough for a trend to exist.
        // WHEN  the trend crosses into established.
        // WHY   the product spends its whole life saying "not enough
        //       weigh-ins to call a direction yet". The moment that
        //       stops being true is worth one sentence.
        // AFTER she should know which number to trust from now on.
        // QUIET fires once.
        MethodNote(
            id: "trend_readable_v1",
            trigger: .trendJustReadable,
            noticed: "you have weighed in enough times that the line can be read now.",
            noticedItalic: ["can be read now."],
            because: "single mornings bounce by a kilo on water alone. the smoothed line ignores that, which is why from here on it is the number worth looking at.",
            evidence: nil,
            action: .init(label: "see your line", door: .weightTrend),
            followUp: .weighedInWithinThreeDays,
            cooldownDays: 3650,
            suppressedForm: "you have weighed in enough times for the line to be readable."
        ),

        // ───────────────────────────────────────────────────────────
        // 10 · THE FLOOR, MET
        //
        // WHO   anyone who reached her protein floor for the first time.
        // WHEN  once, the first day it happens.
        // WHY   the product asks for protein constantly and has never
        //       once explained the payoff at the moment it landed.
        // AFTER she should know what that number was protecting.
        // QUIET once, ever. No praise: a mechanism, not a good girl.
        MethodNote(
            id: "floor_met_v1",
            trigger: .proteinFloorMetFirstTime,
            noticed: "{protein} g today. that is the floor, met.",
            noticedItalic: ["the floor, met."],
            because: "a quarter to nearly two fifths of what comes off on these medicines is lean tissue if nothing protects it. that number is the protection, and it is most of the job.",
            evidence: "lean mass accounted for roughly 25% to 39% of total loss in the semaglutide and tirzepatide trials",
            action: nil,
            followUp: .proteinFloorMetToday,
            cooldownDays: 3650,
            suppressedForm: "you reached your protein floor today. that is the part that protects muscle.",
            evidenceTier: .strong
        ),

        // ───────────────────────────────────────────────────────────
        // 11 · THE OTHER HALF OF THE PROTEIN STORY
        //
        // WHO   someone losing steadily with no strength work recorded.
        // WHEN  trend falling at a real rate, ≥14 days on file, and
        //       nothing resistance-shaped in the record.
        // WHY   protein alone is one of two levers. The 2025/26 guidance
        //       pairs it with resistance work twice a week, and the
        //       reason is mechanical: protein supplies the material,
        //       loading is the signal to keep it.
        // AFTER she should know two sessions a week is the whole ask.
        // QUIET never framed as a workout plan, never with a calorie
        //       number, never while she is not actually losing.
        MethodNote(
            id: "resistance_pairing_v1",
            trigger: .losingWithoutResistanceWork,
            noticed: "the weight is moving. nothing in your record is asking your muscles to stay.",
            noticedItalic: ["asking your muscles to stay."],
            because: "protein is the material and loading is the signal. twice a week of something heavy for you is the whole ask, and it is the difference between losing weight and losing what holds you up.",
            evidence: "2025 lean-mass guidance: resistance work at least twice weekly alongside protein",
            action: .init(label: "record something you did", door: .move),
            followUp: .movementRecordedWithinTwoDays,
            cooldownDays: 21,
            suppressedForm: "the weight is moving, and nothing here is asking your muscles to stay.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 12 · THE END OF WEEK ONE
        //
        // WHO   everyone who reaches it, which is a minority worth
        //       speaking to precisely.
        // WHEN  program day 6-8.
        // WHY   week one is where a diet and a method feel identical and
        //       diverge. Expectation-setting at exactly this point is
        //       the cheapest thing that changes month three.
        // AFTER she should expect the loss to be uneven and know what
        //       the second week is actually for.
        // QUIET once.
        MethodNote(
            id: "first_week_v1",
            trigger: .firstWeekClosing,
            noticed: "that is a week. {plates} plates, and the line has started.",
            noticedItalic: ["a week."],
            because: "week one is the one that flatters you and the one that means least. what the second week is for is finding out which of these you would still do on a bad day.",
            evidence: nil,
            action: nil,
            followUp: .plateLoggedToday,
            cooldownDays: 3650,
            suppressedForm: "that is a week on file, and the line has started."
        ),

        // ───────────────────────────────────────────────────────────
        // 13 · MAINTENANCE
        //
        // WHO   anyone whose loss phase is ending.
        // WHEN  the program arc enters its maintenance phase.
        // WHY   this is where the product's whole logic changes and
        //       nothing tells her. Keeping weight off runs on the same
        //       behaviours, measured differently: a band, not a target.
        // AFTER she should know what "working" looks like when the
        //       number stops going down.
        // QUIET once.
        MethodNote(
            id: "maintenance_band_v1",
            trigger: .enteringMaintenance,
            noticed: "the losing part is finishing. the number stops being the score now.",
            noticedItalic: ["stops being the score"],
            because: "keeping runs on a band rather than a target: a range you move inside without reacting. the behaviours do not change, only what counts as it working.",
            evidence: nil,
            action: .init(
                label: "set your band with jeni",
                door: .askJeni,
                chatSeed: "they are entering maintenance. help them name a band, the range they will not react inside, from their own trend."
            ),
            followUp: .none,
            cooldownDays: 3650,
            suppressedForm: "the losing part is finishing. what counts as working changes now."
        ),

        // ───────────────────────────────────────────────────────────
        // 14 · FLUIDS ON A QUEASY DAY  (v25 E9)
        //
        // WHO   anyone on a GLP-1 who has just logged nausea or a loose
        //       stomach — the two symptoms whose consequence the drug
        //       labels themselves single out.
        // WHEN  within two days of logging either one.
        // WHY   this is the highest-authority thing Jeni can say about
        //       fluids, and the only version of it that is honest. Every
        //       label in this class carries the same warning: acute
        //       kidney injury has been reported post-marketing, "the
        //       majority of the reported events occurred in patients who
        //       had experienced nausea, vomiting, or diarrhea, leading to
        //       volume depletion" (Wegovy PI; Zepbound, Ozempic and
        //       Mounjaro carry parallel language), and the patient-facing
        //       Medication Guides say plainly that it is important to
        //       drink fluids to reduce the chance of dehydration. On top
        //       of that, these drugs blunt thirst itself (dulaglutide
        //       cut fluid intake ~490 ml/day vs placebo, Winzeler 2021)
        //       and shrink the meals fluid usually arrives with — so the
        //       one signal a person would normally rely on is the signal
        //       the drug is quieting.
        // AFTER she should treat sips on a bad day as part of the
        //       treatment rather than as optional self-care.
        // QUIET NO NUMBER, EVER — not 1,800 ml, not eight glasses, not
        //       the IOM adequate intake. No credible body prescribes a
        //       personal fluid volume, and fluid RESTRICTION is standard
        //       care in heart failure, advanced CKD and hyponatremia,
        //       which are not rare in this population. Jeni cannot know
        //       which reader is which, so she gives the instruction the
        //       label gives and stops. A care team's number outranks
        //       this and renders attributed on the day row instead.
        //       Never fires on a day the adequacy net is already
        //       speaking; never twice in a fortnight.
        // ───────────────────────────────────────────────────────────
        // 14a · LIGHTHEADED IN A ROUGH-STOMACH STRETCH  (p55)
        //
        // WHO   anyone who logged lightheadedness inside the same
        //       window as a GI-loss symptom (queasy / loose stomach).
        // WHEN  within two days of either.
        // WHY   the highest-authority hydration fact this class of
        //       medication carries: the labels report acute kidney
        //       injury post-marketing, "the majority… in patients who
        //       had experienced nausea, vomiting, or diarrhea, leading
        //       to volume depletion" (Wegovy PI; Zepbound and the
        //       others carry parallel language) — and the drugs blunt
        //       thirst itself (Winzeler 2021, −490 ml/day), so the
        //       signal she would normally rely on is being quieted.
        //       Lightheadedness is how low volume commonly announces
        //       itself. This note ROUTES; it never diagnoses.
        // AFTER she should mention the pairing to her prescriber and
        //       treat sips as part of the day.
        // QUIET no volume, ever (note 14's law). It does NOT stand
        //       down for the adequacy net: a routing note is not a
        //       teaching, and the label's warning outranks the
        //       one-voice law. Once a fortnight at most.
        MethodNote(
            id: "dizzy_fluid_loss_v1",
            trigger: .dizzyOnAFluidLossDay,
            noticed: "lightheaded, in the same stretch as {gi_symptom}. that pairing is worth telling your prescriber about.",
            noticedItalic: ["worth telling your prescriber"],
            because: "a rough stomach loses fluid, and these medications quiet thirst as well as appetite, so low fluid can sneak up. lightheaded is often how it first shows. sips through the day help; the pairing itself is your prescriber's to hear.",
            evidence: "the labels for this class ask patients to keep taking fluids during stomach trouble and to involve their care team when it persists",
            action: .init(
                label: "ask jeni what helps today",
                door: .askJeni,
                chatSeed: "they logged lightheadedness within two days of a GI symptom (nausea or loose stomach). encourage fluids in sips, gentle salty-adjacent foods if tolerated, and SAY PLAINLY that this pairing is worth a message to their prescriber, especially if it has not settled. never give a fluid volume, never assess severity, never speculate about kidneys or diagnoses, and never suggest changing or skipping doses."
            ),
            followUp: .none,
            cooldownDays: 14,
            suppressedForm: "lightheaded on a rough-stomach day is worth telling your prescriber about. sips through the day, rather than a lot at once.",
            evidenceTier: .strong
        ),

        MethodNote(
            id: "fluids_queasy_day_v1",
            trigger: .fluidsOnAQueasyDay,
            noticed: "you logged {symptom}. that is the kind of day fluids slip without noticing.",
            noticedItalic: ["fluids slip"],
            because: "eating and drinking usually happen together, so a day you eat less is a day you drink less, and these medications quiet thirst as well as appetite. sips through the day, rather than a lot at once, is what the medication guides ask for.",
            evidence: "glp-1 medication guides: keep taking fluids when nausea, vomiting or diarrhea show up",
            action: .init(
                label: "ask jeni what to eat today",
                door: .askJeni,
                chatSeed: "they logged nausea or a loose stomach in the last two days. suggest gentle, protein-forward things that sit easily, and fluids in sips. do not give a fluid volume. if vomiting or diarrhea has not settled, tell them to contact their care team."
            ),
            followUp: .none,
            cooldownDays: 14,
            suppressedForm: "a queasy day is a day fluids slip. sips through the day, rather than a lot at once.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 15 · BACKED UP, AND FIBER IS LOW  (v25 E9)
        //
        // WHO   anyone who logged constipation while her own recent
        //       fiber sits low.
        // WHEN  within three days of the symptom.
        // WHY   constipation runs ~24% on semaglutide against ~11% on
        //       placebo (pooled STEP 1-3) and is the GI complaint people
        //       are least likely to raise. First-line management is
        //       behavioural — fluid AND fiber together, plus movement —
        //       and fiber is the half of it that is a thing she can put
        //       on a plate, which makes it the half this product can
        //       actually help with.
        // AFTER she should know the two levers, and that this usually
        //       settles.
        // QUIET only when her OWN fiber is low. Telling someone already
        //       eating 35 g of fiber to eat more fiber is how a note
        //       loses its authority for good. And no volume here either,
        //       for the same reason as note 14.
        MethodNote(
            id: "constipation_fiber_v1",
            trigger: .constipationWithLowFiber,
            noticed: "backed up, and fiber has been running near {fiber} g a day.",
            noticedItalic: ["near {fiber} g"],
            because: "fluid and fiber work together on this; either one on its own does much less. it is the second most common side effect of these medications and it usually settles.",
            // p54 — "second most common" and "usually settles" are trial
            // epidemiology (pooled STEP 1-3: constipation ~24% vs ~11%
            // without, mostly mild and clustered in escalation), and
            // they rode an arithmetic tier with the source living only
            // in this comment.
            evidence: "pooled semaglutide trials: constipation ran about 24 percent, against 11 without, mostly settling after the early weeks",
            action: .init(label: "add something with fiber", door: .describePlate),
            followUp: .plateLoggedToday,
            version: 2,
            cooldownDays: 10,
            suppressedForm: "backed up is common on these medications. fluid and fiber together are the first thing to try.",
            evidenceTier: .strong
        ),
        // ───────────────────────────────────────────────────────────
        // 16 · THE BREAKFAST GAP (p53)
        //
        // WHO   someone whose floor keeps slipping for a locatable
        //       reason: the mornings are nearly empty.
        // WHEN  ≥3 of her recent logged days missed the floor with
        //       near-zero before-noon protein; never in the evening
        //       (nothing actionable about breakfast at 9pm), never
        //       over the adequacy net, never without a floor.
        // WHY   the floor is reachable by evening only if the day
        //       starts; the gap number is the mean shortfall of HER
        //       OWN missed days, not a generic target.
        // AFTER breakfast becomes the one lever, sized in her grams.
        // QUIET under the net; under 3 pattern days; evenings.
        MethodNote(
            id: "morning_protein_gap_v1",
            trigger: .morningProteinGap,
            noticed: "your last few logged days missed the floor, and the mornings were nearly empty. about {gap} g at breakfast closes most of it.",
            noticedItalic: ["at breakfast"],
            because: "protein spread across the day holds muscle better than one late catch-up, and a morning start makes the floor reachable by evening.",
            evidence: "2025 lean-mass guidance for glp-1 therapy: 1.2 to 1.6 g/kg, spread across 3 to 4 meals",
            action: .init(label: "say what breakfast was", door: .describePlate),
            followUp: .proteinFloorMetToday,
            cooldownDays: 10,
            suppressedForm: "the mornings are where your floor slips. breakfast first.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 17a · THE SALTY PATTERN, HERS (p54)
        //
        // WHO   someone whose OWN record has already paired salty days
        //       with next-morning bumps at least twice before.
        // WHEN  the same facts as the base note below, PLUS ≥2 prior
        //       completed pairings in her 60-day record — supplied as
        //       the {nth} token, which is absent below the floor, so
        //       this note DROPS and the base note speaks instead. The
        //       token machinery is the whole variant mechanism: no
        //       cohort flag, no second trigger.
        // WHY   §5 of the brief, verbatim: population evidence says
        //       "often"; after enough repeats of her own, jeni may say
        //       "this has happened after three of your saltier dinners
        //       now" — and only when the record actually supports it.
        // AFTER the pattern is HERS, which is worth more than a
        //       mechanism: next salty morning she already knows.
        // QUIET below two prior pairings; everywhere the base note is
        //       quiet; the ordinal caps at "sixth" (a wrong ordinal
        //       would be a small lie) and the base note takes over.
        MethodNote(
            id: "salty_dinner_pattern_v1",
            trigger: .saltyDinnerScaleBump,
            noticed: "up {bump} after a salty day. that's the {nth} time your record has paired salt with a next-morning bump.",
            noticedItalic: ["{nth} time"],
            because: "your own record keeps showing the pair: salt holds water for a day or two, then lets it go. a real kilo of tissue is about 7,700 calories.",
            evidence: "salt-loading studies: a high-sodium stretch can hold a kilo or two of water; a kilo of fat is about 7,700 calories",
            action: .init(label: "look at the line", door: .weightTrend),
            followUp: .weighedInWithinThreeDays,
            cooldownDays: 10,
            suppressedForm: "the scale is reading salt again, the way your record has shown before.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 17 · THE SALTY-DAY BUMP (p53; hedged p54)
        //
        // WHO   someone whose scale is up this morning after a day her
        //       own record shows was heavy on sodium.
        // WHEN  yesterday's plates carried ≥2,800 mg sodium AND this
        //       morning's weigh-in is up ≥0.4 kg AND the trend is not
        //       clearly rising (else the reassurance could hide a real
        //       change). Facts only — no sodium on file, no note.
        // WHY   the salt→water mechanism is strong; attributing ONE
        //       morning to ONE dinner is not (no controlled trial
        //       quantifies a single salty dinner's next-morning scale
        //       effect) — so p54 added "often" and "usually", and the
        //       tier is reasonable practice, not strong. The trend
        //       guard is what keeps the reassurance honest.
        // AFTER the morning stops being a verdict; the line decides.
        // QUIET without its facts; under the net; against a rising
        //       trend.
        MethodNote(
            id: "salty_dinner_scale_v1",
            trigger: .saltyDinnerScaleBump,
            noticed: "up {bump} on the scale after a salty day. salt often holds water for a day or two, then lets it go.",
            noticedItalic: ["water"],
            because: "a real kilo of tissue is about 7,700 calories. an overnight bump after a salty day is usually water arithmetic, not fat.",
            evidence: "salt-loading studies: a high-sodium stretch can hold a kilo or two of water; a kilo of fat is about 7,700 calories",
            action: .init(label: "look at the line", door: .weightTrend),
            followUp: .weighedInWithinThreeDays,
            version: 2,
            cooldownDays: 10,
            suppressedForm: "the scale is reading yesterday's salt, not a change in you.",
            evidenceTier: .reasonablePractice
        ),

        // ───────────────────────────────────────────────────────────
        // 18 · THE FIRST DAYS OF FLOW (p54)
        //
        // WHO   someone whose scale is up while her own recorded
        //       period starts say she is in the first days of flow.
        // WHEN  `CycleSignal.read` is `.menstrual` (her own starts,
        //       the irregularity stand-downs applied — a spread over
        //       ten days, implausible gaps, or a perimenopausal
        //       profile all arrive here as FALSE) AND this morning's
        //       weigh-in is up ≥0.4 kg AND the trend is not clearly
        //       rising. Salt outranks it by priority: yesterday's
        //       dinner is the more specific fact when both are true.
        // WHY   the one cycle claim strong enough to ship (p53 §9),
        //       now with actual-weight backing: daily-weighing and
        //       body-water studies put the peak in the first day or
        //       two of flow, roughly half a kilo on average,
        //       resolving within the week. Every mainstream tracker
        //       reads this water as fat — the market's clearest
        //       unclaimed women-specific gap.
        // AFTER the morning stops being a verdict here too.
        // QUIET whenever the signal is unreliable; under the net;
        //       against a rising trend; never a prediction, never a
        //       fertility word — the standing cycle law.
        MethodNote(
            id: "menses_scale_bump_v1",
            trigger: .mensesOnsetScaleBump,
            noticed: "up {bump} with your period starting. the first days of flow usually run heavy on water, then let it go.",
            noticedItalic: ["water"],
            because: "in daily-weighing studies the scale peaks in the first day or two of flow, about half a kilo on average, and settles inside the week. water moving, not a change in you.",
            evidence: "daily-weighing studies across hundreds of cycles: roughly half a kilo of water around the first days of flow",
            action: .init(label: "look at the line", door: .weightTrend),
            followUp: .weighedInWithinThreeDays,
            cooldownDays: 21,
            suppressedForm: "the scale often runs high in the first days of a period, and it's water.",
            evidenceTier: .strong
        ),

        // ───────────────────────────────────────────────────────────
        // 19 · THE PLAN SHE ENDED (p54)
        //
        // WHO   someone who deliberately marked her self-managed
        //       medication plan ENDED — not paused, not a dose change,
        //       not a care-team decision — with no successor plan.
        // WHEN  within 28 days of the end. The builder supplies nil
        //       for every other shape of ending, so the engine cannot
        //       confuse "stopped" with "hasn't logged lately" — the
        //       exact confusion that kept this note unwritable since
        //       E8.1 named it the highest-value teaching in the
        //       domain.
        // WHY   the trial extensions are unambiguous: much of the
        //       lost weight returned within a year of stopping,
        //       steepest in the first months — and the same floors
        //       (protein, strength, the record) are what she keeps.
        //       Real-world cohorts run softer than the trials, so the
        //       note states the shape, never a prediction about her.
        // AFTER she should know the record did not end with the plan,
        //       and that the what-next belongs to her prescriber.
        // QUIET for pauses (a break is a break); for era changes; for
        //       care-team endings (that transition is the clinic's
        //       conversation); past the window; never a restart
        //       suggestion, never a medication decision.
        MethodNote(
            id: "medication_ended_v1",
            trigger: .medicationRecentlyEnded,
            noticed: "your medication plan is marked ended. the record stays yours, and it keeps working.",
            noticedItalic: ["stays yours"],
            because: "the first months after stopping are when appetite returns, and the trial extensions saw weight begin to come back. the floors, the movement and the record are the part people keep. your prescriber is the right person for the what-next.",
            evidence: "in the trial extensions, much of the lost weight returned within the year after stopping",
            action: .init(
                label: "keep the floors with jeni",
                door: .askJeni,
                chatSeed: "their self-managed glp-1 medication plan was recently marked ended, by their own record. support the transition: the protein floor, strength work and keeping the record all still stand. no alarm, no predictions about their body, never suggest restarting or any medication decision. if symptoms drove the stop or it wasn't planned, suggest talking with their prescriber."
            ),
            followUp: .plateLoggedToday,
            cooldownDays: 45,
            suppressedForm: "your medication plan is marked ended. the record stays yours, and the floors still stand.",
            evidenceTier: .strong
        ),
    ]

    /// Notes for a trigger, most authoritative first. Care-team content
    /// outranks Jeni's for the same trigger; Jeni's default is what
    /// remains when a clinic has supplied nothing, which is why a clinic
    /// connection can never produce an empty Method.
    static func candidates(
        for trigger: MethodTrigger,
        clinicNotes: [MethodNote],
        now: Date
    ) -> [MethodNote] {
        let clinic = clinicNotes.filter {
            $0.trigger == trigger && ($0.expiresAt.map { $0 > now } ?? true)
        }
        let defaults = notes.filter { $0.trigger == trigger }
        return clinic + defaults
    }
}
