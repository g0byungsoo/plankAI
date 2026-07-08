# Onboarding v5 — Screen-by-Screen Flow + Copy Deck

Archetypes: **Q** list-question (cross-off single-select, auto-advance) ·
**QC** continue-question (sensitive; explicit CTA) · **M** multi-select ·
**PG** photo-grid · **R** ruler · **T** teach · **B** bridge/receipt ·
**S** statement yes/no · **X** bespoke. Italic punch marked *word*
(spec only — implement via ItalicAccentText). All single-selects write
option KEYS identical to v4.5 (labels may differ). "→" = writes.

Progress: 5 acts, hairline segments. Acts: i her arrival · ii her food
story · iii the numbers, gently · iv the part nobody asks · v almost hers.

## ACT I — her arrival

| # | id | A | spec |
|---|----|---|------|
| 1 | welcome | X | Collage (9-13 cutouts, from-behind hero girl, one scanned-plate polaroid w/ soft kcal pill, ≤2 stickers). Headline line-cascade: "become *her*." · pill "a plan that finally fits" · CTA "i'm ready" · "free to start." · "already have an account? sign in" |
| 2 | antiShame | T | "the last plan failed *you*. not the other way around." body: "no clean slates needed. no earning your way in. we build around your actual life, starting with how you actually eat." (no citation) |
| 3 | outcome | Q | "what are you *here* for, mostly?" opts: myself "feel like myself again" · noise "quiet the food noise" · energy "steady energy" · clothes "clothes that fit right" · keep "keep off what i lost" → `onb_v5_outcome` + legacy `goal` mirror (myself→confidence, noise→foodpeace, energy→energy, clothes→confidence, keep→maintain — verify legacy space at build) |
| 4 | attribution | Q | "where'd you *find* us?" logo assets, cross-off debut → acquisitionSource (tiktok/instagram/friend/app_store/google/other) |
| 5 | credibility | T | "you're in the *right* place." body: "women who've tried everything. women alongside the shot, or after it. women done with all-or-nothing. the plan listens either way." (patterns copy, NO counts) |
| 6 | name | X | "what do we *call* you?" field + keyboard-attached CTA, ghost→solid. skip = "later" quiet link → name |

## ACT II — her food story

| # | id | A | spec |
|---|----|---|------|
| 7 | glp1Status | QC | "any weight meds right *now*?" trust line: "the plan reads differently on, after, or without them. private, always." opts: none "no" · current "yes, i'm on one" · past "i was. not anymore" · considering "thinking about it" · prefer_not_say "prefer not to say" (lock) → `onboarding_glp1_status`. Inline ack (ship-only promises): current "we pace for the shot." · past "the first goal is *keeping* what you built." · considering "med or no med, the daily piece is the same." |
| 7a | glp1Phase (current) | QC | "how long on *it*?" just_started "just started" · few_months "a few months" · established "it's routine now" · prefer_not → `onboarding_glp1_phase` |
| 7b | appetiteRhythm (current) | Q | "when is eating *hardest* right now?" after_shot "the day or two after my shot" · late_week "late week, appetite creeps back" · most_days "most days right now" · varies "it varies" → `onb_v5_appetite_rhythm` |
| 7c | muscleMath (current) | T | "a share of what's lost on the shot is *muscle*." i "appetite down means protein down, quietly." ii "protein + movement decide what you keep." closing "that's the work we do beside it." chip: "lean-mass findings · NEJM STEP 1" |
| 7d | stopWindow (past) | QC | "how long since you *stopped*?" under3 "under 3 months" · three6 "3 to 6 months" · six12 "6 to 12 months" · overyear "over a year" · prefer_not → `onboarding_glp1_stop_window` |
| 7e | appetiteReturn (past) | Q | "is your appetite finding its way *back*?" fully "fully back" · creeping "creeping back" · notyet "not yet" · waves "it comes in waves" → `onboarding_appetite_return` |
| 7f | regainTruth (past) | T | "and then the volume came *back*." i "appetite returning is physiology, not failure." ii "about half stop within the first year." (chip: "JAMA 2025") iii "the rhythm is the part nobody prescribed." closing "that's the part we're built for." |
| 7g | consideringAgency (considering) | T | "med or no med, the daily piece is the *same*." body: "if you ever start one, this still fits. if you never do, this is the whole plan." |
| 8 | foodRelationship | Q | "what is food, *mostly*?" fuel/comfort/love/control/complicated (v4.5 keys+subs, NO stickers) → onboardingFoodRelationship |
| 9 | foodNoise | T | cohort-routed: generalWL/considering "that 3pm loop in your head? it has a *name*." (food-noise teach, v4.5 spine) · current "you know food noise because it went *quiet*." · past "and then the volume came *back*." → (7f exists; past variant here shifts to "quieter hunger still deserves a *plan*." to avoid repeat) |
| 10 | preEat | T | pre-eat permission wedge (166 content): "snap it *first*. see if it fits." — sets up demo |
| 11 | snapDemo | X | full spec in OV5SnapDemo section below → `onb_v5_snap_demo_meal` |
| 12 | eatingCadence | Q | "how do you usually *eat*?" one_meal/two_meals/three_meals/grazing/chaotic (v4.5 keys) → onboardingEatingCadence |
| 13 | priorWin | Q | case 159 content: "what *worked*, even briefly?" (keys verbatim from v4.5) → onboardingPriorWin |
| 14 | cuisine | PG | "what's on *your* table?" existing onb-cuisine-* photo grid, multi → onboardingCuisinePreference CSV |
| 15 | dietary | M | case 170 content (pattern + restrictions + allergies) → onboarding_dietary CSV |
| 16 | receiptFood | B | "your food story, *heard*." 3 hairline rows citing her keys (relationship · cadence · cuisines) + "tomorrow morning, we start quieting it." tap-through |

