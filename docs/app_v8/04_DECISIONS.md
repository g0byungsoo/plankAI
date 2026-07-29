# app v8 — THE DECISION LOG (living, 2026-07-28)

Format per entry: **decision** · evidence · tradeoffs · status.
Sections: standing decisions → postponed → needs-founder. Entries
land as research resolves them; nothing ships un-logged.

## Standing decisions

**D1 — Pull the v7 phase-5 platform seam forward to now.**
CareProtocol config + typed ObservationStore + BrandVoice stop
being "last phase" and become the foundation this pass builds on.
· Evidence: v7 thesis §4 already designed the seam; the founder
brief makes it the company direction. · Tradeoff: phase 3 (first-
move letters) and phase 4 (material/feel sweep) queue behind it.
· Status: adopted.

**D2 — Additive-only data evolution.** New tables/columns/records
only; defaults safe; no destructive migration; every record
tenant-friendly (stable ids, provenance fields, nullable org
seam); zero clinic UI exposure. · Evidence: medical-grade spec
principle 1; live TestFlight users on v1.1.2. · Status: adopted.

**D3 — The consumer is the default tenant.** One protocol
vocabulary serves both futures; the consumer experience is the
default protocol instance, never a fork. A clinic later authors a
protocol; the app renders it through the same engine. · Status:
adopted.

**D4 — The checklist grammar is kept; its content becomes
protocol.** Founder-locked form (sticker rows, check-off, day
rail, tools rail, rings) persists; rows re-anchor from app
features to care actions per research. · Status: adopted; item
taxonomy awaits 01_RESEARCH.

**D5 — Language completes the clinical-calm trajectory.** Plain
comprehension-first verbs (log / record / track / scan), zero
diet-culture or influencer residue, warmth in tone not poetry —
inside the editorial composition laws and lowercase voice.
· Evidence: founder register steers 2026-07-17 →; health-literacy
lane lands in 01_RESEARCH. · Status: adopted; audit pending.

**D6 — Protocol shape (research-resolved).** The item VOCABULARY
grows (medication, hydration, waist later); the daily ask count
does NOT — ≤3 actionable moves stands, medication + one keystone
are the non-negotiables on dose days, everything else is offered.
Morning-anchored; intensity tapers across program phases (DPP
pattern). · Evidence: 01_RESEARCH §B5 (2-3 habit start, burden
kills adherence in our exact demographic), §B8.1. The founder
brief's 9-item example ships as vocabulary, never as a
simultaneous checklist. · Status: adopted.

**D7 — Supplements: never co-equal, never the default spine.**
No supplements-first onboarding default; one optional collapsed
"supports" line; protein is the foregrounded evidence-backed
support (1.2-2.0 g/kg advisory; >22% of GLP-1 users deficient
within 12mo). Copy stays structure/function-safe. · Evidence:
§B3. · Status: adopted.

**D8 — The shot-day ritual.** RegimenPlan.anchorWeekday is the
transformative field (the panel's named move): a fixed, named
weekly ritual — qualitatively different from any ping — plus the
titration support window (weeks 1-8) driving hydration +
side-effect care. Missed-dose guidance stays out of app-authored
copy (no dosing advice — wall B5.8); the row simply re-offers.
· Evidence: §B1-B2 (weekly cadence week-slip; implementation
intentions d≈0.65; 30% quit in first 4 weeks). · Status: adopted;
lands with the regimen build.

**D9 — The verb law (language register).** ONE verb per action,
concrete, gain-framed, lowercase editorial: **add** (food — "add
breakfast", "add your plate"), **mark** (dose — "mark today's
dose"), **weigh in** (existing), **walk**. "Snap" survives only
as the camera's own gesture name, not as the ask; "log/track/
scan" retire from asks. Notifications: few, personalized-time,
gain-framed, content rotated. · Evidence: §B7 (AHRQ plain
language; anxiety degrades comprehension; verb consistency;
no-RCT-on-verbs confirmed — this is judgment on evidence).
· Status: adopted; sweep in the language pass.

**D10 — "After the medication" is a named product direction.**
The market's weakest beat with zero consumer competitors and
brutal physics (84% off drug by yr 2; +14% regain unsupported;
taper-support proof is B2B-only). The post-GLP-1 chapter + v7 §8
post-medication arc get pulled forward on the roadmap; the
protocol object must express a taper/maintenance phase from day
one. · Evidence: 02_COMPETITORS §B3.3. · Status: adopted
(architecture now; surface next pass).

**D11 — Trend-as-hero is retention mechanics, not just voice.**
Every 1% lost cuts discontinuation hazard ~3% (JAMA 2025) — the
trend-first anti-shame narrative is the mechanism that keeps
women in care. Reinforces existing law; cited for the record.

**D12 — Business posture notes (for the founder).** Never
compete on drug access (falling $149 floor; partners revoked
overnight); the clinic layer prices per-enrolled-patient/month
($10-25 PPPM opening — rare in category, aligned with clinic
RPM/CCM revenue); radical billing legibility as brand (the
category's top complaint genre is our trust moat); consented
outcome data is the clinic entry ticket. · Status: recorded for
founder strategy; no app change this pass.

**D13 — Sit-check widened one word, one cohort.** "backed up"
joins fine/heavy/queasy (constipation is the most persistent GLP-1
complaint and outlasts titration — it was unrepresentable in three
words), and the evening sit-check extends to the post-medication
chapter. One optional tap stays the whole cost; answers now land
in the chart. · Evidence: v7 clinic panel (problems §7, recs §8);
04_CLINICAL_CHECKLIST §1.2. · Status: shipped this pass.

## Postponed (named, not dropped)

- S2 server-hydrated protocol/content; S3 care-team surfaces
  (visit-prep packet is the bridge candidate); S4 tenancy +
  BrandVoice re-voicing.
- HIPAA/BAA, FHIR/EHR interop, clinical governance org, SaMD
  legal opinion — required before any external "medical-grade"
  claim or clinic partnership; non-app tracks (medical-grade spec
  out-of-scope list stands).
- v7 phase 3 (first-move letters, comeback tiers, celebration
  ladder) + phase 4 (chart grammar port, heart budget, JeniHaptics
  semantic layer) — queued behind the platform foundation.

## Needs founder

- **F1:** whether her own entered medication name may render on
  her private surfaces (display-only; never notifications, never
  app-authored) — compliance-reviewed recommendation to follow in
  04 after research lands.
- **F2:** hearts + sticker warmth inside the clinical-calm
  register — keep (current law) vs quiet further on protocol
  surfaces.
- **F3:** onboarding evolution — RESOLVED into a recommendation:
  Stage A reframe over the v5 machine (contract sentence,
  expectation anchor, shot-day beat + regimen handoff,
  supplements single-ask, verb-law sweep), full design +
  staging in `06_ONBOARDING.md`. v5 is founder-reviewed law, so
  Stage A awaits the founder's go; no onboarding code changed
  this pass.
- (open — entries append as decisions surface them)
