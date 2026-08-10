# v25 THE SYSTEM — working ledger

era opened 2026-08-10 · branch `feat/app-v2` · this file is the
era's memory across sessions and context compaction. update as work
lands. `BRIEF.md` is the founder's directive verbatim — when in
doubt, re-read it, not this summary.

## the era in one breath

PRODUCT ARCHITECTURE era. deliverable = `00_THE_SYSTEM.md`, the
canonical spec for the next several eras. jeni becomes ONE adaptive
weight-loss system with two modes — CONSUMER and CLINIC-CONNECTED —
same app, same jeni; the difference is AUTHORITY
(clinician-prescribed › jeni-recommended › user-preferred, never
silently overwriting). thesis: answer "what should i do today to
lose weight safely and sustainably?" better as jeni learns. every
signal feeds ONE adaptive program, not ten dashboards. today =
action · jeni = understanding · becoming = evidence · clinician
dashboard = configurable care. optimize VALUE / USER EFFORT.
research first; challenge founder hypotheses; permission to kill
features (the method is NOT sacred; workouts questionable;
breathwork must earn existence; sleep only if actionable).

## deliverables

- [x] era scaffolding (BRIEF.md verbatim + this ledger) — committed
- [ ] ground truth: audit/00_canon.md (docs distillation, agent)
- [ ] ground truth: audit/01_app_reality.md (code reality, agent)
- [ ] ground truth: audit/02_clinician_web.md (jeni-health-web, agent)
- [ ] ground truth: audit/03_walk_notes.md (recorded sim walk, agent)
- [ ] research/r1_glp1_companions.md … r6_retention_notifications.md (6 agents)
- [ ] 02_AUDIT.md — jeni-as-a-system audit (the brief's 10 questions
      per feature; verdicts keep / improve / rebuild / remove)
- [ ] 00_THE_SYSTEM.md — the master plan, 15 sections per BRIEF.md,
      with the scored prioritization (user value · frequency ·
      retention · WL relevance · B2C · B2B · differentiation ·
      evidence · complexity · clinical risk)
- [ ] walk the product AGAIN vs THE SYSTEM → 03_GAP_MAP.md (ranked)
- [ ] 04_FIRST_ERA.md — detailed brief for the single
      highest-leverage implementation era. then STOP.
- [ ] founder presentation: WHAT JENI BECOMES / KEEP / KILL / BUILD /
      WHY / THE ERAS / FIRST ERA / biggest research insight

## research fan-out (launched 2026-08-10)

ten background agents, each writes its file + returns a summary:
canon docs · app code reality · clinician web · sim walk (QA sim
259952D4, film doors, frames in session scratchpad) · r1 GLP-1
companions+communities · r2 food logging/AI accuracy · r3 behavior
change/content · r4 movement/steps/sleep evidence · r5 clinician
workflows/RPM/regulatory · r6 retention/notifications/JITAI/iOS
surfaces. reports land under docs/app_v25/{audit,research}/ —
commit them as they arrive.

## founder hypotheses under test (from BRIEF.md — verify, don't assume)

- jeni chat → the intelligence layer over longitudinal data
  (tools + structured data, never invented answers); decide what
  belongs in conversation vs proactive insight vs today vs becoming
  vs notification.
- food = flagship loop; accuracy > theater; journal must create
  downstream value without nutrition policing.
- v24 regimen: audit, don't rebuild; find genuine gaps only.
- steps: today can create a walking action ("2,100 steps left"
  concept); research best representation (steps vs minutes) +
  evidence-informed ADAPTIVE default (not 10,000); user override.
- sleep: minimal surface unless it changes a decision.
- notifications: ONE product system with an intelligence model —
  every send answers why now / why this user / why is opening jeni
  valuable now. volume constrained; understandable controls.
- adaptive program: one central system, longitudinal signals →
  1–3 meaningful daily actions, never a 14-item checklist; knows
  known vs inferred vs prescribed vs recommended vs user-changed.
- clinician-tuned jeni: structured controls (philosophy, priorities,
  instructions, escalation, tone, prohibited advice, templates) —
  NOT a raw prompt box, unless research says otherwise.
- clinician dashboard: designed around "what deserves attention",
  exception-first, reduces clinical work; excellent defaults —
  an unconfigured clinic patient still has a complete product.
