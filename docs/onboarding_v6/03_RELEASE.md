# Onboarding v6 — RELEASE DECISION DOCUMENT

2026-08-02, the production-readiness pass. This document exists so
the v6 baseline's production results can be TRUSTED: what ships, what
stays dormant, what is measured, what was decided, what is assumed,
what is risked, and what number gates the next decision. Optimized
for interpretability, not impressiveness.

## 1. What ships

The v6 onboarding + keep wall exactly as recorded in
`00_DIRECTION.md §10` (commits a26ab6a…30086cf), plus this pass:
- The canonical production funnel (§3) under `onboarding_version:
  "v6"`, emitted alongside — never instead of — the legacy events.
- Truthful purchase resolution: pending (Ask to Buy / bank
  confirmation) is messaged as pending, not failure, and never asks
  for a retry; network drops no longer imply "nothing was charged";
  the smaller-step sheet's silent no-package tap now speaks and
  reports. One latent analytics-sink concurrency crash fixed
  (mutation-during-enumeration on the sink list; mutations now
  serialize onto the send queue).
- The F2/F8 dormant surfaces (§2).
- The research digest re-audited for evidence classes and the
  no-forecast rule (`02_RESEARCH.md` preamble).

No architecture, copy, visual-system, wall-fold, pricing, trial, or
ATT-position changes were made in this pass beyond the corrections
listed above — the experiment baseline is protected.

## 2. What remains dormant

- **Real social proof (F2)** — `PaywallRealProof` in
  `PaywallView.swift` is the ONLY content location; the band renders
  nothing until verbatim ASC reviews + the live rating + a sourcing
  date all exist, and partial/blank content disappears cleanly.
  Update = edit that one data block (+ bump `contentVersion`); no
  paywall layout code is touched. Fabrication, paraphrase,
  combination, or cosmetic improvement of reviews is prohibited.
- **Clinical reviewer attribution (F8)** — `ClinicalReviewRecord`
  (reviewer, credentials, scope, review date, content version);
  `ClinicalReview.current = nil` renders nothing anywhere. When a
  real RD/MD completes a real review, the one permitted claim is
  scoped: "content reviewed for clinical accuracy by [Name,
  Credentials]" + what/when/version. Never an approval claim for
  the app, the personalized plan, or any outcome.
- **The 7-day-trial arm (F4)** — not exposed. Architecture ready:
  offerings are server-side (RevenueCat), the funnel splits by
  `product_id` + `onboarding_version`, and completion is
  edge-triggered off the entitlement stream, so a future trial
  offering needs no client analytics change.

## 3. The production funnel (the measurement contract)

All canonical events carry the metadata block: `onboarding_version`
("v6") · `cohort` (GLP-1 status key or "unset") · `acquisition_
source` (self-reported; "unset" until answered) · `att_status` ·
`device_class` (phone/pad × se/compact/regular) · `locale` — plus
the global `app_version`/`environment` stamps. Campaign is NOT
collected client-side (ad-platform attribution lives with the
networks; the in-app signal is the self-reported source). No weight,
goal, or other health value rides any funnel event.

| event | fires at | semantics |
|---|---|---|
| install | PostHog "Application Installed" (lifecycle capture ON) | SDK-managed; not duplicated |
| onboarding_started | first OV5 mount | once per install |
| care_safety_completed | safety gate onPassed (+mode, suppression) | once |
| personalization_completed | hold-to-build seal | once |
| plan_reveal_viewed | projection presentation (+variant) | once |
| paywall_viewed | first wall presentation | once (legacy `paywall_view` continues per-presentation) |
| plan_selected | tier row tap (+plan, product_id, surface) | repeatable |
| purchase_started | purchase CTA, BEFORE the StoreKit handoff | repeatable; every start pairs with a resolution |
| purchase_completed | PaymentService entitlement stream, inactive→active edge | exactly once per real purchase — the cached-entitlement init (`lastKnownEntitlementKey`) preserves the edge across cold launches; also catches backgrounded/pending completions and all surfaces |
| purchase_cancelled | user closed Apple's sheet (+surface) | repeatable |
| purchase_failed | store error / not-activated / unresolved package (+reason, surface) | repeatable |
| purchase_pending | Ask-to-Buy / SCA thrown as pending (+surface) | repeatable; NOT a failure |
| restore_started / restore_completed(+entitlement_active) / restore_failed | wall restore | repeatable |
| att_prompt_shown / att_result (+context, status) | mid-loader ATT ask | once (OS asks once) |

