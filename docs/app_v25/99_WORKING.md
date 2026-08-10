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

## decisions + rejected alternatives

(record every consequential call here as it's made, with the why and
the alternatives declined.)