- retention: healthy loops only (snap→understand→act ·
  dose→observe→pattern · week→review→adapt · ask→understand→act ·
  clinician plan→action→evidence→clinician); no dark patterns.

## standing constraints (do not re-derive)

- design law `docs/design/00_JENI_DESIGN_LANGUAGE.md` governs every
  surface; paper+ink; every new surface unmistakably jeni.
- safety floors: data provenance (no fabricated numbers, no PK
  curves), body privacy, observed-never-prescribed, no drug brand
  names in marketing surfaces, no numeric weight-loss claims, never
  "HIPAA compliant" (no BAA), no AI in the clinic loop today,
  timing-never-causality for patterns.
- care platform (v8) is the b2b substrate: org-null tenant,
  RPC-only clinician access, consent scopes + lookback, authority
  self|care_team on regimen, CareProtocol served config,
  07_CLINIC_MIRROR configure-vocabulary + alert-budget law.
- keep the module contract (v22): B2C/B2B by composition, never UI
  forks.

## status

- 2026-08-10: era opened. scaffolding committed. 10 agents running.
  STATE.md read (v24→v6 sections). next: synthesize agent reports as
  they land → 02_AUDIT.md → 00_THE_SYSTEM.md.
- audit/02_clinician_web.md LANDED. **premise correction:**
  /Users/bko/jeni-health-web = the undeployed B2B MARKETING site
  (next.js, waitlist POST only, no supabase). the real clinician
  product is `plankAI/clinic/` — the jeni care dashboard (vite+react,
  ~1,900 LoC, untouched since v9-P6). the S4/S5 loop still WORKS
  end-to-end on dev incl. v24 regimen writes (CareReconciliation →
  RegimenPlanRecord). nothing clinician-facing is deployed anywhere.
  top gaps: no triage/worklist, no silence detection or messaging,
  no titration ladders/oral regimens clinic-side, no charts/notes/
  export, no BAA rail.
- research/r3_behavior_content.md LANDED. lesson libraries are
  evidence-dead (noom's own 11k-user analysis: articles-read among
  weakest outcome predictors; pull-based homework dies by month 2).
  what works: weekly review ritual (PROVEN — templated feedback BEAT
  counselor-crafted), moment-attached cards/JITAI (promising),
  self-monitoring IS the intervention. GLP-1 content has only two
  proven pillars: protein 1.2–2.0 g/kg + resistance 2–3×/wk.
  mindful eating helps emotional eating NOT weight; MI keep the
  voice not the sessions; regain ~2/3 within a yr off-med and
  generic behavioral support does NOT slow it. verdict: method dies
  as a library → trigger-tagged atoms through existing surfaces +
  ONE weekly review ritual + ≤5 moment-tools shelf. do-not-build:
  lessons tab w/ completion %, content streaks/XP, lesson video, MI
  chatbot, psych quizzes, daily-weighing prompts.
- research/r4_movement_sleep.md LANDED. adaptive step goals =
  the domain's strongest behavioral finding (60th percentile of own
  last 9-10 days beat static 10k by ~+1,000/day, 58% vs 22%
  attainment; goals must breathe DOWN after bad weeks). 10k = 1965
  pedometer slogan. benefits steepest 2k→7k. post-meal walk PROVEN
  for glucose even at 2-10 min — and uniquely jeni's (the food log
  is the trigger no fitness app has). GLP-1: 25-40% of loss is lean
  mass AND users' steps DROP after starting (5,047→4,487, ENDO
  2026) → the one movement build = 2×/wk minimal-dose strength
  floor for the medicated (single hard sets proven) + protein.
  sleep: restriction +204-385 kcal/day intake, extension −270
  (tasali RCT); regularity beats duration; phone-only = timing/
  duration only → sleep is a pattern input + bedtime-consistency
  nudge, never a dashboard/score. gentler streak proves the gentle
  register retains; apple's unbroken-chain rings HARM. founder
  hypotheses confirmed: "2,100 steps left" today action (adaptive),
  sleep minimal, generic workouts die. do-not-build: NTC-lite,
  10k defaults, kcal-from-active-energy (28% device error), sleep
  scores/stages, hourly stand nags, step rewards, hard streaks.
