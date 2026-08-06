# Onboarding v7 — Current-State Audit (synthesis)

2026-08-02. Two full audit passes over the live tree (post-v6, clean at
30086cf): `audit/beat_inventory.md` — every beat with exact copy,
writes, conditionality, and register flags, plus the female-specific
content map (22 sites), silent-answers map, and paywall inventory ·
`audit/data_flow.md` — every collected key traced to its REAL readers
with PLAN / EXP / ANALYTICS / DEAD verdicts, the plan function's true
input list, and the conditionality that exists today. This file keeps
the five theses those facts establish. FACTS live in the two audit
files; the design answers live in `00_DIRECTION.md`.

## Thesis 1 — Gender is collected, explained, plan-live, and then ignored.

The gender beat (v6) names Mifflin-St Jeor and feeds the calorie sex
term (+166 kcal BMR male; nonbinary/private → female formula). That is
the entire effect. `ProgramGoalCalculator.compute()` accepts sex and
ignores it (documented TODO). **Zero copy conditionals exist on gender
anywhere in the funnel.** A male answer still routes through the
perimenopause question (options are exclusively cycle stages) and the
pregnancy/TTC/breastfeeding screen, then reads "her file, ready.",
"sign her in.", "JENI · HER PLAN", and buys under a chart axis that
says "her, {date}". The founder's own 08-01 walk (as "ben") crossed
every one of these. 22 female-specific sites are mapped with file:line.

## Thesis 2 — Four collected answers are dead; two consents gate nothing.

`appetiteReturn` (past branch) and `priorWin` have no reader anywhere;
`supports` is silent by FR8 design but renders nothing back to the
user who disclosed; `nsv` and `stopWindow` survive on one loader line
each. The signature card's two toggles (`onb_consent_personalize`,
`onb_consent_day2`) are read by nothing — consent theater, worse than
a dead question because it presents as control. The completion payload
carries ~10 vestigial legacy fields (constants; not user-facing).

## Thesis 3 — The clinical register exists as a pattern but is unevenly applied.

~14 copy lines carry a named source (Mifflin-St Jeor, ACSM ×3, NWCR ×4,
NEJM STEP-1 ×2, JAMA 2025, Hollis 2008, Morgan-1999-verbatim SCOFF
items) — concentrated in muscleMath / regainTruth / targetReframe /
pacePicker / projection / wall. Act I carries zero sources and zero
conditionality; the food-noise teach makes biology claims ("hunger
hormones") unsourced in all three variants; the pace picker asserts
"most chosen." with no data provenance; the 5-7% milestone cites
"clinical consensus" (vague tag for what is really the FDA/DPP
anchor); and the SCOFF instrument — a genuine validated screen — is
never named on screen, forfeiting earned credibility.

## Thesis 4 — Voice-law violations survive at the single most clinical moment.

Nine live hearts (♡) render in the safety-gate views
(OnboardingComponents.swift:822-836, 992) despite the 1.2.0
hearts-retired law; terminal headlines run twee ("gentle it is.",
"steady and fed."). One fabricated number ships: "fifty-two answers.
one plan." (hard-coded; real per-path answer counts differ). Residual
soft-register filler ("you're in the right place.", "your food story,
heard.", "no shame either way", "the kitchen") sits exactly where the
founder's brief points.

## Thesis 5 — The echo architecture is strong and extendable.

Loader tape (14 keys, live-only), causal receipts (engine-gated),
dataMirror, act receipts, herFile dossier, fear-resolution, paywall
closing line + plan band: the machinery for "this app actually
understands me" is built and provenance-honest. The gaps are wiring
(dead answers above, glp1Phase silent, gender unacknowledged for
nonbinary/private) — not architecture.

## Verdict counts (from data_flow.md)

PLAN-shaping asks: glp1Status · glp1Phase · shotDay · foodRelationship ·
movement · sleep · stress · gender · age · height · weight · goalWeight ·
weightTrend · goalDirection · medication · safetyGate (+ reveal:
pacePicker · nudge time · promise · healthKit). EXP: name · outcome ·
appetiteRhythm · stopWindow · eatingCadence · cuisine · dietary ·
identity · startedOver · fears ×3 · nsv (thin) · snapDemo. ANALYTICS:
attribution. DEAD: appetiteReturn · priorWin · supports (silent-by-law) ·
consentPersonalize · consentDay2 (as gates).