## ACT III — the numbers, gently

| # | id | A | spec |
|---|----|---|------|
| 17 | numbersBridge | B | "the numbers, *gently*." sub "sixty seconds. never shown back as a grade. never shared." |
| 18 | movement | Q | case 8 content, keys verbatim → onb_v4_movement_baseline |
| 19 | sleep | Q | "how much *sleep*, honestly?" under5/five6/six7/seven8/eightPlus (v4.5 keys) → onboardingSleepHours |
| 20 | stress | Q | case 155 content, keys verbatim → onboardingStressLevel |
| 21 | gender | Q | case 130 keys (female/male/nonbinary/private) → OnboardingData.gender |
| 22 | age | R | ruler 16-70, seed 25 → ageYears (+ bucketize mirror). no derived line |
| 23 | height | R | ruler cm/in toggle → heightCm. no derived line |
| 24 | weight | R | ruler lb/kg → currentWeightKg. confirmation "okay. that's the hard one ♥" |
| 25 | weightTrend | Q | case 1320 keys (climbing/stable/declining/cycling) → onboarding_weight_trend. inline (past+climbing): "that's the regain window. it's exactly what we build for." |
| 26 | goalDirection | Q | case 1330 keys+behavior (lose/maintain/maintain_kept/recomp). past cohort: maintain_kept FIRST. → onboarding_goal_direction + program_mode + goal seed |
| 27 | goalWeight | R | ruler seeded per direction; rose delta band + "−12 lb" pill; live line from ProgramGoalCalculator ("about 0.5% a week. *room* for life."); BMI-floor gate state (sage, disables continue) → goalWeightKg |
| 28 | targetReframe | T | IMMEDIATELY next (conveyor). 3 dynamic variants keyed to delta (maintain / on-pace Wing&Phelan / ambitious honest-pace). cites her actual numbers |
| 29 | nsv | M | case 136 NSV cards + cohort extras (current: "keeping muscle while i lose", "steady energy" · past: "trusting food again", "no rebound spiral" · considering/generalWL: "quiet around food") → onboardingNsvPriority CSV |
| 30 | careBridge | B | "the *care* part." sub "a few questions we ask every woman. most apps skip this." |
| 31 | medication | QC | case 1642 keys verbatim → onboarding_medication_status |
| 32 | safetyGate | X | SafetyGatePresentation relocated (SCOFF/pregnancy/BMI/med routing, machinery untouched). passed → receiptNumbers. terminals park here |
| 33 | receiptNumbers | B | "what you *carry*, counted." rows: her delta or maintenance frame · sleep band · movement. + "your plan starts *there*." |

## ACT IV — the part nobody asks

| # | id | A | spec |
|---|----|---|------|
| 34 | identity | Q | case 140 content (identityFeeling: powerful/calm/light/strong/radiant, keys verbatim) → identityFeeling (bookend payload) |
| 35 | hormonal | QC | "where's your body at, *hormonally*?" restored why-line. keys verbatim (cycling/irregular/postpartum/perimenopause/postmenopause/prefer_not_say) + duty-of-care inline cards (v4.5 strings) → onboardingHormonalStage |
| 36 | startedOver | Q | "how many times have you *started over*?" case 158 keys verbatim, labels: first "this is my first real plan" · once "once or twice" · few "a few times" · lost_count "lost count" (verify keys) + mirror on high counts: "that's not failure. that's *data*." → onboardingPriorAttempts |
| 37 | dataMirror | B | "you told us the truth. here's what it *changes*." 3 rows interpolating stored answers (sleep→recovery weighting w/ Nedeltcheva chip · hormonal→lead cue · glp1→identity ack ONLY). rows render only when key set + modifier real |
| 38-40 | fear1/2/3 | S | rapid-fire giant-serif statements, progress frozen, yes/no docked pills, strike-the-fear on "no", pin on "yes" ("we'll come back for *this* one."). 1: "i'm scared of apps that promise *quick* results." → onb_fear_quickResults. 2: "i'm scared this turns into another *diet*." → onb_fear_anotherDiet. 3 cohort: generalWL/considering "i've given up after the first *hard* day." → onb_fear_priorAttempt · current "i'm afraid of what happens when i *stop*." → onb_fear_offramp · past "i'm afraid it all comes back now that i've *stopped*." → onb_fear_regain |
| 41 | whyItCameBack | T | 290 spine + rebound-curve Path visual (two thin curves, no axis numbers) + NWCR chip. cohort variants: past point iii "the prescription ended. the *rhythm* didn't exist." · current closing "whenever the shot chapter ends, the rhythm *stays*." |
| 42 | receiptCarry | B | "almost *yours*." + the fears she crossed out rendered struck-through + "the plan answers the ones you kept." |