Exactly-once verification: unit-tested (`V6FunnelTests`, 4/4 — once
guards hold across repeats; metadata keys present; no health values)
and live-verified on-sim (fresh install fired `onboarding_started`
with the full block; first wall launch fired `paywall_viewed`; a
relaunch fired zero canonical duplicates while legacy per-
presentation events continued). Purchase surfaces covered: wall,
downsell year, smaller step (`surface` property); the day-6 upgrade
moment is post-purchase and deliberately outside this funnel.

QA-door caveat (not a defect): `--uitest-skip-payment` keeps
RevenueCat unconfigured, so entitlement-readiness never flips and
the app holds pre-wall — use it for capture runs only, never for
funnel checks.

## 4. The four experiment decisions (as approved)

- **F2** — approved conditionally; dormant until genuine verbatim
  content exists (mechanics in §2).
- **F3** — ATT stays mid-loader THIS RELEASE to protect the
  baseline; explicitly not permanent. Instrumented for the future
  test: context + prompt + result events, and ATT status on every
  funnel event, so current-vs-post-onboarding placement can be
  compared on real data. Denial gates nothing (verified: no code
  path reads ATT status for behavior).
- **F4** — no trial this release. The eventual experiment: hard
  wall vs 7-day trial on the yearly tier, judged by REVENUE PER
  INSTALL and RETAINED PAID SUBSCRIBERS at cohort maturity (≥45
  days: trial resolution + first renewal + refund settling), never
  by trial starts.
- **F8** — surface prepared, dormant; no reviewer claim until a
  real qualified reviewer has reviewed named material (record in
  `ClinicalReviewRecord`).

## 5. Purchase-path matrix (evidence per case)

Classes: LIVE = executed this pass on sim · TEST = green automated
test · AUDIT = code-path audit with mechanism named · DEVICE =
requires founder device/sandbox — a pre-submission gate.

| case | evidence |
|---|---|
| fresh install → wall | LIVE (fresh install → onboarding_started; wall mounts + paywall_viewed) |
| eligible purchaser to Apple sheet | TEST (KeepWall recovery leg walks CTA→sheet on the StoreKit config) |
| purchase completion + entitlement | AUDIT (stream edge → entitlement + purchase_completed) + DEVICE (real sandbox completion) |
| weekly / annual purchase paths | TEST (tier selection + CTA per tier) + DEVICE for completion |
| ineligible introductory offer | N/A BY DESIGN — the live offering sells no intro offers or trials; nothing exists to be ineligible for |
| purchase cancellation | TEST (full ladder: cancel → downsell → winback → reclaim → smaller step) + purchase_cancelled instrumented |
| purchase failure | AUDIT (classifier → truthful message + purchase_failed(reason) + $exception) ; failure injection not simulated locally — DEVICE/sandbox residual |
| pending purchase (Ask to Buy / SCA) | AUDIT (pending ≠ failure; message says it completes on its own; stream activates whenever it clears — including after relaunch, via the cold-start edge) + DEVICE residual |
| restore | AUDIT + instrumented (started/completed/failed); recovery flows unit-tested (EntitlementRecoveryTests) + DEVICE residual |
| existing subscriber, fresh device | AUDIT + TEST (sign-in door; interactive-sign-in recovery window; 2026-07-25 hardening) |
| network interruption | LIVE (pricing-fail leg: skeletons, failure row, retry CTA, nothing chargeable) + AUDIT (mid-purchase drop message no longer claims "nothing was charged") |
| backgrounding during purchase | AUDIT (system-owned sheet; resolution via result or the stream on return) |
| entitlement propagation after relaunch | AUDIT (cached entitlement init + first stream emit + AppPhase gating; AppPhaseTests table) |
| silent purchase-start taps | CLOSED — release builds cannot tap without a resolved price; the one silent guard found (smaller-step missing package) now speaks + reports |

