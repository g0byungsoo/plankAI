# AGENT EXTRACT — clinician needs / B2B (ad50949b)

FRAME: AOM follow-up = four decisions: titrate up/hold/de-escalate/switch · manage tolerability · protect nutrition+lean mass · escalate red flags. Cadence (Obesity Association 2026): monthly ×3 months, quarterly to month 12, then 6-monthly; titration ~q4wk. Summary unit = THE INTERVAL (4–12 wks), never the day.

RANKED FIELDS for a between-visit summary:
1. Weight trajectory AS A RATE with provenance: start→now, %total, %/week velocity flagged vs bands: adequate ≥0.5%/wk (Embla treat-to-target, Seier DOM 2025); excessive >1.5 kg/wk (Delphi 87%). Weigh-in count + provenance (scale vs typed); 30+ day gaps predict regain.
2. Dose ledger: every dose date/product/dose/on-time-late-missed + weeks at current dose. (Jeni's DoseEventRecord is already exactly this.)
3. GI side-effect burden: symptom × worst severity × days-affected + clustering within 48h post-injection + trend vs prior interval (Delphi 100% consensus nausea/vomiting/diarrhea; Shotsy's most-praised feature = symptom-vs-dose overlay).
4. Red-flag events surfaced RAW, never interpreted; "none recorded" is itself information.
5. Protein adequacy vs explicit floor: 1.2–1.6 g/kg/d (joint advisory) / 1.2–1.5 (Delphi 87%); report days-meeting-floor of days-logged, median g/day. NEVER daily calorie tables.
6. Hydration flag: >2 L/day necessary (Delphi 87%); report as symptom-threat flag not ml chart.
7. Strength-training sessions/week vs ≥3 target (advisory) / ≥150min + RT (Delphi 93%); NOT step counts.
8. Appetite/satiety/food-noise in her OWN words (Embla escalates when satiety "unmanageable"); one verbatim line.
9. Injection-site rotation exception flag (lipohypertrophy).
10. Nutrition-warning symptoms (hair loss, fatigue, bruising → lab triggers).
11. Mood-change flag, event-based only (FDA: no causal suicidality link; vigilance still advised).
FORMAT LAW: trends over points, thresholds over streams (npj Digital Medicine PGHD).

NOISE/UNSAFE: daily calorie totals (self-report under-reports 17–38% — "should not be used for the study of energy balance"); raw step streams (RPM meta: no outcome effect; ~70% of wearable data clinically unusable); daily mood charts; ESTIMATED MEDICATION BLOOD LEVELS (Shotsy's PK curves = false precision, no guideline asks for it); bulk food photos; app-computed composite scores (liability: implies review duty); photo body-composition (no evidence).

SAFETY BOUNDARIES: record verbatim + route ("contact your clinician now"), never interpret/score/reassure: pancreatitis-shaped pain, gallbladder signs, dehydration/AKI (can't keep fluids ~24h), hypoglycemia w/ insulin/SU, mood worsening (route to crisis resources). Never advise stopping/skipping doses. Reverse boundary: don't normalize severe events ("nausea is common" only for mild).

QUOTES: "It's a lot of extra work to review more and more data. More clicks are cumbersome" (clinician, npj 2025) · "systems… aren't set up to receive and make use of that data" (Shoreibah/UAB) · patient brings Shotsy PDF "share with my medical provider monthly at check in".

COMPETITOR EXPORTS: Shotsy PDF = doses+sites+side effects+weight (+PK overlay); FlyteHealth = PROs, adherence, weight, BP, nutrition, activity; Embla = monthly weight, weekly med log, side effects + hunger/satiety at nurse consults; Ro = connected scale + weekly nurse check-in; nobody ships calories/steps/mood to clinicians.

JENI PAGE (order): header product/dose/weeks-at-dose/doses taken-late-missed → weight rate + bands + provenance → tolerability table + clustering → red flags (or "none") → protein floor days-met + warning symptoms → resistance sessions/wk → one patient-voice appetite line + rotation exception → footer: consent, provenance legend, "patient-recorded; not independently verified; no continuous monitoring implied". Existing record covers ranks 1–3, 5–9 with NO new collection; work = interval-grain compression + band flags + refusal to interpret.
