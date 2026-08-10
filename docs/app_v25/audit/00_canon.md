# v25 AUDIT — 00 THE CANON (distilled 2026-08-10)

Sources: STATE.md · app_v24 law+evidence · app_v23 · app_v22 · app_v21 ·
design/00_JENI_DESIGN_LANGUAGE.md · app_v9 00_MISSION + 04_DESIGN ·
jeni_release · onboarding_v7 + v8 · app_v8 (00/03/10/11 + STATE §-8) ·
glp1_strategy_2026_06_16 · TODOS.md. Precedence: design law > older design
docs; era law (v24→v21) wins on its surfaces; v8 care docs win where they
speak; v9 mission laws L1-L7 stand under everything.

---

## 1. INVARIANT LAWS (survive every era)

### Product laws (docs/app_v9/00_MISSION.md)
- **L1 three-questions law**: every surface answers ≥1 of "am I changing? /
  why am I changing? / what should I do next?" — a surface answering none is a
  demotion candidate, ledgered, never silently cut.
- **L2 evolution law**: additive models + idempotent migrations; new modules as
  new enum cases in existing hosts; no schema rewrites; existing users feel
  evolution, not a new app (migration-moment pattern).
- **L3 honesty/provenance**: every number traces to a collected field; **no
  number is ever derived from a photo**; change language qualitative,
  floor-gated, states uncertainty; correlation stays observational
  (timing-never-causality); a rising trend never blamed on one food.
- **L4 body privacy**: scans on-device, local-first; cloud backup explicit
  opt-in **default OFF**; never in analytics/logs, never to AI services, never
  to a clinician (no consent scope exists, deliberately); silhouette first-
  class; sweep/purge/re-key ship same-commit as the store.
- **L5 passive law**: never ask her to type what iOS knows; every requested
  HealthKit read must have a rendered surface; background delivery; each new
  manual ask displaces an old one.
- **L6 register**: body surfaces speak clinical-calm — "Apple Health, not
  Instagram wellness"; anti-shame floors everywhere (trend-as-hero, no red
  states, no before/after shame grammar, "your record" framing).
- **L7 / 04_DESIGN — DESIGN 100×**: design quality is the bottleneck; ADA
  bar; remove>add; never generic; one unforgettable interaction beats one new
  feature; continuous sim verification. Superseded on visual FORM by the
  design law; the bar + verification duty stand.

### The design law (docs/design/00_JENI_DESIGN_LANGUAGE.md — canonical)
- **Ink on paper**. §1.1b **TWO INSTRUMENTS, ONE HAND** (v21): Home/Becoming/
  tools/details are INSTRUMENTS (visual-first; the page must make sense with
  every paragraph deleted); the consult + moments stay EDITORIAL (serif letter
  register). One voice, two surfaces.
- §1.2b shape carries meaning; **no collected target → no progress bar** (D2,
  invented denominator) — history or share-of-whole instead; **N shapes must
  be N questions**. One idea per screen · speak-then-wait · nothing appears,
  everything arrives · remove beats add · calm over clever.
