# ONBOARDING BEAT INVENTORY — current state (feat/app-v2, 2026-08-02)

Scope: the live v5 flow (`OV5Step` enum, 55 cases) + the reveal sequence
(v5 enters at `.building`; disclaimer/safety preamble steps in the
reveal are **legacy-v4.5-only** — v5 runs the safety gate mid-Act-III
and folds the disclaimer into the signature beat) + the keep wall.
Persistent chrome: `OV5TopBar` renders lowercase act eyebrows
`"her arrival" / "her food story" / "the numbers, gently" / "the part
nobody asks" / "almost hers"` (OV5Flow.swift:100-103) — three of five
eyebrows are "her/hers" grammar. Every receipt-type screen also renders
the hint `"tap to continue"` (OV5Components.swift:809).
(Agent-produced 2026-08-02; every line verified against source.)

---

## ACT I — "her arrival"

### 1. welcome — collage (device-demo hero)
- file: OV5Collage.swift:13 (demo frame: OV5DeviceDemo.swift:13)
- headline: "your care plan," / "made around real days." (italic: "real") (OV5Collage.swift:74-88)
- sub/support: "free to start." (:117) · "already have an account? sign in" (:126-127). Device-demo internal copy (cycling 3 scenes): "day 1", rows "move"/"10 min", "add a meal"/"before you eat", "7,500 steps"/"counted for you", "the method"/"2-min read" (OV5DeviceDemo.swift:104-135); camera scene "fits today", "· 500 cal", "add it before you eat" (:239-253); steps scene "4,680", "of 7,500 steps", "the everyday anchor" (:288-321). A11y label "a preview of jeni: your daily plan, the food camera, and steps" (:87).
- options: CTA "continue" (:105)
- writes: none (advance only; sign-in path sets hasCompletedOnboarding for recovered accounts)
- conditional: none
- register-flags: sticker scatter (starLineart, sparkleGlossy, flower3D, strawberry, cherries — OV5Collage.swift:29-46) decorative it-girl vocabulary; "the everyday anchor" italic poetic; profile avatar asset "onb-profile-latte" (OV5DeviceDemo.swift:112) female-coded it-girl art.

### 2. antiShame — teach
- file: OV5ScreensArrival.swift:7
- headline: "the last plan failed you. not the other way around." (italic: "you")
- sub: "no clean slates needed. no earning your way in. jeni builds your care plan around your real days, starting with how you actually eat." (:13)
- options: CTA "okay" · writes: none · conditional: none
- register-flags: emotional-reassurance therapy register; claim without mechanism/source; CTA "okay" chatty.

### 3. outcome — select (cross-off, auto-advance)
- file: OV5ScreensArrival.swift:20
- headline: "what are you here for, mostly?" (italic: "here")
- options: "feel like myself again" (myself) · "quiet the food noise" (noise) · "steady energy" (energy) · "clothes that fit right" (clothes) · "keep off what i lost" (keep)
- writes: onb_v5_outcome (+ legacy mirror)
- register-flags: "feel like myself again" / "clothes that fit right" emotional/appearance-led.

### 4. attribution — select
- file: OV5ScreensArrival.swift:41
- headline: "where'd you find us?" (italic: "find")
- options: tiktok / instagram / "a friend told me" / app store / google / "somewhere else"
- writes: onb_v5_attribution · register-flags: none material.

### 5. credibility — bridge (receipt-style rows)
- file: OV5ScreensArrival.swift:63
- headline: "you're in the right place." (italic: "right")
- sub: "women who've tried everything. women alongside the shot, or after it. women done with all-or-nothing." (:74) · rows: "the pace" → "0.5-1% a week, the clinical band" · "the floor" → "protein set by your body weight" · "the screen" → "safety questions before you pay" (:76-78) · footnote "your care plan listens either way." (:80)
- register-flags: **three "women" repetitions — hardest female-assumption in Act I**; "you're in the right place" affirmation filler; "the clinical band" cites NO named source; "your care plan listens" anthropomorphizing.

### 6. name — bespoke (text field)
- file: OV5ScreensArrival.swift:86
- headline: "what do we call you?" (italic: "call") · placeholder "your name"
- options: CTA "continue" · secondary "later" (skippable)
- writes: onb_v5_name · register-flags: none.

---

## ACT II — "her food story"

### 7. glp1Status — select (explicit continue; sensitive)
- file: OV5ScreensFood.swift:9
- headline: "any weight meds right now?" (italic: "now")
- sub: trust line (lock glyph) "the plan reads differently on, after, or without them. private, always." (:17) · inline ack after pick: current → "we pace for the shot." · past → "the first goal is keeping what you built." · considering → "med or no med, the daily piece is the same." · none/prefer_not_say → "noted. your plan, your way." (:58-61)
- options: "no" (none) · "yes, i'm on one" (current) · "i was. not anymore" (past) · "thinking about it" (considering) · "prefer not to say" (prefer_not_say, lock icon)
- writes: onboarding_glp1_status · conditional: routes the whole act; ack varies
- register-flags: "noted. your plan, your way." chatty filler; "the shot" colloquialism.

### 8. glp1Phase — select (current branch)
- file: OV5ScreensFood.swift:67
- headline: "how long on it?" (italic: "it")
- options: "just started" / "a few months in" / "6+ months, steady" / "prefer not to say"
- writes: onboarding_glp1_phase · **Silent answer** (feeds pace engine invisibly).

### 9. appetiteRhythm — select (current branch)
- file: OV5ScreensFood.swift:91
- headline: "when is eating hardest right now?" (italic: "hardest") · sub "your lived rhythm. we pace week one around it."
- options: "the day or two after my shot" (after_shot) · "late week, appetite creeps back" (late_week) · "most days right now" (most_days) · "it varies" (varies)
- writes: onb_v5_appetite_rhythm · conditional: only after_shot echoes (loader)
- register-flags: "your lived rhythm" soft-academic.

