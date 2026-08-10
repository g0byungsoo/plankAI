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

## decisions + rejected alternatives

(record every consequential call here as it's made, with the why and
the alternatives declined.)