- **Type**: exactly three families — JeniHeroSerif (Jeni's voice), DM Sans
  (the system), Fraunces (ornament); token ladder only, never raw
  `.system(size:)`; negative leading mandatory on serif; italic punch = 1-3
  composed words, never `*markers*` or whole-line `.italic()`.
- **Colour**: locked tokens; `bgPrimary` is THE ONLY page background; THE ROSE
  RAMP — one hue, three depths (blush rest · dusty fill · berry now):
  quantities fill rose, trajectories draw ink, selection is ink; depth =
  emphasis never judgment; bans stand — no red, no green, no colour-coded
  state, no colour carrying meaning alone; **clinical register exempt:
  medication surfaces stay unadorned ink**.
- **Motion**: JeniMotion vocabulary only; one `arrived` flag per screen;
  charts draw, numbers count (JeniCountingNumeral), bars land; transitions
  ranked (in-tree morph into detented sheet > in-place crossfade > staged
  arrival > JeniMoment > push); default SwiftUI transitions banned; Canvas
  self-drives from `.task`; celebration rationed to one burst per flow.
- **Interaction**: tap acknowledged ≤100ms; ONE primary action (one ink pill)
  per screen; single-select commits itself; selection is a morph; **every
  answer gets echoed** (consequence law); errors absorbed by the surface,
  never alerts; destructive actions get a hold, not a dialog.
- **Haptics**: three words — tick / land / swell (one swell per flow); one
  interaction one response; never passive; rate-limited.
- **A11y (non-negotiable)**: real labels matching visible text; Dynamic Type
  via relativeTo, nothing clips at XXXL; Reduce Motion removes motion never
  information; 4.5:1 / 3:1 contrast; 44pt targets; VoiceOver reading order;
  charts carry accessibilityText; never meaning on colour alone; stable
  accessibilityIdentifiers for QA legs.
- **Copy**: two registers — B2C (plain, friendly, confident, lightly gen-z)
  and B2B (clinical, evidence-oriented, zero personality); lowercase; no
  em-dash between words; **never the word "AI"**; no hearts/emoji; direct
  verbs ("sugar intake" never "sweetness"; add / mark / weigh in); no
  controlling verbs (must/should/need to); gain-frame ("room left", never
  "over budget"); sentences not aphorisms; **evidence law**: number + unit +
  named source from the vetted set only (NEJM STEP-1 · JAMA 2025 · Hayashi
  2023 · Wycherley 2012 · ACSM 0.5-1%/wk · Morgan 1999 SCOFF · FDA/DPP 5-7%);
  hedges are assets ("an estimate, not a promise").
- **§12 never-do**: no default transitions; no push-to-change-content; no
  second primary button; no border+shadow+fill; no state colours; no stock
  photos/generic icon sets (THE DOODLE SET is the icon register; medication
  keeps its unadorned SF glyph); no raw sizes; no alerts; no takeover headline
  in a scroll; no number without provenance; no question whose answer changes
  nothing; no passive haptics; never break the gutter; nothing unlabelled.
- **§13**: target iOS 17 — Liquid Glass availability-gated,
  `.ultraThinMaterial` floor; glass on chrome only, banned on content.
- **§16 THE PAYWALL IS EXEMPT** from design migration (founder directive);
  its KeepWall legs are the regression gate.
- **§15 THE LOOP** is the verification law: build → install → drive (XCUI) →
  record → dump frames → inspect → fix → repeat. "Would Apple ship this?"

### Brand (docs/jeni_release/00_JENI_RELEASE.md)
- The hand-drawn **j mark**: one colour — ink↔ceramic, **never rose**, never
  rotated/mirrored/outlined/redrawn; one canonical JeniMark/JeniWordmark.
- Warm paper + ink palette; launch == bgPrimary (one continuous surface).
- **Voice pass**: hearts retired app-wide (zero; chat normalizer strips
  streamed hearts); cheer clauses cut; ornament slots → dose-dot or ink mark;
  affirmations speak product truths; the letter signs "— jeni".
- **JKBorderBeam law**: earned/premium only, NEVER medication/clinical, one
  region per screen, ≤0.5 peak.
- Identifiers stay legacy on purpose (bundle id, jenifit://, RC ids); rename
  founder-gated.

### Onboarding law (onboarding_v7 + v8)
- v7's four laws bind v8: **persona** (routing-only: male skips hormonal +
  pregnancy; SCOFF for everyone), **consequence** (every ask changes something
  visible or dies; falsifiable echoes, Barnum guard), **evidence**,
  **register** (clear beats charming; zero wit on safety/billing).
- v8 THE CONSULT: universal register (never feminine/masculine); conversation
  grammar (typewriter, transcript, acks, ink chapters, drawn evidence);
  **THE DOOR** — clinic patients enter a clinician code up front and walk a
  clinical intake with ZERO conversion beats; B2C hard wall; care-entitled
  patients pass it (`hasCareEntitlement` AppPhase input, re-verified every
  sync; revocation re-walls).
- The quiz is exactly three illustrated screens (test-pinned); cohort ask is
  one screen per branch — EXCEPT current-GLP-1, superseded by v24's four
  medication beats (ledgered, current cohort ONLY). Store contract byte-stable
  (OV5Store keys, v4.5 completion pipeline, funnel events).
- No fabricated proof ever: real-proof band dormant until verbatim ASC
  reviews (F2); no reviewer byline until a real RD/MD (F8); live RevenueCat
  prices only (3.1.2(a)); no fake urgency.

### Care platform invariants (docs/app_v8/ S4 §1 + S5)
- **Clinician AUTHORS care; patient LIVES care; Jeni ORGANIZES care.** ONE
  canonical record system — clinic access is grants over the SAME rows the
  consumer app writes, never a parallel chart.
- Patient can never mutate a care-team regimen (server-enforced); clinician
  can never rewrite patient observations or relabel provenance. **Access ≠
  treatment**: revocation prospective, access-only (164.508(b)(5)).
- Clinician reads of patient data are SECURITY DEFINER **RPC-only** (the
  disclosure-audit chokepoint); F1 masking (self-reported regimens read "your
  weekly medication" to the clinic) is a server projection.
- Consent: explicit, scoped (visit_packet_view / observation_view /
  care_assignment), lookback-bounded, revocable, audited; inactive default.
- Role law: explicit `clinical_authority` (clinicians auto; owners only if
  marked; staff never) gates all seven clinical actions. Corrections are
  164.526-shaped (request, never mutate).
- **Not an EHR, not e-prescribing**; copy never says prescribe / Rx /
  "monitored in real time". Nothing sensitive on lock screens or analytics —
  no medication names, strengths, weights, symptom words.
- Env law: dev = consumer-prod; pilot = fresh project, founder-gated;
  **internal dev alpha, test data only, NO BAA — never "HIPAA compliant"**;
  no AI in the clinic loop. Consumer = the org-null default tenant; a clinic
  arrives by filling fields, not migrating schemas.

### The module contract (docs/app_v22/00_ONE_HAND.md)
- Every capability is a MODULE with the same faces (preview / expanded /
  detail / history / empty / loading / error / celebration / weekly read).
  **Composition, not forks**: the UI never knows who authored a task; B2B
  enters through the same beats via the protocol/care-layer registry.
- The 5-question consistency gate before any screen ships; **E2 honest
  theater** — never simulate understanding we don't have (provenance law
  extends to animation).

### Medication law (docs/app_v24/00_REGIMEN.md D1-D10 + v8 FR laws)
- Medication is a rhythm inside her day, **never a tab/dashboard**
  (permanent). Clinical register (v8 FR2) on every medication surface; the
  timestamp is the only reward; warmth lives around the row, not on it.
- **Supersede, never mutate**: catalog is code; regimens are append-only
  VERSION CHAINS through the `applySelfRegimen` chokepoint; dose events
  append-only with deterministic per-slot ids (all surfaces converge); side
  effects are observations. Nothing user-entered is ever overwritten.
- iOS writes `authority=self` ONLY; care_team regimens mutation-guarded; dose
  events stamp the regimen version in force.
- **Observed, never prescribed**: reminds of HER schedule, reflects
  label-level guidance plainly; never advises doses or computes catch-up;
  missed is derived, reversible, gentle ("log it late, or let it go");
  rotation suggests never insists; patterns speak timing never causality,
  floor-gated ≥3; escape hatches everywhere; oral has zero injection
  vocabulary; no lock-screen skip.
- Names render only on surfaces SHE reads (product function); **never in
  notification payloads, never in analytics**; analytics categorical only.

### Engines + data (standing)
- Signals law (v6): observed-never-prescribed; **"fasting" never renders**;
  no timers/targets/streaks on observed windows.
- Program: NEVER hardcode 75 — read `plan.totalDays`; ACSM pacing + cohort
  floors (GLP-1/peri 0.3%/wk); TargetsService + CohortStore are the single
  numeric truths; engagement day derived, never stored.
- Sync: anonymous-first auth; all entity reads `@Query userId`; sign-out
  sweeps user-scoped AppStorage + cancels retention pushes; additive
  migrations only; sync 404s gracefully local-first until SQL applied.
- Notifications: day-2 consent gates the first-days family; surgical
  pending-removal; weekly ceiling, replace-never-stack; cohort-aware; voice =
  identity/hope + her-own-data, no scale words or streak threats; medication
  reminders survive breaks and never name the medication.
- GLP-1 strategy: **convergence, not pivot** — cohort signal in the noun
  phrase, never in feature promises; bodies reference only shipping features;
  every promise cashable in ≤3 sessions.
- Dead-code law: superseded code + orphans die in the same change; grep TYPES
  not filenames before deleting.

---

## 2. CURRENT PER-SURFACE STATE (post-v24)

- **Home/Today** (v21 law): one-line header (greeting · day chip · gear) →
  calendar strip (first-class selector, disc morph, page re-keys) → THE HERO
  CAROUSEL (five morphing faces: 176pt calorie ring w/ counted numeral inside
  · protein vs floor · plate split · chemistry weeks · week bars) → checklist
  of `JeniTaskRow` OBJECTS (blush chips, real plate photo on the food row,
  clinical rows ink; completion compresses to a receipt) → TOOLS two-across
  `JeniToolTile` with live instruments → evening close as a list row. HOME'S
  LAW: nutrition + list + tools render at EVERY hour; states change content,
  never anatomy. v24: dose day composes the clinical row as lead; daily med
  cadence rides as first support OUTSIDE the ≤3 cap.
- **Becoming** (v21): masthead → scope bar as header (morph, never reload) →
  THE BODY CARD hero (weight numeral over 56pt ink trajectory) → insight
  carousel (R6 grammar, floor-gated) → 2-col LABEL·VALUE·SHAPE grid → rows
  for metrics without a read → body progress + care doors; detail sheets =
  v19 in-tree morph + five-breath staged reveal; care-connected patients read
  YOUR CARE first (C8). v24 added the medication tile (compact, never a lead,
  absent without a regimen: dose value, tally strip, adherence read, pattern
  observations, THE DOSE ERAS ledger).
- **Chat (Jeni)**: two voices — serif letter + rose marginalia; bare hairline
  composer; local-first transcript; SSE EF `jeni-chat` (server-side key,
  per-user + budget caps); provenance-only CoachContext per turn; crisis/ED
  routes to fixed care responses locally; normalizer strips hearts. v24:
  envelope gains medication{} (compound never brand, dose-day/day-after
  flags, recent symptoms) + EF timing-empathy rule (deploy pending). A
  spacing/composer audit is still queued (design law §16).
- **Food (v23 THE STILL LIFE)**: THE WINDOW (full-bleed camera, glass chrome)
  with THE DIAL (morphing bracket aim; the reading closes the frame, honest
  hold at 96%); modes scan · barcode (live VN + OpenFoodFacts by code) ·
  label (EF text-hint, zero deploy); THE UNDERSTANDING (real result chips
  land on the photo — honest theater); THE READING is ONE page (carousel
  dead: context · serif name · counted kcal ± band · protein floor card ·
  split · hairline ledger · editable items · fraction · WHAT JENI NOTICED ·
  "add it"; no scores ever); THE BOOK (day spreads, photos lead, month +
  FoodWeekRead seams, "again" lives here). Engines untouched (vision EF,
  PlateEditSession, JSONL+payload ledger, Live Activity). PlankFoodTests run
  via the PACKAGE scheme only.
- **Medication (v24 THE REGIMEN)**: MedicationCatalog (9 products, code-
  versioned; new med = one entry) → regimen version chains → DoseEventRecord
  → symptom observations. Engines: schedule (wall clock, DST-safe, weekly
  late window = until next dose), rotation, patterns, reminder planner (the
  app's FIRST actionable category: taken / in an hour / log later). THE DOSE
  SHEET (facts eyebrow, pre-selected site cells, ink mark, skip reasons, late
  + oral faces). THE REGIMEN home in settings (facts as doors, THE RECORD
  eras, pause/stop, later-enable wizard, side-effect logger). Four consult
  beats (current cohort; clinic door skips all). Gates: 20260809 migration ·
  jeni-chat EF deploy · device walk.
- **Body scan**: guided REAR-camera capture, fixed-aperture WINDOW; WaistCrop
  (waist only, EXIF-normalized) + BandProfile (width → WORDS, 3% noise floor,
  fuller weeks never scolded); on-device silhouettes; local-first store; D3
  opt-in backup default OFF; THE COMPARE one-drag scrub. v22's queued motion
  pass never ran.
- **Method/lessons**: 42-lesson CBT manifest; v22 verdict — the content
  deserves to exist, the article format does not; ONE IDEA ONE ACT card
  grammar is the binding design (eyebrow → serif claim → drawn figure → one
  action row → citation; trigger-matched delivery). DESIGN BOUND, BUILD
  QUEUED (trigger engine founder-gated).
- **Breathwork**: generative breath field + CoreHaptics envelopes, no
  numerals; science-honest primer (cortisol mechanism, NEVER fat-burn).
- **Workout/sessions**: plank-rotation engine (ACSM-grade, tested);
  completion = kept receipt (stars dead). v22 audit: **the workout cover is
  another app** (her75-era pink script + stickers) — the largest drift,
  queued for rebuild on the module contract.
- **Steps**: HealthKit, 7,500 anchor; Home mini-ring + Becoming tile; the
  model for health rails. **Sleep**: passive HealthKit; forgiveness bands;
  Becoming tile; short sleep feeds tone + appetite acks.
- **Notifications**: trial anchors + `daily_reminder` (surgical removal);
  cohort variants; day-2 consent gate; v24 medication category actionable;
  deep-links queue until `.main`. Full orchestrator consolidation spec'd
  (app_v2/09) but never built.
- **Settings**: migrated 2026-08-06 (DM Sans, quiet ink glyphs); "your
  medication" door → THE REGIMEN; care-team door; body-backup doors.
- **Onboarding**: v8 THE CONSULT live (conversation, ink/paper flips, drawn
  evidence, THE DOOR with live code validation, clinical intake with zero
  conversion beats, three-screen quiz, oath commitment, named HealthKit ask);
  v24 added the medication beats; `onboarding_version: v8`; v5 mounted behind
  `--onboarding-v5` pending deletion sweep.
- **Paywall**: THE KEEP WALL — no-trial pay-upfront (yearly badged +
  quarterly + weekly), billed-today everywhere, earned-trust bands, dormant
  real-proof + reviewer slots, tier-matched downsells, reclaim row; live
  localized prices only; design-migration EXEMPT; clinic patients bypass via
  care entitlement.
- **Auth/Sync**: anonymous-first Supabase, Apple + email upgrade, recovery,
  delete-account + anti-enumeration; `@Query userId` isolation; typed
  Codable upserts; UUID case normalized; PaymentService re-configures on user
  change; restore() respects paid users.
- **Care platform (v8, S1-S5 shipped, live on dev)**: CareProtocol served
  from rows (whole-or-reject gate, bundled fallback) → ObservationStore chart
  → S3 visit-prep packet (deterministic, no AI, consent-gated share) → S4
  clinic loop (orgs · members · peppered single-use invitations ·
  relationships · consent scopes + lookback · protocol assignments ·
  corrections · append-only audit; `clinic/` dashboard, RLS + RPC-only) → S5
  pilot-ready (Jeni Health › Jeni Care › Jeni; env guards; clinical_authority;
  demo tenant; ops set; site). Patient side: FR2 reconciliation, read-only
  care-team face + correction door, "your care team" settings door. Internal
  alpha; real clinic gates on BAA + counsel + insurance.

---

## 3. DEFERRED / TRADEOFF LEDGER (gold for the next plan)

### v24 tradeoffs (law §11, decided) + queue (§13, evidence)
- **No pharmacokinetic "medication level" curve** — fails data-provenance
  (modeled mg-in-body is not collected); the dose-era read answers "is it
  working" from HER data. Revisit = founder call only.
- No cravings-day onboarding question — the coach earns it later from data
  ("your hardest day looks like Friday — want to move your shot?", pattern-
  engine, opt-in, floors met). Designed, unbuilt.
- No lock-screen "skip" (accident magnet); no site photo (medical-record
  drift + body-privacy); no pain slider; side effects are chips (3
  severities), never 0-10 sliders.
- Era LEDGER over the annotated dose-era weight CURVE in v1 — the JeniChart
  era-seam overlay is queued as its own chart pass.
- Considering/about-to-start cohorts ship ZERO config beats (settings
  later-enable door is the path; §7 sketch stands as design).
- B2B "add something your clinic hasn't set" — designed in §6, BLOCKED by the
  one-medication-truth invariant; needs its own care-loop pass.
- Also queued: per-symptom notes sync (device-local payload only); widgets
  (no infrastructure app-wide — its own era); served catalog overrides;
  clinician comments surface (S4-deferred messaging); chip→row flash + XXXL
  floors on the three new sheets; device walk.

### v23 queued (01_EVIDENCE deferrals)
- Chip→row flash on the reading; plate page as the reading in read mode; the
  filing choreography; device walk for barcode/label + live feed; XXXL floors
  on the three food surfaces; carousel leg re-anchor; dial tune on device.

### v22 queued (law §3/§6/§7 — the propagation map, unbuilt)
- Body scan motion pass; moments/chat/settings sweeps; **THE METHOD card
  slice** (§4 binding: ONE IDEA ONE ACT + trigger engine, founder-gated);
  **B2B composition registry surfacing**; **the workout cover rebuild** (the
  audit's largest drift).

### Design-law §16 still-to-migrate
- Chat audit · body-scan motion · medication/supplements/history/clinician
  small surfaces · **B2B Home variant** (care-first priority order — same
  language, NOT STARTED) · residual in-app poetry sweep.

### Older era queues never closed
- Widgets (JenifitWidgets target + jenifit:// ready); notification
  orchestrator consolidation (spec'd app_v2/09, unbuilt); evening close
  re-skin; sheet material pass; Lovi-style scan chooser (v11 cycle N).
- Onboarding v8 deferrals: reveal + keep-wall re-dress into the consult
  grammar; RM/XXL/SE walks for v8; v5 deletion sweep once metrics hold; ATT
  stays mid-loader (F3); F4 trial experiment (hard wall vs 7-day on yearly)
  parked until funnel gates mature.

### v8 care platform held / S4-deferred (04_DECISIONS, 10_S4 §15/§29)
- E-prescribing/pharmacy, billing minutes ledger, drafts-pending-signature,
  FormTemplate intake, clinic BrandVoice re-voicing, clinician push,
  patient↔clinician messaging, multi-clinic-per-patient, protocol composer,
  population analytics, cookie sessions, org self-serve, SSO/SCIM/seats.
- Supplements UI line deliberately not built; dose-day brief softening;
  sit↔shot-week correlation lines.
- Real-pilot gates: pilot Supabase project, BAA chain, counsel legal, cyber
  insurance, risk analysis, site exposure, trademark clearance.

### GLP-1 strategy roadmap (2026-06-16 — partially overtaken)
- Now SHIPPED by later eras: protein floor, dose tracker, side-effect log,
  site rotation (v24), food-noise vocabulary. Still open: 12-week keep-it-off
  curriculum (post-GLP-1 wedge), "we're not Calibrate" non-Rx trust strip,
  30-day "first month off" milestone, sister-cohort SKU (10x LTV bet),
  cohort-aware lesson sequencing, food-noise/hunger-return daily tracker,
  cycle-aware program, correction-flywheel scanner moat.

### TODOS.md (stale — last updated 2026-07-07; verify before acting)
- Bundle ID + project + SKU (`absmaxxing_*` → `jenifit_*`) + trial-end
  notification identifier renames — one coordinated founder-gated cutover.
  ElevenLabs clip generation (**key rotation FIRST** — key live in git
  history per the v1.1.7 audit).
- Snap manual retry + photo cache; server-side cross-device trial-end push;
  OnboardingData weight fields → optional; RC anon→auth identity merge;
  voice-clip orphans → ODR. Many v4-era items reference retired surfaces —
  triage against the current tree.

### Standing founder gates (open now)
- v24: apply `20260809090000_v24_medication_platform.sql`; deploy jeni-chat
  EF; device walk (lock-screen actions, real timezone crossing, dose sheet
  in-hand); review §11 tradeoffs.
- v1.1.7: TestFlight-ready; App Store behind 10 founder gates.
- iOS 26 target-raise decision (Liquid Glass, design law §13).

---

## 4. COMPLIANCE + SAFETY FLOORS (consolidated)

- **No drug brand names on app-controlled surfaces** (Apple 5.2.1): never in
  name/subtitle/keywords/screenshots/creative/push/paywall/coach voice.
  Safe: "GLP-1", "the shot", "the medication". v24 nuance (ledgered): brand
  names render in-app as PRODUCT FUNCTION (her picker, dose sheet, regimen
  home), never as marketing, **never in notifications or analytics**.
- **No drug-equivalence claims** (FTC NextMed precedent); no guaranteed/
  miracle/easy. **No "GLP-1 alternative" / "natural Ozempic"**; never frame
  the app as medication substitution (FDA Feb 2026).
- **No first-party numeric weight-loss claims**; third-party cited stats OK
  when accurate; every claim number + unit + named source (vetted set only).
- **Never "HIPAA compliant"** (internal alpha, no BAA); no AI in the clinic
  loop; no health data in analytics/logs; not an EHR; never prescribe / Rx /
  "monitored in real time".
- **Observed-never-prescribed**: no dose advice, no catch-up computation, no
  fasting vocabulary, no timers/targets/streaks on observed windows; SaMD
  line — educate/track/behavioral, never diagnose/dose/interpret labs.
- **Body privacy**: never a number from a photo; BF% via provenance ladder
  only; scans local-first, backup default OFF, never to AI or clinicians.
- **Anti-shame**: no red bars, no "over budget", no earned-food grammar, no
  streak threats; fuller weeks never scolded; numeric suppression honored
  under the safety gate.
- **Analytics hygiene**: counts/choices/categoricals only — never doses,
  symptom notes, sites, weights, medication names; internal testers excluded.
- **Marketing/ads**: no before/after body imagery; no AI faces/hands; no body
  imagery in lock-screen copy; voice bans (labor verbs, scale words in push,
  ALL CAPS, accusation questions, "AI coach").
- **Payments**: live localized prices only (3.1.2(a)); billed-today first;
  pending ≠ failure; no fake urgency; no fabricated proof/reviews ever.
- **Safety gate**: SCOFF (named, Morgan 1999) + pregnancy + BMI floor
  pre-paywall for all; crisis/ED chat → fixed care responses; day-2 consent
  gates the push family.

---

## 5. TENSIONS (honest flags for v25)

1. **Paper token drift.** CLAUDE.md + jeni_release fix paper at `#FCFAF7`;
   design law §3 (v20) steps bgPrimary to `#F5F3EF` for card separation.
   `Tokens.swift` is the declared truth — v25 docs should point at the token,
   not restate hex.
2. **"One adaptive system" vs the chokepoint architecture.** The canon has
   one composition chokepoint per domain (CarePlanEngine for the day,
   applySelfRegimen for medication, CareProtocol for constants). An adaptive
   layer must read/write THROUGH these or it forks authority — what the
   module contract (v22 §2) and S1 "protocol as data" exist to prevent.
   Adaptive should be protocol-shaped data feeding the existing engines, not
   a new engine beside them.
3. **Adaptive vs observed-never-prescribed.** Uninvited plan changes collide
   with consented-change-only (v4 re-signing: ≤1 change/week from a closed
   safe set), suggests-never-insists, and timing-never-causality. The canon's
   shape for adaptation is OFFER + CONSENT, floor-gated, provenance-stamped —
   not silent self-tuning. v25 should name its consent surface early.
4. **Clinic-connected mode vs HOME'S LAW.** The sanctioned-but-unbuilt B2B
   Home variant wants a different priority order; HOME'S LAW fixes anatomy at
   every hour and v22 forbids UI forks. The implied reconciliation: same
   anatomy, different COMPOSITION (care leads promoted inside the same blocks
   — the C8/dose-day precedent). Re-architecting Home breaks two laws.
5. **Authority hierarchy vs server law.** A v25 authority ladder already
   half-exists as SERVER law (iOS writes authority=self only;
   clinical_authority gates; RPC-only access; one-medication-truth blocks a
   self plan beside a care plan). A client-side model would duplicate then
   contradict it. The v24 §6 B2B "add alongside" door is designed but blocked
   by the invariant — resolve deliberately.
6. **Two entitlement sources.** RevenueCat pro vs live care connection bit
   once — MainShell's guard read only RevenueCat and rendered a void under a
   correct `.main` (onboarding_v8 §11 CLOSED). Every new gate must mirror the
   phase machine's three inputs (pro · care · auth transition).
7. **Reminders vs BreakState.** v3: a break pauses ALL uninvited pushes; v24:
   medication reminders SURVIVE breaks ("medical rhythm ≠ engagement"). A
   deliberate carve-out — the unified notification orchestrator (unbuilt)
   must encode two opposite break behaviors explicitly.
8. **GLP-1 strategy doc is partially stale.** Its "does NOT exist — never
   mention" list (protein floor, dose tracker, side-effect log, rotation) now
   ships via v24; its sample copy carries retired hearts. Compliance floors
   remain binding; the feature inventory needs a v25 refresh.
9. **Onboarding question budget.** v8's ledger: one cohort question, depth
   post-purchase; v24 superseded it for the CURRENT cohort only. A v25 intake
   adding beats for other cohorts re-opens a decided ledger item — do it as a
   ledgered supersession or not at all.
10. **Two registers vs one system.** The instrument/editorial split (§1.1b)
    plus the clinical-register exemption (medication = ink, no rose) mean v25
    can unify ARCHITECTURE but must preserve three visual registers
    (instrument / editorial / clinical). One theme everywhere would violate
    the design law it claims to implement.
11. **Doc hygiene.** STATE.md's lower half is self-declared history yet still
    carries superseded guidance (e.g. "hearts as terminal punctuation" in its
    §4); TODOS.md predates five eras. Re-baseline both.