### 10. shotDay — bespoke weekday list (current branch; the one "clinical register" beat)
- file: OV5ScreensStageA.swift:46
- headline: "your shot day" · sub "if you'd like jeni to hold the rhythm, dose days shape themselves around it. optional, change anytime." (:60) · "only you see this. never named in notifications." (:73)
- options: monday…sunday; "skip for now" (:84); CTA "continue"
- writes: onb_v5_shot_day
- register-flags: "if you'd like jeni to hold the rhythm" soft/pastoral inside the clinical beat; "dose days shape themselves" anthropomorphizing.

### 11. muscleMath — teach (current branch)
- file: OV5ScreensFood.swift:115
- headline: "a share of what's lost on the shot is muscle." (italic: "muscle.")
- figure muscleComposition ("what the scale loses" / "fat" / "muscle · the share we protect", OV5Components.swift:543-593) · points: i "appetite down means protein down, quietly." gloss "smaller meals crowd protein out first, without you choosing it." · ii "protein + movement decide what you keep." gloss "the two levers that protect lean mass while the scale moves." · closing "that's the work we do beside it." · **citation chip "lean-mass findings · nejm step 1"**
- register-flags: sourced (named); "quietly"/"beside it" poetic modifiers.

### 12. stopWindow — select (past branch)
- file: OV5ScreensFood.swift:136
- headline: "how long since you stopped?" (italic: "stopped")
- options: "under 3 months" / "3 to 6 months" / "6 to 12 months" / "over a year" / "prefer not to say"
- writes: onboarding_glp1_stop_window · echoes in loader tape variants.

### 13. appetiteReturn — select (past branch)
- file: OV5ScreensFood.swift:161
- headline: "is your appetite finding its way back?" (italic: "back")
- options: "fully back" / "creeping back" / "not yet" / "it comes in waves"
- writes: onboarding_appetite_return
- register-flags: "finding its way back"/"comes in waves" poetic. **Fully silent answer — no reader anywhere.**

### 14. regainTruth — teach (past branch)
- file: OV5ScreensFood.swift:181
- headline: "and then the volume came back." (italic: "back.")
- lead "appetite returning is physiology, not failure." · points: i "about half stop within the first year." gloss "coverage, cost, side effects, life. stopping is the norm, not the exception." · ii "the rhythm is the part nobody prescribed." gloss "protein, steps, the daily pattern. the medication never built those for you." · closing "that's the part we're built for." · **citation chip "discontinuation data · jama 2025"**
- register-flags: sourced; "the volume came back" metaphor.

### 15. consideringAgency — teach (considering branch)
- file: OV5ScreensFood.swift:202
- headline: "med or no med, the daily piece is the same." · lead "if you ever start one, this still fits. if you never do, this is the whole plan."

### 16. foodRelationship — select
- file: OV5ScreensFood.swift:217
- headline: "what is food, mostly?" (italic: "food")
- options (label · sub): "fuel" · "i eat to function" / "comfort" · "food is how i decompress" / "love" · "cooking + sharing is joy" / "control" · "i track it closely" / "complicated" · "not a clean answer"
- writes: onboardingFoodRelationship.

### 17. foodNoise — teach, 3 cohort variants
- file: OV5ScreensFood.swift:238
- current: "you know food noise because it went quiet." · i "the shot turns the volume down." gloss "that hush you noticed in week one? that was the noise, leaving." · ii "the habits decide what stays." gloss "protein, rhythm, movement. the quiet is the window to build them." · closing "we're the part that stays."
- past: "quieter hunger still deserves a plan." · lead "you've heard the noise loud and heard it quiet. the plan works either way." · i "it's biology, not willpower." gloss "hunger hormones and habit loops keep the thought running in the background." · closing "we build the rhythm that holds."
- general: "that's called food noise." · lead "the chatter that never quite quiets. what to eat, when, how much. the bargaining at 9pm." · i "it's not willpower." gloss "you're not failing at discipline. for some bodies the signal is simply louder." · ii "it's biology." gloss (same hormones line) · closing "your plan is built to turn the volume down."
- figure foodNoiseWave ("the noise" / "quieter", OV5Components.swift:494-503)
- register-flags: **"it's biology"/"hunger hormones" claims carry NO source on any variant**; "that hush… the noise, leaving." poetic; "we're the part that stays." emotional.

### 18. preEat — teach
- file: OV5ScreensFood.swift:291
- headline: "you can decide before you eat." (italic: "before") · lead "add it first. see if it fits. no shame either way." · CTA "show me"
- register-flags: "no shame either way" filler clause.

### 19. snapDemo — demo (full-bleed interactive)
- file: OV5SnapDemo.swift:36
- headline: "watch what one photo can tell us." · sub "pick one. they're ours, from real days." (:93-96)
- support: skip "skip the practice run" (:122) · scanning "reading the plate…" + "calm, not judging" (:201-206) · result: meal title, "calories" + "± {range}", "{n}g" "protein", GLP-1 chip "your number now" (:272) · jeni line: GLP-1 "see the protein line? that's the one we watch together." / else "it fits. no drama either way." (:335-343)
- options: 3 plate cards; CTA "day one, you do this for real" (:308)
- writes: onb_v5_snap_demo_meal · conditional: protein chip + jeni line by GLP-1 (current OR past)
- register-flags: "calm, not judging" / "no drama either way" filler; "we watch together" companionate; CTA casual.

### 20. eatingCadence — select
- file: OV5ScreensFood.swift:304
- headline: "how do you usually eat?" (italic: "usually")
- options: "one meal" / "2 + snacks" / "3 steady meals" / "grazing all day" / "no real pattern"
- writes: onboardingEatingCadence.

### 21. priorWin — select
- file: OV5ScreensFood.swift:325
- headline: "what worked, even briefly?" (italic: "worked")
- options: "daily movement" / "an eating window" / "less sugar" / "tracking food" / "still figuring it out"
- writes: onboardingPriorWin · **Silent/dead in v5** (no reader).

### 22. cuisine — chip cloud (multi)
- file: OV5ScreensFood.swift:346
- headline: "what's on your table?" (italic: "your") · sub "pick what you actually eat. the plate reader learns it."
- options: 11 cuisines + "a bit of everything" · writes: onboardingCuisinePreference.

