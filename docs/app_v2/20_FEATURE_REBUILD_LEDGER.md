# 20 — v2.5 feature rebuild ledger

Date: 2026-07-03. The one-go sprint's build record against the
founder's feature list. Evidence: the refreshed PNG ledger
(/tmp/jenifit_inventory, in-repo walker) + build/test logs.

## Touched THIS sprint (v2.5)

| Feature | What changed | Evidence |
|---|---|---|
| Today | chain line renders seeds AND routes; silk sweep + anchor refresh hooks in refresh() | 60_evening shot |
| Jeni chat | suggestion chips are STATE-AWARE (comeback, evening protein gap, trend uptick, craving hour — computed from the live snapshot, provenance-gated) | walker jeni leg |
| Becoming | Sunday "the week, kept" receipt block (plates/protein-days/line movement from WeekState); designed fresh-user state ("your story starts on day one") | code + next Sunday ledger |
| Journal | day headers are protein-first receipts ("62g protein · 2 plates · about 860 cal") | walker journal leg |
| Snap lifecycle | post-log chain: evening plates offer a jeni-seeded dinner idea | chain system |
| Weight | post-save chain: "the trend line does the thinking" → becoming | chain system |
| Steps | brief cascade thread: yesterday's goal-hit becomes today's easiest-lever line (1-in-3 rotation) | brief engine |
| Workouts | completion chains into protein-soon → snap | chain system |
| Method | (v2.4 chain) + reflection handoff below | — |
| Journal/reflection v1 | evening close gains the archetype-aware guided prompt + one optional line, saved to her file by dayKey | 60_evening shot |
| Notifications | the daily anchor speaks tomorrow's archetype line at her hour, refreshed once/day from Today; deeplink to today; same surgical-removal discipline | NotificationOrchestrator |
| Breathwork | (v2.4 craving-reset reframe) verified in the ledger rest-day leg | 81-83 shots |

## Touched in the parent passes (v2.0-v2.4), still current

Shell/gating/walls/migration (v2.0) · Today ritual + beats engine +
targets unification (v2.0) · chat stack + safety (v2.0) · Becoming
insight layer (v2.1) · silk sweep + celebration retype (v2.1) ·
journal rows + Becoming curation + notification deep links (v2.0/2.2)
· steps sheet + strip sheets + workout brief receipts (v2.2/2.3) ·
sweep of 12 legacy files (v2.3) · craving doorways + 5-minute floor
+ lesson chain (v2.4).

## Production safety delta (v2.5)

Client-only. The one notification change uses the existing canonical
id + removal discipline; no server artifacts touched. 13_DEPLOY_SAFETY
verdict unchanged.

## Honest remaining deferrals (each with its gate)

1. Method CONTENT rewrite — gate: 10-sample-slot doc for founder
   voice sign-off (the system around lessons is now built: journey
   card, ordinal cadence, chains, reflection handoff).
2. Setup-ritual flow order + commitment moment — gate: founder taste.
3. Journal reflection cloud sync — gate: the sync v2.1 batch
   (day_reflections table already shipped server-side).
4. Per-day one-shot anchor laddering (vs the repeating trigger's
   2-day staleness bound) — gate: orchestrator consolidation.
5. Weekly receipt share artifact — gate: founder pick of register.
6. Chat transcript cloud sync — gate: sync v2.1 batch.

## Verification

Fresh full-ledger run (4 walker legs) after the sprint + unit suite
+ the evening-close capture (60_) proving the whole loop in one
frame: seeded plates → protein arc 62/90g → kcal line recomputed
from latest weight → day receipt with the lived-day mark → correct
tomorrow whisper → archetype-aware reflection prompt.