## 6. Known assumptions

- The StoreKit configuration exercises the REAL StoreKit 2 + RC
  purchase code paths; only completion economics differ from
  production. Real sandbox completion remains a founder gate.
- PostHog "Application Installed" is an accurate install proxy
  (lifecycle capture verified enabled in config).
- DEBUG console-sink evidence generalizes to the PostHog sink (both
  sit behind the same `Analytics.track` path).
- Walker taps approximate real user taps; per-cohort legs cover the
  branch structure.
- `acquisition_source` is self-reported and biased accordingly —
  interpret as identity, not attribution.

## 7. Known risks (unresolved)

1. **Real-device purchase legs unexecuted** (completion, pending,
   failure injection, restore against sandbox) — the top risk;
   founder pre-submission checklist below.
2. The earned-trust bands lengthen the wall's scroll surface; their
   effect on conversion is what the baseline MEASURES — treat any
   read before the §8 gates as noise.
3. ATT prompt lands mid-loader on slow devices near tape end; the
   new att_* events make any interaction visible, but the timing
   itself is unchanged this release (F3).
4. Compile-time proof content (F2) means an App Store release is
   needed to activate it — accepted; the band is invisible until
   then, so App Review sees a complete wall either way.
5. Legacy + canonical event pairs (paywall_view/paywall_viewed,
   paywallTierSelected/plan_selected) coexist by design — dashboards
   must query the canonical set for the v6 funnel (this doc is the
   contract; mixing vocabularies will double-count).

## 8. Metrics required before the NEXT onboarding decision

All from the canonical funnel, production environment only:
- ≥1,000 installs carrying `onboarding_version: v6` AND ≥30 days of
  cohort age on the earliest 500 (weekly renewals ≥4 decisions;
  refunds settled).
- The seven step-rates, stable week-over-week (<±20% relative drift
  across two consecutive weeks): install → onboarding_started →
  care_safety_completed → personalization_completed →
  plan_reveal_viewed → paywall_viewed → purchase_started →
  purchase_completed.
- Revenue per install + completed-purchase mix by product_id, split
  by cohort, att_status, device_class.
- purchase_failed/purchase_pending rates by reason (a nonzero
  pending rate validates the Ask-to-Buy path; a rising
  package_unresolved rate is an offerings incident, not funnel
  news).
Until every gate above is met, no onboarding copy, structure,
pricing, or placement change should be made on conversion grounds.

## 9. Rollback path

- The v6 series is additive on `feat/app-v2`: revert = drop/revert
  a26ab6a…HEAD (docs + code revert cleanly; no schema, data-contract,
  RC-offering, or server changes anywhere in v6).
- New UserDefaults keys (`funnel_once_*`) are inert under any build.
- Canonical events are additive — old dashboards unaffected by
  rollback; the v6 dashboard simply stops receiving.
- Production rollback after submission = ship the prior build; no
  migration to unwind.

## 10. The next experiment (only after §8 matures)

**F4: hard keep wall vs 7-day trial on the yearly tier.** One
variable; same onboarding; assignment stamped on every funnel event;
judged on revenue per install and retained paid subscribers at ≥45
days of cohort maturity. Design note: expose via a distinct RC
offering so the client change is assignment + display only. F3's
ATT-placement test queues BEHIND F4 (never two funnel variables at
once).

## 11. Founder pre-submission checklist (DEVICE gates)

1. Sandbox: complete one weekly + one yearly purchase end to end;
   confirm purchase_completed fires once each (PostHog live view),
   entitlement survives relaunch.
2. Sandbox: one Ask-to-Buy pending purchase → verify the pending
   message + later auto-unlock.
3. Sandbox: one restore on a fresh install (existing subscriber).
4. Airplane-mode toggle mid-purchase → verify the truthful network
   message + eventual stream reconciliation.
5. Fill F2 content from ASC when real reviews exist (rules in §2).