### 23. dietary — multi
- file: OV5ScreensFood.swift:387
- headline: "anything the kitchen should know?" (italic: "kitchen") · sub "patterns, allergies, rules. multi-pick."
- options: 11 + "none of these" (exclusive) · writes: onboarding_dietary
- register-flags: "the kitchen" cutesy personification.

### 24. supports — multi (Stage A)
- file: OV5ScreensStageA.swift:14
- headline: "do you already take any of these?" (italic: "already") · sub "so the plan fits around your real days. jeni recommends nothing here. skip freely."
- options: protein powder / multivitamin / vitamin d / fiber / magnesium / electrolytes / "none of these"
- writes: onb_v5_supports · **Silent by design (FR8) — zero downstream render.**

### 25. receiptFood — bridge (dynamic receipt)
- file: OV5ScreensFood.swift:422
- headline: "your food story, heard." (italic: "heard.")
- rows: "you said" → relationship phrase · "your rhythm" → cadence phrase · "your table" → top-2 cuisines · footnote "tomorrow morning, we start quieting it."
- register-flags: "heard." therapy/poetic; "we start quieting it" metaphor promise.

---

## ACT III — "the numbers, gently"

### 26. numbersBridge — bridge
- file: OV5ScreensNumbers.swift:13
- headline: "the numbers, gently." (italic: "gently.") · sub "sixty seconds. never shown back as a grade.\nnever shared."
- register-flags: "gently" is the soft-register keyword; anti-shame frame.

### 27. movement — select
- file: OV5ScreensNumbers.swift:25
- headline: "how does movement fit right now?" (italic: "fit")
- options: "barely, honestly" (barely) · "walks here and there" (walks) · "regular-ish" (regular_ish) · "very active" (very_active)
- writes: onb_v4_movement_baseline
- register-flags: "barely, honestly"/"regular-ish" chatty labels.

### 28. sleep — select w/ conditional ack
- file: OV5ScreensNumbers.swift:45
- headline: "how much sleep, honestly?" (italic: "honestly")
- ack (short sleepers only): "then recovery leads. we pace for it." (:72)
- options: "under 5 hours" / "5 to 6" / "6 to 7" / "7 to 8" / "8 or more"
- writes: onboardingSleepHours · ack engine-coupled (provenance-true).

### 29. stress — select w/ conditional ack
- file: OV5ScreensNumbers.swift:93
- headline: "how heavy is life right now?" (italic: "heavy")
- ack (heavy/overwhelmed): "heard. the plan starts gentle on purpose." (:119)
- options: "low" / "manageable" / "heavy" / "overwhelmed"
- writes: onboardingStressLevel
- register-flags: "how heavy is life" metaphor; "heard." therapy filler; low answers silent.

### 30. gender — select
- file: OV5ScreensNumbers.swift:140
- headline: "which body does the math use?" (italic: "math")
- sub: "calorie math differs by sex. we use the Mifflin-St Jeor equation." — **named method**
- options: "female" / "male" / "non-binary" (nonbinary) / "prefer not to say" (private)
- writes: onb_v5_gender + canonical onboardingGender
- conditional: none on-screen. **Answering "male" changes NOTHING in any copy downstream.**

### 31. age — ruler
- file: OV5ScreensNumbers.swift:166
- headline: "how many years in?" (italic: "years"); unit "years"; range 16–80
- writes: onb_v5_age_years + band
- register-flags: euphemistic phrasing of "age" (cutesy-oblique).

### 32. height — ruler w/ unit tabs
- file: OV5ScreensNumbers.swift:190
- headline: "how tall are you?" · writes onb_v5_height_cm + mirror. Store default 165cm (female-typical seed, OV5Flow.swift:249).

### 33. weight — ruler w/ earned confirmation
- file: OV5ScreensNumbers.swift:238
- headline: "where's the scale today?" (italic: "today")
- trust "sets your starting point. never shown back as a grade." (:248) · post-commit ack "okay. that's the hard one" (:272)
- options: CTA "that's me" → "continue"; units lb/kg
- writes: onb_v5_weight_kg + mirror
- register-flags: "okay. that's the hard one" emotional hand-holding (selective-empathy-endorsed; review).

### 34. weightTrend — select w/ cohort ack
- file: OV5ScreensNumbers.swift:310
- headline: "lately, your weight has been…" (italic: "lately")
- ack (past-GLP-1 + climbing/cycling): "that's the regain window. it's exactly what we build for." (:337)
- options: "climbing" / "about the same" / "slowly coming down" / "up and down"
- writes: onboarding_weight_trend
- register-flags: "the regain window" clinical-sounding, no source; other answers silent.

### 35. goalDirection — select
- file: OV5ScreensNumbers.swift:363
- headline: "what are we working toward?" (italic: "working toward")
- options: "lose weight" / "maintain where i am" / "keep off what i've lost" / "tone up and get stronger" — **past-GLP-1 sees maintain_kept FIRST**
- writes: onboarding_goal_direction (+ program_mode, goal seeding).

### 36. goalWeight — ruler w/ anchor band + live derived line
- file: OV5ScreensNumbers.swift:388
- headline: loss "what number feels like yours?" / maintain "the weight you're keeping."
- live line: under-BMI-18.5 → "that number sits under the healthy range for your height. we'll aim you at the floor instead." · loss → "about" "{N} weeks" "at the gentlest pace. room for life." · else → "holding steady. the plan becomes a maintenance rhythm."
- writes: onb_v5_goal_kg + mirror
- register-flags: "what number feels like yours?" feelings-framing; "room for life." soft filler.

### 37. targetReframe — teach, 3 delta variants
- file: OV5ScreensNumbers.swift:498
- delta<1kg: "steady is a real goal." + maintenance lead (no citation)
- delta≤12%: "{N} lb is an honest target." + lead "the women who keep it off lose slowly, on purpose. even the first few pounds change how clothes sit." + closing "no crash math here. just a pace that survives real weeks." + **citation "wing & phelan · national weight control registry"**
- delta>12%: "{N} lb is a real journey. we pace it honestly." + lead "big deltas work when the pace protects your muscle and your sanity. we'll break yours into arcs, with maintenance built in." + closing "slower is what makes it stick." + **citation "hollis 2008 · weight-loss maintenance trial"**
- register-flags: "the women who keep it off" female-assuming; "how clothes sit" appearance frame; "your muscle and your sanity" casual.