- research/r6_retention_notifications.md LANDED. category D30 is
  ~3-4%; weight apps die of logging fatigue in days 1-14 (jeni's
  exact W1→W2 collapse window) + tracking burnout wks 8-12. all
  top-decile loops are RITUALS not content: oura morning reveal
  (80%+ renewal), whoop monday self-vs-self, macrofactor weekly
  check-in that ENDS IN A PLAN ADJUSTMENT (adherence-neutral).
  duolingo spent 2025-26 softening streaks (breakage churns).
  headspace: efficacy ≠ retention. JITAI: receptivity-timed beats
  random by ~40%; effects decay → heuristics before ML, decision
  points jeni already has (dose day, logging hour, wake). >6
  pushes/wk = 3.4× uninstall (our <5 cap is right); batching into
  predictable moments beat ad-hoc in an RCT; med reminder actions =
  best-evidenced category (already shipped in v24). live activity
  for dose day PROMISING; widgets promising; complications/standby
  gimmick-tier. TOP IMPLICATION: THE WEEKLY READ anchored to dose
  day — jeni's week has a physiological anchor no competitor has —
  + ONE notification brain (budget, per-user timing, graceful
  auto-silence). do-not-build: unbroken-chain streaks, phantom/
  fake-urgency pushes, guilt copy, cancellation mazes, marketing
  in the medication category, data-free "we miss you".
