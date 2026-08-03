# Onboarding v7 — THE CLINICAL GRADE PASS (direction + build law)

2026-08-02, same day as v6. Founder brief (verbatim intent, distilled):
**not a redesign** — design language, interaction model, IA, navigation,
animations, typography, aesthetic all stay. Make the onboarding + hard
paywall significantly more persuasive, more clinically credible, more
conversion-focused. The onboarding has two jobs: convince the user they
have a real problem; convince them Jeni is the best solution. Every
screen fights for its life. Sell outcomes, not features. The register
moves from "girly, soft, cute" to **scientific, straightforward,
confident, clinically credible** — not robotic, not hospital, not
corporate; calm, confident, concise, factual. Remove emotional filler
and decorative copy; every statistic explains itself; every claim is
supportable. **Conditionality becomes real**: gender selection must
actually matter (male users lose female-specific wording, physiology,
examples, illustrations, questions, assumptions); audit GLP-1 /
non-GLP-1 / prior attempts / beginner-vs-experienced conditionality.
**Only ask questions that influence the generated plan** — a question
that changes nothing is removed. Keep approximately the same overall
length and conversion architecture; increase the value delivered during
it. Paywall: preserve the structure, improve copy, credibility,
perceived value, outcome framing, scientific legitimacy; real social
proof or placeholders, never fabrication. Verify everything in the
simulator (all cohorts, recordings reviewed frame-by-frame, Dynamic
Type, Reduce Motion, VoiceOver, small devices). Document decisions,
commit at milestones, don't ask questions.