### 38. nsv — multi w/ cohort extra
- file: OV5ScreensNumbers.swift:537
- headline: "what would you love back?" (italic: "love") · sub "beyond the scale. pick what matters."
- options: "a core that holds" / "energy that lasts" / "clothes that fit right" / "sleep that resets" + cohort extra: current "keeping muscle while i lose" / past "trusting food again" / else "quiet around food"
- writes: onboardingNsvPriority
- register-flags: "what would you love back?" emotional; poetic option grammar.

### 39. careBridge — bridge
- file: OV5ScreensNumbers.swift:572
- headline: "the care part." (italic: "care")
- sub: "a few questions we ask every woman, because some answers change what's safe to build.\nmost apps skip this. we can't." (:581)
- register-flags: **"every woman" female-assuming**; "most apps skip this" rhetorical claim.

### 40. medication — select (sensitive)
- file: OV5ScreensNumbers.swift:587
- headline: "any blood-sugar medication?" (italic: "blood-sugar")
- trust "changes how we pace fuel around movement. private, always."
- options: "insulin, or a daily pill for blood sugar" / "another blood-sugar medication" / "no" / "prefer not to say"
- writes: onboarding_medication_status.

### 41. safetyGate — bespoke sub-machine (pregnancy → SCOFF → optional terminal)
- entry: OV5ScreensNumbers.swift:619 → SafetyGatePresentation OnboardingRevealView.swift:375
- **41a. SafetyPregnancyView** (OnboardingComponents.swift:966): headline "one more, just to be safe." · sub "is any of this true for you right now? it helps us keep your plan right for your body ♡" (:992, heart U+2661) · options "none of these" / "i'm pregnant" / "trying to conceive" / "breastfeeding" / "prefer not to say" · writes safety_pregnancy_status. **Shown to ALL users regardless of gender answer.**
- **41b. SCOFFScreenView** (OnboardingComponents.swift:578): eyebrow "safety screening" + clinical cross mark · headline "a gentle check, first." · intro "before we build your plan, a few questions so we can make sure this is genuinely good for you. there are no wrong answers, and nothing here is judged." · 5 verbatim SCOFF items (:589-593) · per-item "no"/"yes" pills · writes safety_scoff_yes + safety_scoff_core.
- **41c. terminal variants** (SafetyTerminalVariant, OnboardingComponents.swift:778-848): headlines "your plan, made gentle." (ED) / "strong and steady it is." (lowBMI) / "gentle it is." (underage) / "nourishment first." (pregnant) / "steady and fed." (breastfeeding) / "clinician-aware it is." (clinicianFirst). **Every bodyText ends with a heart ♡** (:822-836), e.g. clinicianFirst: "some medications change how your body handles a deficit, so we've built your plan to be clinician-aware. please review the pace with your prescriber - they may want to adjust your dose. then you're all set ♡". CTAs "build my gentle plan" / "build my plan". ED variant adds SafetyResourcesCard ("support, any time" + US crisis lines, :713-750).
- writes: program_mode, safety_screen_completed, safety_pace_cap, safety_numeric_suppression
- register-flags: **hearts (♡) survive despite the 1.2.0 "hearts retired app-wide" voice pass** — OnboardingComponents.swift:822, 824, 826, 828, 830, 832, 835, 836, 992 (+ legacy SafetyConsentView:931); "gentle it is." / "steady and fed." twee grammar; SCOFF items correctly clinical (Morgan 1999 verbatim, unlabeled on screen).

### 42. receiptNumbers — bridge (dynamic)
- file: OV5ScreensNumbers.swift:643
- headline: "what you carry, counted." (italic: "carry")
- rows — "the distance" → "{N} lb, paced honestly" OR "the goal" → "holding steady"; "your nights" → sleep phrase; "your baseline" → movement phrase ("starting from stillness" for barely) · footnote "your plan starts there."
- register-flags: "what you carry" emotional-weight metaphor; "starting from stillness" poetic.

---

## ACT IV — "the part nobody asks"

### 43. identity — photoGrid
- file: OV5ScreensVulnerability.swift:9
- headline: "who is she, the one you're becoming?" (italic: "becoming")
- options: "powerful" / "calm" / "light" / "strong" / "radiant" — photo cards, assets onb-identity-* (it-girl photography of women)
- writes: onb_v5_identity
- register-flags: **the core "becoming her" conceit** — "she"; "radiant"/"light" femme adjectives; female photo assets.

### 44. hormonal — select (sensitive) w/ conditional care notes
- file: OV5ScreensVulnerability.swift:60
- headline: "where's your body at, hormonally?" (italic: "hormonally")
- trust "hunger, energy, and recovery ride differently in each stage. we adjust for it." · care notes (:111-115): postpartum → "we adjust for postpartum." / "no plank or supine work for the first 6 weeks. talk to your doctor before starting any program."; perimenopause → "we adjust for peri." / "we lean into strength + sleep cues. hunger and mood ride differently here, and we factor that in."; irregular → "we adjust for irregular cycles." / "we don't anchor the plan to a textbook 28-day cycle. expect more weight-by-week, less day-by-day."
- options: "cycling regularly" / "irregular cycle" / "postpartum" / "perimenopause" / "postmenopause" / "prefer not to say"
- writes: onboardingHormonalStage
- register-flags: **question + all options assume female physiology — no male path** (a male user must answer a menstrual-stage question or tap prefer-not-to-say); cycling/postmenopause answers get NO note; notes unsourced.

### 45. startedOver — select w/ conditional mirror
- file: OV5ScreensVulnerability.swift:124
- headline: "how many times have you started over?" (italic: "started over")
- mirror (3-5/many): "that's not failure. that's data." (:150)
- options: "this is my first real plan" / "once or twice" / "3 to 5 times" / "lost count"
- writes: onboardingPriorAttempts.