## ACT V — almost hers

| # | id | A | spec |
|---|----|---|------|
| 43 | herFile | X | dossier card "her *file*" masthead w/ her name, cross-off rows of givens (outcome · cadence · delta/mode · pace-relevant flags). endowment beat |
| 44 | signature | X | consent signature moment: 2 checkbox rows (onb_consent_*) + 3rd row medical ("i understand this is a plan, not medical advice") → medicalDisclaimerAckAtISO. styled as the file's signing page |
| 45 | healthKit | X | "your steps already *count*." mock mini rings card (2° tilt), CTA connect / skip equal dignity. payoff promised on projection |
| 46 | holdToBuild | X | "hold to *build* it" — press-and-hold, cocoa ring fill ~1.2s, haptic ramp → finish() → reveal |

## REVEAL (OnboardingRevealView, edited)

Step order: building → pacePicker → projection → firstWeek →
fearResolution (replaces ratingAsk) → commitment → permissions → wall.
(disclaimer folded into #44; safetyGate moved to #32.)

- **building** = receipt tape: serif hero "building *your* plan", 2pt
  hairline bar, lines appear one-at-a-time in reading zone then compress
  up into checked micro-stack. Lines cite LIVE keys only: movement ·
  cuisine words · sleep band · cohort line (current "pacing for the
  shot · protein first ✓" / past "defending what you built ✓") · NSV ·
  "no forbidden foods. nothing to *earn*." Final: calorie number counts
  up → "your plan, *ready*." tap-to-continue. FIXES dead-field bug.
- **pacePicker** = keep 3 cards + live date; re-skin only.
- **projection** = keep grid + add: identity greeting ("maya, the *calm*
  one. she's already in you."), causal receipt rows (only fired
  modifiers), protein co-line (flip flag; GLP-1 accent), HK steps line
  (real avg or "we'll count your steps whenever you're ready"), plain
  cohort provenance, typographic ♥ fix, "you can tune this anytime".
- **firstWeek** = "day one, *tomorrow*." + day-one artifact card (white,
  masthead 'day one', her name, date range, 4 rails w/ real numbers,
  tracked-caps footer, share button → ImageRenderer PNG) + glance week
  strip. Rails cohort-routed. Kills the contradicting "no counting" line
  ("snap your plate · *protein* is the number to watch" for current).
- **fearResolution** = one screen keyed to her yes-fears: priorAttempt →
  "we planned for the day you'd usually *quit*." (reset weeks) ·
  anotherDiet → "this one *ends*." (her N-day terminal date) ·
  quickResults → "no overnight promises." (her ACSM pace line) ·
  offramp → "whenever that chapter ends, the rhythm stays." · regain →
  "keeping it off is its own *becoming*." skips silently if no yes-fears.
- **commitment** = keep ritual; time chips write BOTH day1PromiseTimeISO
  + plankTime bucket (merged anchor). Snap-demo prefill: promise action
  pre-selected "snap your first real meal" w/ caption "from your practice
  run" when demo completed.
- **permissions** = NudgePermissionAsk: banner payload = HER promise at
  HER time, cohort-routed title, second row "jeni · a reminder before
  anything renews" when intro offer exists (reads live product), body
  "nothing renews without a *heads-up* ♥", no time pills (stamped).

## Analytics (fired from OV5)

`ov5_act_receipt` (act) · `ov5_demo_completed` (meal, dwell) ·
`ov5_promise_set` (action, timeBucket) · `ov5_notif_allowed` ·
`ov5_hk_allowed` · `ov5_gate_outcome` (passed/terminal type).

## Layout-family rule

No archetype twice in a row. The router asserts this in DEBUG; receipts
and teaches break Q-runs; rulers cluster deliberately as one "input
ritual" (same family intentionally — the exception, reads as one beat).