- audit/00_canon.md LANDED. 5 binding laws: provenance/honesty
  (killed the PK curve; governs even animation) ·
  observed-never-prescribed (adaptation must be OFFER+CONSENT; v4
  re-signing precedent: ≤1 consented change/wk from a closed set) ·
  chokepoint/module contract (composition never forks;
  supersede-never-mutate) · care authority = SERVER law (iOS writes
  authority=self only; RPC-only clinician access) · the design law
  (HOME'S LAW fixed anatomy; clinical register unadorned).
  3 tensions for v25: adaptive program must be protocol-shaped data
  feeding EXISTING chokepoints + needs a named consent surface;
  B2B home = recomposition inside HOME'S LAW, never a fork;
  authority ladder must live server-side or it contradicts S4 —
  and v24's blocked "add alongside a care plan" door needs a
  deliberate resolution. deferred gold: widgets ("its own era"),
  annotated dose-era curve, METHOD trigger engine (ONE IDEA ONE
  ACT — design already bound), notification orchestrator (spec'd
  since app_v2), keep-it-off curriculum, B2B registry surfacing.
- research/r5_clinical_rpm.md LANDED. the clinic pitch is CHURN
  (50% discontinue GLP-1 by month 12 vs 7-11% in trials; only 23%
  reach max dose) — not RPM billing (manual app data NEVER bills;
  cash-pay has no payer anyway; later hybrid play). only FOUR
  between-visit signals map to clinician decisions: dose-gap ≥14d
  (label-mandated re-titration) · weight-velocity outliers (>2lb/wk
  titrating, >3 maintenance, >5 gain) · symptoms persisting outside
  the 2-4wk post-escalation window · red flags (pancreatitis-
  pattern, gallbladder, dehydration, hypoglycemia only w/
  insulin/SU, NAION vision loss, mood→crisis-route; catalog
  remotely updatable; surface+route never diagnose). meals/steps =
  clinician noise. under-reporting is the wedge: 41% suffer in
  silence, 11% self-adjust dosing silently, 30% think their doctor
  won't take symptoms seriously. design: exception queue <10
  min/day + weekly digest + PRE-VISIT ONE-PAGER (the artifact a
  20-min visit consumes — S3 packet was right); NEVER an inbox
  (portal volume → 6.4× exhaustion odds). micro-PRO ≤4 taps, weekly
  during titration windows only. clinician-tunes-coach: STRUCTURED
  CONTROLS ONLY (vetted scripts, thresholds, plan pickers);
  free-text prompt editing = gimmick + liability. regulatory: HCP
  dashboard → build to §520(o) CDS-exemption criteria; patient side
  stays general-wellness framing; state AI laws (IL/CA/TX) require
  AI identity disclosure + ban clinician impersonation. v24 fit:
  titration chains want HOLD/SLOW first-class + 4-week review
  clock. do-not-build: dose calculation/auto-titration advice,
  predictive emergency alerts, AI messages signed as the clinic,
  a second EHR, continuous alert streams, RPM billing claims.
- research/r2_food_logging.md LANDED. honest photo-AI state:
  recognition ~86% solved, PORTION VOLUME is not (~39% reliable);
  frontier VLMs ~36% energy MAPE, >60% protein error; consumer
  photo apps (incl. cal AI) undercount kcal+fat by ~1/3 in a
  NUTRITION 2026 controlled test. cal AI = cautionary tale ($30M
  ARR → apple removal for deceptive billing + breach). strongest
  pipeline (nobody ships it all): vision → verified-DB grounding
  (USDA FDC CC0 canonical; OFF queried LIVE with attribution —
  NEVER merge OFF into our tables, ODbL share-alike) →
  history-prior portions → ONE clarifying question → editable
  items → corrections stored as priors. fatigue: median logging
  life ~29 DAYS; >15 min/day doubles abandonment; proven
  extenders: REPEAT MEALS (5.9% vs 4.3% weight loss), logging
  speed, partial-day legitimacy (≥2 occasions/day = the clinical
  adherence bar), retro paths (photo-ONLY loggers quit MORE).
  metrics that drive action: kcal + protein floor (80-120g GLP-1)
  + fiber + hydration; sodium/micros = clutter. macrofactor's
  adherence-neutral + journal-powers-the-algorithm loop = why
  users pay $72/yr with no free tier. do-not-build: proprietary
  food DB, accuracy-% marketing, loss-pressure streaks, red/green
  judgments, micro dashboard, glucose prediction, depth-sensor
  bet, photo-only identity, fabricated outcome stats.
- research/r1_glp1_companions.md LANDED. the category's most-loved
  feature (estimated med-level curve) is scientifically inaccurate
  (8-72h peak variance, 2-3× individual spread) — VALIDATES our
  no-PK-curve law; the honest substitute is CYCLE-DAY framing
  (day 6-7 food-noise return = proven lived pattern). food noise
  as a tracked vital (meagain 0-10 slider vs dose timing) = best
  single idea in category. calorie logging dies on GLP-1 (the
  half-portion problem) → protein adequacy + fractional portions
  win (v23's fraction control already exists). underreported
  symptom set (400K-post upenn study): fatigue, menstrual changes,
  temperature, mood, hair (>75% shedding) — NO app tracks these;
  pairs with r5's 41%-suffer-in-silence wedge. nobody encodes
  missed-dose LABEL RULES at log time (zepbound 4-day/72h, wegovy
  48h/5-day) — the most-googled panic moment; cheap win as label
  facts + prescriber routing (never advice). maintenance nearly
  unbuilt (regain ~14%/yr; 15% microdose, half hiding it).
  insurance switches + compounding wind-down + the oral era make
  regimen SWITCHING normal — v24 version chains are built for
  exactly this. telehealth companions burned trust (hims FTC,
  zealthy FTC/DOJ/FDA) → privacy-first honest register = open
  lane. build ranks: cycle-day+food-noise pattern · missed-dose
  label facts · maintenance era · consult-prep summary (PDURS =
  long-run b2b prize) · underreported-symptom vocabulary.
  do-not-build: PK curve, mascot gamification, compounded dosing
  calculators, microdose presets, hard paywall on basics, in-app
  community feed.
- audit/01_app_reality.md LANDED. everything major is LIVE except:
  care platform (founder-gated; settings doors live), method's
  84-lesson corpus (daily surface = 17 authored reps; full reader
  only via settings archive), v4/v5 onboarding (DEBUG doors).
  VESTIGIAL: PlankEngine + PlankVoice packages (zero imports),
  StepsPulseTile (728 ln), Browse/RoastCard/bento, trial machinery,
  EnergyLedger, 2 skeleton EFs. discrepancies: CLAUDE.md onboarding
  section stale (v8 IS production; files Views/OnboardingV8),
  MARKETING_VERSION actually 1.1.7 (28) not 1.2.0, v23's "Result/
  deleted" is false — FoodCorrectionSheet+PortionStepper survive
  AND are live from CaptureFlowView:155 (the seed of r2's
  correction loop). **v24 medication shipped ZERO analytics
  events** — the becoming-a-system era needs instrumentation from
  day one. chat already has 7 tools + medication{} envelope (real
  foundation for jeni intelligence). workout = 128 exercises +
  1,105 voice clips (big asset, historic ~23% engagement). sync =
  17 tables. dead-weight sweep list: ~18k ln old onboarding behind
  DEBUG doors (6 files in dir still live — careful), PlankEngine/
  PlankVoice, StepsPulseTile, trial stack, orphaned analytics
  constants.

## decisions + rejected alternatives

(record every consequential call here as it's made, with the why and
the alternatives declined.)