### 46. dataMirror — bridge (fully conditional receipt)
- file: OV5ScreensVulnerability.swift:170
- headline: "you told us the truth. here's what it changes." (italic: "changes.")
- rows (max 3, answer + live engine flag): "your short nights" → "recovery outweighs volume" / "your sleep" → "the quiet advantage, kept" / "peri" → "strength + sleep cues lead" / "postpartum" → "gentler floor, no supine work" / "alongside the shot" → "the rhythm is the same shape" / "in the after" → "keeping it is the goal" / "the start-overs" → "built into the pacing" · fallback "your answers" → "already shaping the plan"
- register-flags: "the quiet advantage, kept" poetic; "in the after" conceit.

### 47-49. fear1 / fear2 / fear3 — statement (yes/no)
- file: OV5ScreensVulnerability.swift:213 (component OV5Components.swift:290)
- statements: fear1 "i'm scared of apps that promise quick results." → onb_fear_quickResults; fear2 "i'm scared this turns into another diet." → onb_fear_anotherDiet; fear3 cohort-swapped: current "i'm afraid of what happens when i stop." → onb_fear_offramp / past "i'm afraid it all comes back now that i've stopped." → onb_fear_regain / else "i've given up after the first hard day." → onb_fear_priorAttempt
- yes-pin "we'll come back for this one." (OV5Components.swift:327)
- options: "not really" / "yes, that's me" (:337-338)
- conditional: fear3 by cohort; progress freezes across triplet.

### 50. whyItCameBack — teach (scroll, curve figure)
- file: OV5ScreensVulnerability.swift:255
- headline: "it wasn't your willpower." (italic: "willpower.")
- lead "the last plan didn't fail because you're weak. three things were quietly working against you." · curve labels "the quick fix" / "paced, with a maintenance arc" (:410-415) · points: i "your body adapts." gloss "cut too hard and your metabolism slows to match. the loss stalls, then it creeps back." · ii "all-or-nothing breaks." gloss "one off day ends a strict plan, and a normal slip starts to feel like a personal failure." · iii cohort: past "the prescription ended. the rhythm didn't exist." / else "no one stayed for the after." (shared gloss "most plans rush you to a number, then leave. keeping it off is the part they skip.") · closing: current "whenever the shot chapter ends, the rhythm stays." / else "we're built for the part they quit on." · citation block "the women who keep it off lose slowly and ride out the stalls." + "NATIONAL WEIGHT CONTROL REGISTRY" (:337-343)
- options: CTA "this is the one" (:355)
- register-flags: "the women who keep it off" female-assuming; points i/ii unsourced at row level; "no one stayed for the after." poetic; CTA is a conviction/sales line.

### 51. receiptCarry — bridge
- file: OV5ScreensVulnerability.swift:431
- headline: "almost yours." (italic: "yours.")
- sub: 0 fears "no fears kept. just a plan to build." · 1 "one fear kept. the plan answers it before you pay a cent." · n "{spelled} fears kept. the plan answers each one before you pay a cent." · footnote "one act left: your file, then your plan."
- register-flags: "before you pay a cent" pre-sells the wall inside a care beat.

---

## ACT V — "almost hers"

### 52. herFile — bespoke dossier card
- file: OV5ScreensClose.swift:9
- headline: "her file, ready." (italic: "file")
- card title "{name}'s"/"her" + "file" · rows (conditional): "HERE FOR" → outcome phrase; "THE DISTANCE" → "{N} lb, honest pace" OR "THE MODE" → "maintenance rhythm"; "BECOMING" → "the powerful one"/"the calm one"/"the light one"/"the strong one"/"the radiant one"; "CHAPTER" → "alongside the shot" / "the after. keeping it"; "HER TABLE" → cuisines · footer "JENI · HER PLAN" (:54)
- options: CTA "this is me" (:77)
- register-flags: **"her file"/"her table"/"JENI · HER PLAN" — female grammar hard-coded regardless of gender answer**; "the radiant one" conceit noun phrases.

### 53. signature — bespoke consent card
- file: OV5ScreensClose.swift:110
- headline: "sign her in." (italic: "sign") · sub "the fine print, {name}. all of it honest."
- rows (nothing pre-checked): "use my answers to personalize my plan" / "the whole point. pace, food, lessons. tuned to your file." · "check on me in the first days" / "a gentle nudge or two while the habit is newborn." · "i know this is a plan, not medical advice" / "for medication, pregnancy, or health conditions, your clinician leads." (medical row gates the CTA)
- options: CTA "signed"
- writes: onb_consent_personalize, onb_consent_day2, medicalDisclaimerAckAtISO
- register-flags: **"sign her in."** female grammar; "while the habit is newborn" cutesy metaphor; medical row well-registered.

### 54. healthKit — bespoke permission
- file: OV5ScreensClose.swift:225
- headline: "your steps already count." (italic: "count.") · sub "connect health and the plan cites your real week, not a guess."
- mock card "steps" / "7,500 goal" / "counted for you"
- options: CTA "connect health" · secondary "not now"
- writes: healthKitStepsRequested; HK read auth.

