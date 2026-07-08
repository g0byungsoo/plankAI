# 31 — Chat / Weight / Food premium UI pass (v3.0)

Date: 2026-07-03. Focused UI-layer rescue for the three surfaces the
founder flagged as old/unstable-feeling. Backend untouched: no schema,
RLS, grants, secrets, functions, model, caps, auth, RevenueCat, or
routing changes.

## What felt unstable / old / non-premium (the brutal audit)

- **Chat**: the audit frames showed FOUR duplicate send/answer pairs
  in one transcript (QA history accumulation + demo re-fire — reads
  as "unstable AI wrapper"); a user bubble clipped behind the
  composer mid-keyboard; the tab bar floating awkwardly above the
  keyboard; a "JENI" kicker stamped on every message; the compliance
  line permanently occupying the masthead like a legal banner.
- **Weight**: LogWeightSheet was the last pre-v2 input surface —
  program-pink background, offset-shadow stepper circles,
  accent-stroked borders, italic-Fraunces CTA, a sticker outside the
  three earned moments, and a keypad sheet nested inside a sheet.
- **Food**: journal rows/day-receipts were already v2; the meal
  DETAIL still led with a 40pt kcal hero while protein hid in macro
  rows — inverted against the app's protein-first hierarchy.

## What was redesigned

### Weight → JKWeightRitual (full rebuild; old sheet deleted)
Cream sheet: "THE TREND CHECK" eyebrow → "this morning's number"
serif → 58pt serif numeral with italic accent unit → quiet lb|kg
hairline toggle → **the OV5 tick ruler with haptic detents as the
input** (the onboarding's signature gesture becomes her daily
instrument) → "type it instead" inline fallback (no nested sheet) →
"keep it" / "not now". Saving earns a count-aware confirmation beat
(first: "first morning, logged ♥ / one more morning and your line
begins." · second: "two mornings. your line begins ♥" · after:
"kept ♥ / the line does the thinking, not today's number.") then the
sheet excuses itself (hosts dismiss via onDone so the beat is never
cut short). Entry is judgment-free by design: no delta, no color
states — the trend reads the week.

### Chat stability + letter feel
- Duplicate-send guard (identical text < 3s = stutter, ignored).
- try-again affordance: failed turns set a flag; a quiet capsule
  under the transcript drops the error line (screen + store) and
  re-asks — nothing to retype.
- Kicker grouping: "JENI" marks the start of her turn, not every
  paragraph — consecutive messages group like a letter.
- Compliance line moved into the empty state (reads as her intro,
  not a banner); empty state greets by time of day.
- Transcript pins to the tail while she writes; keyboard focus
  scrolls the tail clear of the composer (the clipped-bubble fix).
- The tab bar yields to the keyboard app-wide (no more tabs floating
  above the keys).
- Tool cards: placed-gently entrance (scale+rise), glyph in a soft
  accent circle.
- User bubbles: quieter receipts (smaller fill, tighter radius).
- Voice guard: emoji hearts from the model render as the brand text
  heart (caught live: gpt-4o-mini emitted ❤️).
- Wire probes (DEBUG-only NSLog) on transport error paths.

### Food detail protein-first
The plate detail hero is now protein ("34g *protein*" serif) with
calories folded into the context line ("about 520 cal · 38% of the
day · 12:42pm"); kcal hero remains the honest fallback for
protein-less entries. Rows/day receipts verified already-v2; snap
carousel untouched (restraint — it's the signature).

## Verification

- Unit suite green; full five-leg walker green on this build
  (fresh ledger /tmp/jenifit_ledger_v30).
- **Real deployed backend, in-app**: fresh-install live turn
  streamed a real gpt-4o-mini reply addressing her seeded name;
  jeni_chat_telemetry gained ok rows (32-token turn, cost logged) —
  caps counting real app traffic. The one "failure" seen mid-pass
  was a stale store replaying a pre-model-fix error line; wire
  probes + fresh install proved the path clean.
- **iPhone SE**: chat (brief + state-aware chips, no clipping) and
  the ritual — first cut clipped the eyebrow/"not now" at 0.62
  detent; fixed (0.7 + tightened verticals) and re-verified complete.
- food-vision untouched (no deploys this pass; v24 stands).
- Videos: weight_ritual.mp4 (flow window), chat live turn shots;
  ritual harness + livedDay leg exercise the sheet end-to-end.

## Honest remaining gaps

- The livedDay walker leg skips the weigh step on the day-12 seed
  (today's weight pre-seeded → no trend-check beat) — the ritual is
  covered by the harness + manual verification instead; a seed-day
  variant that forces the weigh beat would close this.
- Ritual drag (ruler detents) verified by component provenance (same
  OV5Ruler as onboarding, walker-exercised there) — no simctl drag.
- Chat empty-state greeting shows only pre-brief (fresh accounts);
  enrolled users open to the brief line by design.