Read `01_RESEARCH.md` (four new evidence lanes; extends v6's digest)
and `02_AUDIT.md` (+ `audit/beat_inventory.md`, `audit/data_flow.md` —
the fact base with file:line for every claim) first. This doc decides.

## 1. What is LOCKED (inherited constitution)

- The OV5 machine (typed steps, pure router, canonical-key store,
  visited-stack back-nav), the 5-act structure, the interaction
  language (cross-off selects, rulers, strike-the-fear, receipts,
  hold rituals, snap demo), and the v4.5 data contract. Router
  CHANGES are allowed only as cohort/persona gates of the kind the
  machine was built for (the GLP-1 fork is the precedent) — never
  restructuring.
- v6's five design laws stand, esp. "warmth in voice, rigor in
  numbers — never traded" and "every number carries its provenance."
  v7 pushes the words further clinical WITHOUT breaking warmth
  (lane-3 law: concreteness IS the warmth).
- Palette, type stack, motion tokens, JeniMark/JKBorderBeam laws,
  lowercase + italic-punch mechanics, sticker-scatter law (welcome
  stays an earned moment), verb law, anti-shame law, no drug brand
  names, no first-party numeric weight-loss claims, live prices only,
  no fake urgency, no fabricated proof.
- The keep wall's fold anatomy + below-fold band order + honesty
  mechanics (billed-today, renewal+year, per-week subordinate,
  money-back, reclaim, sign-in door, downsell family) — v6 P5 as
  shipped. v7 touches WORDS and adds rows inside existing bands only.
- Founder-ledger outcomes from v6 stand: F1 sentiment-only pre-wall
  gate · F2 real-proof band dormant until verbatim ASC reviews ·
  F3 ATT mid-loader · F4 no trial arm · F8 no reviewer byline until a
  real RD/MD. Nothing in v7 reopens them.
- The v6 measurement contract (03_RELEASE funnel events) — untouched
  except the `onboarding_version` metadata bumps to `v7` so
  before/after reads directly in PostHog.

## 2. The four laws of v7

1. **The persona law.** One resolver (`OV5Store.persona`) with three
   values: `.her` (explicit "female" — keeps the her-register brand
   voice and female-physiology content), `.male` (female-specific
   wording/physiology/questions/illustrations removed; male ruler
   seeds; hormonal + pregnancy beats route around), `.neutral`
   (nonbinary / prefer-not-to-say / unset — second-person register,
   hormonal + pregnancy offered since they may apply, stated-default
   transparency on the calorie formula). Everything upstream of the
   gender beat is persona-neutral for everyone; everything downstream
   reads the resolver. No copy site may hard-code "her/she/women"
   about the user again — female register arrives only through the
   resolver.
2. **The consequence law.** Every question influences the plan or the
   experience in a way the user can SEE, or it is cut. Falsifiability
   test on every echo line: a different answer must produce a
   different line (Barnum guard). Silent plan-inputs get engine-true
   acknowledgments; dead questions get wired or removed; consents
   gate the thing they name.
3. **The evidence law.** Every claim is supportable: number + unit +
   basis; named real sources that resolve; validated instruments named
   on screen (the SCOFF gets its byline); vague tags ("clinical
   consensus") replaced by their real anchors; unsourced biology
   claims either earn a citation or are rewritten as self-evident
   description. The two existing citation-verified chips (NEJM STEP-1,
   JAMA 2025) set the form. Hedges stay ("an estimate, not a
   promise") — hedging is a measured credibility asset (Jensen 2008).
4. **The register law.** Clear beats charming (written tiebreaker).
   Warmth fires selectively after hard disclosures (weight,
   medication, fears) and never as wallpaper; zero wit on operational
   surfaces (safety gate, billing, errors). No controlling verbs
   (must / should / need to); gain-frame over loss-frame; active
   voice; no metaphors doing a fact's job; anthropomorphisms pruned
   ("the kitchen", "your care plan listens", "dose days shape
   themselves"). Hearts: zero, including the safety gate. Sell the
   end state where product-true ("a program with an end"), never
   uninstrumented outcomes.

## 3. Decision ledger

- **D1 — gender stays in Act III; Acts I-II go neutral for everyone.**
  Moving the ask earlier was weighed and rejected: the literature
  endorses identity-first/numbers-mid ordering, the ask belongs
  beside the math it feeds (its Mifflin-St Jeor line), and the Act
  I-II female lines ("women who've tried everything", "her food
  story") are register-flagged filler that should die for ALL users
  anyway. Act eyebrows become: "the arrival" · "your food story" ·
  "the numbers" · "the part nobody asks" (unchanged) · act V
  persona-split: "almost hers" (.her) / "almost yours" (else).
- **D2 — router gates.** `.male` skips `hormonal` (its floor input
  defaults empty → no peri floor: correct) and skips the pregnancy
  screen inside the safety gate (SCOFF runs for everyone; ED risk is
  not sex-specific). `.neutral` keeps both (may apply; both carry
  prefer-not options). Router unit tests cover all three personas ×
  four GLP-1 cohorts.
- **D3 — question dispositions** (from `audit/data_flow.md`):
  `priorWin` CUT (dead; its territory belongs to startedOver) —
  replaced in-slot by a new **proteinRule teach** for the three
  cohorts that never see muscleMath (general/past/considering), so
  the #1 plan number lands pre-taught and act length holds.
  `appetiteReturn` WIRED (loader tape line + dataMirror row + chat
  profile) — it is the emotional core question of the past branch.
  `supports` KEPT (FR8 clinic seam) + paid: herFile dossier row +
  loader line (fact echo, recommends nothing — honors FR8 intent).
  `nsv` WIRED into herFile row + paywall band-1 row (outcome-selling:
  her stated non-scale outcomes at the decision). `stopWindow` kept
  (4 live tape variants). `attribution` kept (business-critical
  analytics; the one legitimate non-experience consumer).
  `outcome` kept + wired into the projection sub (falsifiable echo).
  `glp1Phase` gains a just-started ack (engine-true: 0.3%/wk floor).
  `gender` gains a stated-default ack for nonbinary/private only
  ("we use the more conservative formula" — true).
- **D4 — consent toggles become real.** `onb_consent_day2` gains its
  reader: the day-0/day-2 engagement pushes gate on it (the row
  finally does what it says). `onb_consent_personalize` row rewords
  to the structurally-true consent it records; kept as a consent
  record beside the medical ack (not a fake feature gate).
- **D5 — safety gate ceremony.** All nine hearts out; terminal
  headlines re-registered calm-clinical (same variants, same
  routing, same access-for-all law, resources card untouched); the
  SCOFF names its instrument on screen ("the SCOFF screen ·
  morgan 1999, bmj" — true, citable, earned credibility); pregnancy
  beat gated per D2.
- **D6 — provenance repairs.** "fifty-two answers" → computed live
  answer count from the store; "most chosen." (pace picker) → a
  truthful basis ("the middle of the safe band"); "clinical
  consensus" tag on the 5-7% milestone → its real anchor ("fda
  benchmark · dpp"); food-noise biology glosses rewritten
  self-evident or sourced; fear-resolution's "clinically safe band"
  inherits the ACSM name.
- **D7 — the "becoming" conceit narrows to brand-structural uses**
  (tab name, identity beat) for all personas; decorative uses go
  outcome-factual ("your becoming, plotted" → "your next {N} weeks,
  plotted"; "keeping it off is its own becoming" → "…its own
  practice"; loader closer). The founder asked for clinical for
  everyone — this is not a persona split.
- **D8 — identity beat keeps its five keys** (consumers read the raw
  word: notifications, method ritual, herFile). `.her` keeps the
  photo grid; `.male`/`.neutral` render the same five words as
  typography cards (no female photography). Headline persona-split:
  "who is she, the one you're becoming?" (.her) / "which version of
  you is this for?" (else — same instrument, clinical frame).
- **D9 — ruler seeds by persona.** Male default seeds 178 cm / 88 kg
  (starting position only; the store writes nothing until she moves
  or confirms). Female/neutral keep 165/72.
- **D10 — paywall scope.** Persona swaps ("her, {date}" axis → "you,
  {date}"; "the women who keep it off" → "people who keep it off"
  for non-her — NWCR-true both ways). Band 1 gains the BEYOND THE
  SCALE row (her NSV picks). Band 2 gains the program-has-an-end row
  ("built to be outgrown — the plan runs ~{N} weeks, then teaches
  keeping." — product-true via plan.totalDays + the keeping chapter;
  the renewal line stays adjacent and unchanged). Tier microcopy
  sharpened ("just trying it? that's ok" → confident register). No
  structural, pricing, or mechanic changes.
- **D11 — no invented questions.** The founder's "increase value"
  mandate is served by teach/ack/echo density, never by new
  consumer-less asks (the data-provenance rule cuts both ways).
- **D12 — male path ships fully; nonbinary/private ship coherent.**
  The founder's brief names male explicitly; .neutral is the safe
  superset register so no user ever reads a wrong-physiology line.

## 4. Phases (each: 4-6 changes → ONE build → sim-verify + screenshots same turn → commit)

- **P0 — law fixes (no persona dependency).** Safety-gate hearts ×9
  out + terminal headline re-register (OnboardingComponents.swift);
  "fifty-two answers" → computed count (OV5ScreensClose.swift +
  OV5Store answeredCount); "most chosen." → truthful basis +
  "clinical consensus" → "fda benchmark · dpp" + fear-res ACSM name
  (OnboardingRevealView.swift, OV5FearResolution.swift). Unit-safe;
  keep-wall + walker untouched surfaces.
- **P1 — persona infrastructure.** `OV5Persona` resolver on OV5Store
  (reads the live gender key); router gates for hormonal + pregnancy
  (OV5Flow.swift, OnboardingRevealView safety-gate presentation);
  ruler seeds (D9); act-eyebrow persona plumbing (OV5Scaffold reads
  store); walker gains TEST_RUNNER_GENDER; router unit tests
  (OV5RouterTests) extended: 3 personas × 4 cohorts reachability +
  hormonal/pregnancy gating + no-dead-ends.
- **P2 — acts I-II register + persona.** Act I rewrite (antiShame
  mechanism line, credibility bridge neutral + sourced, outcome
  option register); Act II: glp1 ack polish, shotDay sub de-pastoral,
  foodNoise sourced/self-evident rewrite, preEat, snapDemo lines,
  dietary "kitchen" fix, priorWin CUT + proteinRule teach NEW
  (OV5ScreensFood/Arrival/StageA, OV5Flow router, walker).
- **P3 — acts III-IV-V register + persona + wiring.** numbersBridge,
  movement labels, stress question, weight ack review, targetReframe
  persona, careBridge "every woman" → persona, hormonal question
  register (+ its absence for .male), identity beat D8, dataMirror
  additions (appetiteReturn), startedOver, whyItCameBack persona +
  source rows, receipt polish, herFile persona + supports/nsv rows,
  signature persona + D4 consent wiring (notification gate), 
  holdToBuild count (if not P0).
- **P4 — reveal register + persona + echoes.** Loader tape (persona
  lines, appetiteReturn line, supports line, register polish),
  pace picker copy, projection (headline D7, outcome-echo sub,
  persona strip lines), firstWeek, reviewGate "other women" →
  persona, fear-resolution register, commitment, nudge ask copy.
- **P5 — the wall (D10).** Persona swaps, band rows, microcopy,
  closing lines. KeepWallUITests updated only if labels moved.
- **P6 — verification sweep.** Full unit suite; router tests; v5
  walker per cohort (generalWL, current, past) × persona legs
  (female default + NEW male leg); KeepWall + Downsell suites SOLO;
  Reduce Motion walk; Dynamic Type XXL; SE + Pro Max buckets;
  VoiceOver spot-check on new/changed beats; sim video → ffmpeg
  frame review of the money transitions; `onboarding_version` → v7.
- **P7 — documentation.** This doc's shipped record; STATE.md §-11;
  CLAUDE.md pointer; memory update; final report to the founder.

## 5. Success criteria (checkable)

1. **The ben walk is clean**: a male-persona walker run renders zero
   female-specific lines (grep the female map's 22 sites for persona
   guards + walker frame review).
2. **No dead questions**: every ask in `audit/data_flow.md` resolves
   PLAN / EXP-visible / ANALYTICS(attribution only) — zero DEAD.
3. **No naked claims**: the inventory's unsourced-claim families are
   eliminated (sourced, self-evident, or cut); zero hearts; zero
   fabricated numbers; every new echo passes the falsifiability test.
4. **Register**: the flagged filler lines are gone; question+reason
   on every sensitive ask; no controlling verbs.
5. **Green**: full unit suite + extended router tests; walker legs
   per cohort × persona; KeepWall 3/3; XXL/RM/SE/Pro Max clean;
   money transitions frame-verified.
6. **Measurement continuity**: identical event stream with
   `onboarding_version: v7`.