### 55. holdToBuild — bespoke ritual
- file: OV5ScreensClose.swift:305
- headline: "everything's here." (italic: "everything's") · sub "fifty-two answers. one plan."
- options: HoldToPromiseButton "hold to build it" → "promised" (HoldToPromiseButton.swift:124)
- register-flags: **"fifty-two answers" is a hard-coded count that traces to nothing** (path lengths are 44-48 and many beats aren't questions) — violates data-provenance; "promised" ritual register.

---

## REVEAL SEQUENCE (v5 enters at .building)

Host: OnboardingRevealView.swift:34 (step enum :100-146; v5 skipsPreamble :97). Legacy-only, not rendered in v5: DisclaimerPresentation (:597) and the reveal-positioned safety step (:163).

### R1. building — loader (receipt tape)
- file: BuildingPlanLoadingView.swift:26
- headline: "personalizing your plan" → completion "your plan, ready." + "every answer is in it." (:78-97)
- tape lines (each only when its key is set): "starting from {stillness, gently / your walks / your regular-ish rhythm / a strong base}…" · "shaping around {cadence phrase} days…" · "keeping {cuisine + cuisine} on the table…" · "remembering {dietary}…" · "your practice plate, read in seconds…" · "learning from every start-over…" · sleep: "pacing gentler for your short nights…" / "accounting for your 6-to-7 hours…" / "accounting for your solid sleep…" / "banking your deep recovery…" · "weighting recovery for the load you carry…" (heavy stress) · "adjusting for where your body is…" (hormonal) · current: "pacing for the shot · protein first…" + "easing the days after your shot…" (after_shot) · past: "fresh off the shot · defending it…" / "3-6 months off · defending it…" / "6-12 months off · defending it…" / "a year off the shot · keeping it yours…" / "the after-chapter · keeping it yours…" · "aiming at {nsv phrase}…" · "building your maintenance rhythm…" OR "setting your calorie window…" · fixed: "no forbidden foods. nothing to earn…" · "computing your projection curve…" · closer "your becoming, ready" (:223-347)
- options: CTA "see your plan" (:131); **ATT fires at ~30% progress (:393)**
- register-flags: "your becoming, ready" conceit; "banking"/"defending it"/"keeping it yours" poetic; "the load you carry" emotional.

### R2. pacePicker
- file: OnboardingRevealView.swift:2053
- headline: "how fast feels right?" (italic: "right") · sub "ACSM-safe range. you can change this later." (:2122) — **named source**
- options (rows w/ slope glyph + live weeks numeral): "soft" → "0.5% a week ≈ {N} {lb|kg} for you. room for life." · "steady" → "0.75% a week ≈ {N} … most chosen." · "focused" → "1% a week ≈ {N} … fastest healthy pace." (:2133-2176)
- writes: onboardingPickedTier + pace defaults
- register-flags: "how fast feels right?" feelings-framing; **"most chosen." social-proof claim without data provenance**; "room for life." filler.

### R3. projection — the reveal peak
- file: OnboardingRevealView.swift:901
- headline: loss "your becoming, plotted" / maintenance-or-suppressed "your plan, steady" (:1026) · sub: loss "the next {N} weeks of your care plan, drawn from your answers." / maintenance "you're right where you want to be. here's the fuel to hold it." (:1044,1230-1239)
- curve: BecomingProjectionCard (axis "today", date italic, "~{N} {lb}/wk · {pace} pace") + caption "an estimate, not a promise." (:1075)
- tiles (4, calorie-computed gate): "calories" {kcal} "from your height, weight + pace" · "protein floor" {N}g "protects muscle while you lose" · "movement" "7,500" "steps · counted for you" · "weigh-ins" "the trend" "read the week, never the day" + footer "a starting plan. we'll tune yours over the first few weeks" (:1467-1511) + "these numbers are yours to keep." (:1092)
- credibility strip "the science behind your pace" (:1256-1311): provenance row (conditional, tag "calibrated for you"): "because you sleep around 6 hours, we set a gentler pace." / "because of your body's signals right now, we paced this gently." (GLP-1) / "because of where your body is, we paced this gently." (peri) · "paced to the 0.5-1% a week range clinicians use. slower is what lasts." — **ACSM** · "women who keep it off lose slowly, and ride out the stalls." — **national weight control registry** · "the first milestone that moves health is 5-7%. for most women it arrives well before a final goal, each at her own pace." — **clinical consensus** · conditional "safety-screened before you started." — "pre-paywall check ✓"
- causal receipts (max 3, answer+engine-gated, :1576-1593): "because you're on a GLP-1" → "protein leads your plate" · "because you stopped the shot" → "keeping it is the first goal" · "because you sleep under six" → "we paced you gentler" · "because you're in peri" → "strength + sleep cues lead" · "because it came back before" → "the pace protects the after"
- writes: stamps foodDailyTarget
- register-flags: "your becoming, plotted" conceit; "women who…"/"each at her own pace" female-assuming; **"clinical consensus" vague source tag**; "these numbers are yours to keep." reciprocity-sales line.

### R4. firstWeek
- file: OnboardingRevealView.swift:1878
- headline: "your first week of care." · sub "the rhythm your plan runs on."
- 7 DayTiles (OnboardingComponents.swift:413-543): titles "protein"/"movement"/"balanced"/"rest", details "{N} min workout" / "snap + breathe" / "breathe + reflect" · "you can change pace or rest days anytime." · locked Day-1 device mock + "tomorrow morning, as it will actually look." · GLP-1 rails: "add your plate · protein is the number to watch" + (current w/ shot day) "medication rhythm · {weekday}s anchor the week" (:1982-1992)
- register-flags: none major — one of the cleaner beats.

### R5. reviewGate — rating sentiment (once/install)
- file: RatingSentimentScreen.swift:19
- headline: "enjoying jeni so far?" · sub "a quick word helps other women find us." (:56)
- options: "yes, loving it" (→ native review sheet) · "not really" (→ feedback sheet)
- conditional: RatingPromptService.isEligible(.postPlanReveal)
- register-flags: **"other women" female-assuming**; "yes, loving it" enthusiastic register.

### R6. fear resolution (renders only if a fear was kept)
- file: OV5FearResolution.swift:12
- pattern: her fear re-stated then struck through → answer headline → mechanic paragraph. Priority: regain → "keeping it off is its own becoming." / offramp → "the rhythm stays." / priorAttempt → "we planned for the day you'd usually quit." / anotherDiet → "this one ends." + "your plan runs about {N} weeks, then shifts to keeping. a program with an end, not a diet without one." / quickResults → "no overnight promises." + "your pace sits inside the clinically safe band, and the projection you just saw is an estimate, not a promise. slow is the strategy."
- options: CTA "keep going"
- register-flags: "its own becoming" conceit; "clinically safe band" unsourced at this site.

### R7. commitment ritual
- file: OnboardingRevealView.swift:2324
- headline: eyebrow "your first promise" + "before the plan, one promise." (italic: "promise")
- panel: WHEN chips "after coffee" / "after i wake up" / "after lunch" · WHAT chips "snap your first real meal" (leads if demo done) / "log breakfast" / "snap what i eat" / "log my first meal" — GLP-1 current gets fixed row "protect your muscle" · "from your practice run" caption · TIME chips "8am" / "12pm" / "6pm"
- replay: "your promise:" + "tomorrow, {anchor}, you'll {action}." · empty "when · what · time. it builds here." · ghost CTA "choose when · what · time"
- options: HoldToPromiseButton "hold to promise" → "promised"
- writes: day1Promise* keys; schedules Day-1 push
- register-flags: "protect your muscle" imposed for GLP-1 (no choice).

### R8. permissions — notification ask (last pre-wall beat)
- file: OnboardingRevealView.swift:1640 (banner NudgeNotificationBanner.swift:16)
- headline: "want a nudge from jeni?" · sub "one quiet one a day. nothing nagging."
- banner mock: "Jeni" · "now" · title "your promise, gently." (promise set) / "five minutes, today." · body "{anchor} · {action}" / "five minutes is enough today. small moves still count." · hint "tap to feel it" · arrives line "arrives {bucket} · change anytime in settings"
- options: CTA "allow notifications" · secondary "not right now"
- writes: notificationsEnabled, plankTime
- register-flags: "your promise, gently." / "small moves still count." soft-reassurance.

---

## PAYWALL — the keep wall (PaywallView.swift:119)

**Chrome:** X close · "already a member? sign in" · "·" · "Restore" (:1742-1803). Scroll-gated paper scrim (:793-804).

**FOLD:** 1. Hero "{name}, your plan to {goal} lb." (italic goal number; fallback "{name}, your plan is ready.") (:336-344,882). 2. Promise chart: her curve, "{168} lb" → "{151} lb" pill, rose dose-dot terminus; axis "you, today" · "~{1.2} {lb}/wk · {steady} pace" · **"her, {sep 14}"** (:906-950, chart :2109). Omitted for maintenance/no-goal. 3. Tier band (:1007-1055): eyebrow "pick how you start" · "the year" + "most popular" + "your whole plan · save {N}%" + "{$0.92} /wk" + "{$47.99} per year" · "the quarter" + "three months · save {N}%" · "one week" + "just trying it? that's ok" + "{$N}/year if billed weekly" (:1122-1137). Beam on selected row. Authority line: "paced to ACSM guidance · safety-screened before you started." / "…built for sustainable loss." (:1046-1048). 4. conditional reclaim row (:1599-1603); offerings-failure row (:1811).

**DOCKED CLOSE (pinned):** "money-back guarantee · no forms, no guilt" (shield) · "renews {date+year yearly} unless you cancel · two taps in settings" · CTA "keep my plan · {$47.99} today" · "apple will ask to confirm · that's the whole plan" (:752-782,1625-1643).

**BELOW-FOLD BANDS (:1289-1542):**
- Band 1 "your plan, on one page" (:1357): "CALORIES" → "{1620} kcal a day" / "from your height, weight + the pace you chose" · "PROTEIN FLOOR" → "{94}g a day" / "protects muscle while you lose" · "THE PACE" → "{~1.2 lb/wk · steady pace}" / "on track for {sep 14} · an estimate, not a promise" · (GLP-1 current + shot day) "MEDICATION RHYTHM" → "{thursdays} anchor the week" / "dose days compose themselves around it"
- Band 2 "why this works" (:1419): "slow is the strategy. your pace sits inside the 0.5-1% a week band clinicians use." — **ACSM** · "the women who keep it off lose slowly, and ride out the stalls." — **national weight control registry** · "protein + movement protect lean mass while the scale moves." — **lean-mass findings · nejm step 1** · (conditional) "you were safety-screened before this screen. most apps skip that." — "pre-pay check ✓" · (dormant ClinicalReview) "content reviewed for clinical accuracy by {name}, {credentials}."
- Band "from the app store" (:1459, **dormant** — PaywallRealProof empty at :33-58)
- Band 3 "what's included" (:1490): "the daily checklist" / "your day, composed each morning" · "add meals before you eat" / "the photo read, in seconds" · "weigh-ins read as a trend" / "never a grade, never day-to-day" · "the method" / "2-minute reads that stick" · "letters from jeni" / "plus your weekly review"
- Band 4 "the jeni rules" (:1522): "no red numbers. no grades." · "a bad day is in the math. tomorrow resets, nothing is forfeited." · "no streaks to lose. kept days never reset." · "your data stays yours. never sold." — ink JeniMark + "— jeni"

**Footer (:1555-1583):** fear-conditional closing — anotherDiet "not another diet. a program that ends · no ads, ever" / priorAttempt "built for the day you'd usually quit · no ads, ever" / quickResults "no overnight promises. just a real pace · no ads, ever" / default "your data stays yours · no ads, ever" · "terms" "·" "privacy".

**System/error copy:** restore alerts (:2023-2035); "Couldn't load pricing…" (:1908); "Purchase didn't activate Pro. Try again or contact support@jenifit.app." (:1962).

- paywall register-flags: **"her, {date}" axis female-conceit at the money moment**; "the women who keep it off" female-assuming; "just trying it? that's ok" chatty; "no forms, no guilt" emotional; headline/CTA otherwise outcome-factual; all prices live-StoreKit; save-% checkable arithmetic.

---

## 1. SUMMARY TABLE

| Section | Beats | Seen | Conditional | Named-source lines | Notable unsourced claims |
|---|---|---|---|---|---|
| Act I | 6 | 6 | 0 | 0 | "0.5-1% a week, the clinical band"; "the last plan failed you" |
| Act II | 19 | 11-15 by cohort | 12 of 19 | 2 (nejm step 1; jama 2025) | food-noise "it's biology / hunger hormones" (all 3 variants) |
| Act III | 17 | 17 | 9 of 17 | 3 (Mifflin-St Jeor; wing & phelan · NWCR; hollis 2008) | "the regain window"; "most apps skip this"; hormonal care notes |
| Act IV | 9 | 9 | 6 of 9 | 1 (NWCR) | "your body adapts / metabolism slows" |
| Act V | 4 | 4 | 2 of 4 | 0 | "fifty-two answers" (fabricated count) |
| Reveal | 8 | 6-8 | 7 of 8 | 4 (ACSM ×2; NWCR; "clinical consensus" 5-7%) | "most chosen."; "clinically safe band" (fear res) |
| Paywall | 1 screen | 1 | most zones | 4 + 2 dormant slots | "most apps skip that" |
| **Total** | **55 + 8 + wall** | ~44-48/user | ~36 | ~14 | ~9 recurring naked-claim families |

## 2. FEMALE-SPECIFIC CONTENT MAP
(the gender answer gates ZERO copy — a male/nonbinary user gets every line below)

| # | Content | file:line |
|---|---|---|
| 1 | Act eyebrows "her arrival", "her food story", "almost hers" | OV5Flow.swift:100-103 |
| 2 | "women who've tried everything. women alongside the shot…" | OV5ScreensArrival.swift:74 |
| 3 | "the women who keep it off lose slowly, on purpose." | OV5ScreensNumbers.swift:517 |
| 4 | "a few questions we ask every woman…" | OV5ScreensNumbers.swift:581 |
| 5 | Hormonal-stage question + all six options — no male path, no gender gate | OV5ScreensVulnerability.swift:60-122 |
| 6 | "who is she, the one you're becoming?" + onb-identity-* female photo assets | OV5ScreensVulnerability.swift:13-24 |
| 7 | "the women who keep it off…" + NWCR chip | OV5ScreensVulnerability.swift:337-340 |
| 8 | dataMirror rows "peri" / "postpartum" | OV5ScreensVulnerability.swift:192-196 |
| 9 | "her file, ready." · "her"/"{name}'s" file · "HER TABLE" · "JENI · HER PLAN" | OV5ScreensClose.swift:16,22-27,54,105 |
| 10 | "sign her in." | OV5ScreensClose.swift:125 |
| 11 | Pregnancy/TTC/breastfeeding screen (ungated by gender) | OnboardingComponents.swift:966-1027 |
| 12 | Terminal copy "nourishment first." / "steady and fed." / "…protects your supply" | OnboardingComponents.swift:798-836 |
| 13 | Projection strip "women who keep it off…" + "for most women… each at her own pace." | OnboardingRevealView.swift:1287,1295 |
| 14 | Provenance line "because of where your body is…" (peri) | OnboardingRevealView.swift:1351 |
| 15 | Causal receipt "because you're in peri" | OnboardingRevealView.swift:1587 |
| 16 | Loader "adjusting for where your body is…" (hormonal-keyed) | BuildingPlanLoadingView.swift:255 |
| 17 | "a quick word helps other women find us." | RatingSentimentScreen.swift:56 |
| 18 | Paywall axis "her, {date}" (vs "you, today") | PaywallView.swift:933-938 |
| 19 | Paywall why-it-works "the women who keep it off…" | PaywallView.swift:1427 |
| 20 | Fear-res "keeping it off is its own becoming." + reveal "your becoming, plotted" | OV5FearResolution.swift:96; OnboardingRevealView.swift:1026 |
| 21 | Store seeds: default height 165cm / weight 72kg; reveal fallback 165 | OV5Flow.swift:249-250; OnboardingRevealView.swift:1427 |
| 22 | Welcome device-mock avatar onb-profile-latte + it-girl thumbnails | OV5DeviceDemo.swift:112,132-135 |

## 3. SILENT ANSWERS MAP

| Question | Key | Status |
|---|---|---|
| attribution | onb_v5_attribution | Fully silent (analytics-only — expected, zero ack) |
| glp1Phase | onboarding_glp1_phase | No ack/echo; silently moves pace math |
| appetiteReturn | onboarding_appetite_return | **Completely dead** — no ack, no echo, no engine reader |
| priorWin | onboardingPriorWin | **Dead in v5** |
| supports | onb_v5_supports | Silent by design (FR8) — user sees nothing for the disclosure |
| gender | onboardingGender | No ack; engine-only; **no copy anywhere adapts** |
| age / height | onb_v5_age_years / onboardingHeightCm | No ack/derived line (deliberate); engine-only |
| stress = low/manageable | onboardingStressLevel | Silent (ack fires only heavy/overwhelmed) |
| weightTrend = stable/declining | onboarding_weight_trend | Silent (ack only past-GLP-1 climbing/cycling) |
| hormonal = cycling/postmenopause | onboardingHormonalStage | No care note (3 of 6 answers have one) |
| appetiteRhythm ≠ after_shot | onb_v5_appetite_rhythm | Echo only for after_shot |
| medication = none/other_glucose | onboarding_medication_status | No ack ever |
| SCOFF + pregnancy | safety_* | Silent unless terminal fires (clinically deliberate) |
| eatingCadence/cuisine/dietary/nsv/foodRelationship/outcome/identity/snapDemo/sleep/weight/goal/fears/shotDay/stopWindow/startedOver | — | NOT silent (receipts/tape/dataMirror/herFile/fear-res/paywall echo them) |

## 4. Cross-cutting register findings (for the rewrite)

1. Hearts officially retired but **9 live ♡ occurrences remain in the safety-gate views** (OnboardingComponents.swift:822-836, 931, 992) — inside the single most clinical moment of the flow.
2. The "becoming her / she" conceit spans question copy, receipts, dossier, reveal headline, and the paywall axis — the deepest-rooted female assumption.
3. The gender answer is collected with a named-method rationale but conditions **no copy anywhere**.
4. The strongest existing scientific register (citation chips, engine-coupled acks, number+unit+basis tiles, ACSM/NWCR/NEJM naming) already exists as a pattern — concentrated in muscleMath/regainTruth/targetReframe/pacePicker/projection/paywall and absent from Act I, food-noise, and the safety terminals.
5. Two answers (appetiteReturn, priorWin) and one disclosure (supports) are collected and never reflected — cost without payoff.
6. One fabricated number: "fifty-two answers. one plan." (OV5ScreensClose.swift:322).
