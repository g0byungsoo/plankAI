# AGENT REPORT EXTRACT — education evidence (full text arrived 2026-08-18, agent a7ce146274c7bb43c)

## Tier verdicts (S=strong, RP=reasonable practice, W=weak, IWC=internet wellness claim)
1. Energy balance governs (S — Hall AJCN 2022). Digital self-monitoring improves loss (S — Berry Obesity Reviews 2021). Frequency→magnitude association S, causation RP (Payne Obes Sci Pract 2022). Copy: "people who log more consistently lose more" not "logging causes loss".
2. Protein: higher protein preserves lean mass in deficit (S — Leidy AJCN). GLP-1 numbers: ≥1.2 (to 1.6) g/kg/d, 0.3–0.4 g/kg/meal = RP from **2025 four-society joint advisory (ACLM/ASN/OMA/TOS, co-published AJCN/Obesity/Obesity Pillars)** — extrapolated, no RCT on AOMs; must be attributed.
3. Fiber 25–38 g/d S general; GLP-1-specific = RP; ramp ~5 g/week + fluid (Mayo Clin Proc 2025; PubMed 42106160).
4. Resistance training preserves lean mass in deficit (S — meta 35191588). **On GLP-1: Lundgren NEJM 2021 (S-LiTE): liraglutide+exercise beat either alone for 1-yr maintenance, preserved FFM, ~2.4 sessions/wk feasible — the single best citation in the layer.**
5. Steps: maintenance-insurance S (registries: activity = most consistent maintainer trait — Paixão 2020, Varkevisser 2019); steps during loss phase don't predict loss magnitude (W for loss). 10,000 myth dead (Paluch Lancet Public Health 2022: plateau 6–10k).
6. Sleep: Tasali JAMA IM 2022 RCT — +1.2h sleep → −270 kcal/day intake (S, short-term). "Sleep to lose weight" = W.
7. Water weight: 0.5–2.5 kg daily fluctuation normal (S); glycogen ~3 g water/g (S); sodium clears 1–3 d (RP); menstrual ~+0.45 kg mean, up to 1.5–2.5 kg (S exists/RP magnitude — Kanellakis AJHB 2023). **Highest-value low-risk content family.**
8. Plateaus: 6-mo plateau = intermittent adherence not stalled metabolism (S — Thomas/Hall AJCN 2014 model); adaptation modest tens of kcal (S); adaptation doesn't predict regain (S — Martins UAB). "Starvation mode" = IWC.
9. Regain: STEP-1 ext (DOM 2022): stop semaglutide → ~2/3 regained by wk120. SURMOUNT-4 (JAMA 2024): stop tirzepatide → ~14% BW regain in 1 yr. Must never render as "don't stop your medication".
10. Habits: ~59–66 days median to automaticity (Singh Healthcare 2024; Lally 2010); 21 days = IWC. Implementation intentions: real but small in health (d 0.14–0.24 PA).
11. GLP-1 GI: 40–70% GI AEs (S — Frontiers Pharmacol 2025 network meta). Small/slow/low-fat meals etc = RP (untrialed convention, attribute + route to prescriber). Eating adequately when appetite low: protein-first by plan = RP (2025 advisory).
12. Self-weighing: aids loss in programs (S — Madigan 2015 meta, −1.7 kg adjunct); daily vs weekly same outcome (S); no mood harm in general adults (S — Steinberg 2014); **BUT 2024 RCT in emerging-adult women (n=69, PMC11351998): daily weighing → negative affective lability — the harm signal exists precisely in Jeni's demographic.** Trend-line-display-reduces-anxiety = RP by inference, NOT directly proven — name the gap.
13. Lean mass on GLP-1s: STEP-1 DXA ≈ 39–40% of loss was lean soft tissue; SURMOUNT-1 DXA ≈ 25–26%. Fat loss predominates 2.5–3:1 ("melts your muscle" = IWC). LST ≠ contractile muscle (Prado Lancet D&E 2024).

## JITAI vs curriculum
- Koh 2025 JMIR e76625 VERIFIED: 35 studies/19 interventions; JITAIs deliver prompts 94%, feedback 69%, **educational info only 14%**; weight effects 0.5–3.7%; retention 74–100%; rule-based 68.6%. **NO head-to-head JITAI vs linear curriculum exists — say so honestly.**
- Attrition: Eysenbach law; engagement carries outcome (JMIR 2024 e45469 — early lesson INITIATION predicts loss, i.e. sequencing not volume); Noom outcomes engagement-stratified because completion collapses.
- Internal: 84-lesson curriculum vs median 2.0 active-day payer = median dose ~2% of content. → Verdict: contextual micro-education wins on REACH, not proven superiority. Bloom RCT (arXiv 2510.05449): users valued plans, not chat.

## Card architecture (extends MethodNote chassis)
Fields: trigger (predicate over her record, stated in card) · oneIdea (≤2 sentences, tier-hedged) · oneAction (if-then micro-plan, non-medical) · neverClaim (machine-checked banned assertions) · evidenceTier (S/RP/W; W never ships) · attribution (required for RP) · cooldown (≤1 edu card/day, share notification arbiter) · quiet (safety gate/ED flags suppress weight-variability cards) · authority (.general vs .careTeam outranks) · expiry (resolves with the observation) · measure (event + proximal outcome).

## Top triggers by evidence × frequency
1. Weigh-in spike after salty/carby logged dinner → water-weight (S, daily-class)
2. Evening protein gap → protein-why (S/RP, daily-class)
3. Logging gap ≥3d → consistency (S-assoc, weekly)
4. No strength 14d while trend falls → lean-mass NEJM (S, weekly)
5. Dose day + nausea → small/slow/low-fat, attributed (RP)
6. Constipation/fiber<15g 5d → fiber+fluid ramp (S/RP)
7. Intake <1000-1200 3d+ on GLP-1 → eat-by-plan (RP; suppressed under safety gate)
8. Trend flat ≥21d with logging → plateau truth (S, monthly)
9. Weigh-in rise near menstruation (if cycle context given) → cycle water (S/RP)
10. Rising scale-check frequency + frustration → trend-not-day (S freq-equivalence)
11. Steps collapse >40% below her own norm → her-own-usual (S-maint)
12. Sleep <6.5h 5+ nights (data-gated) → 270 kcal RCT (S short-term)
13. New habit declared in chat → 10 weeks + if-then (S)
14. Dose gap ≥2× cycle / stopping language → regain data + clinician conversation (S data; hard neverClaim wall)
Excluded as IWC: metabolism-boosting foods, water-for-loss targets, cortisol-fat, detox.
