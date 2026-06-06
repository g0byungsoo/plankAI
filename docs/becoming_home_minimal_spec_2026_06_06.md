# Becoming + Home minimal-functional-aesthetic spec

**Date:** 2026-06-06
**Decision:** Ship as proposed. Defer Sunday weekly recap surface to next phase.
**Source:** Synthesis of 3 follow-up expert briefs (Whoop/Apple Health, Aesop/Sweet July, Typography Systems) after founder feedback rejected italic numerals and asked for "minimal but still functional and aesthetic."

---

## Numeral type system (Linear/Things-grade)

| Tier | Use | Type | Weight | Size | Color | Tabular |
|---|---|---|---|---|---|---|
| Hero | Weight digit, plank PR | Fraunces72pt | **Light** | 64pt | cocoa 100% | yes |
| Secondary | Delta, jeweledRose-tinted metrics | DM Sans | Medium | 22pt | jeweledRose 85% | yes |
| Tertiary | Streak day count, units, kcal avg | DM Sans | Regular | 13-15pt | cocoa 72% | yes |
| Label uppercase | "STREAK", "PLANK PR" stat row labels | DM Sans | Regular | 11pt | cocoa 48% | n/a |
| Roman ornament | Chapter pagination i. ii. iii. | Fraunces72pt | **SemiBold upright** | 11pt | cocoa 48% | n/a |

**Rules:**
- Hero number = Fraunces **Light**, NOT SemiBold. Light at display size carries Aesop warmth without banking-app vibes.
- All numbers use `.monospacedDigit()` so deltas re-render without horizontal shift.
- Tertiary digits get tracking +0.1 — small upright digits breathe without bolding.
- Small uppercase labels get tracking +0.04em to +0.08em (Aesop's specimen-label move; 60% of the "warm tool vs tracker" difference).
- Roman numerals stay as typographic ornament (Penguin Classics convention). Romans are NOT data — italic dies, upright stays.

## Italic survives ONLY here

- Italic Fraunces SemiBoldItalic on ONE punch word per scroll-position (`*becoming*`, `*week*`, `*ate*`, `*moved*`, `*changing*`, `*worked*`)
- By killing italic on numerals everywhere else, the italic word becomes a *rare jewel* — load-bearing semantic emphasis, not ambient decoration.
- Brand signature gets **louder** by getting rarer (New Yorker pull-quote behavior).

## 3-tier cocoa hierarchy (the Linear-grade detail)

Most apps ship 2 tiers (primary + 60% secondary) → flat data layer.
Linear/Things ship 3 tiers → composed.

- Primary 100% — hero numerals + section heads
- Secondary 72% — labels ("weight", "streak"), tertiary numbers
- Tertiary 48% — meta ("logged 2h ago", roman numerals, "of 14" in "day 12 of 14")

Pair with **0.5pt hairlines at cocoa 12%** — never 1pt. The 0.5/1pt distinction is the whole difference.

---

## Daily Becoming top-of-scroll (5 elements, ~40% whitespace)

```
┌──────────────────────────────────────┐
│                                      │
│   you're becoming steady             │ ← Identity. DM Sans Med 17pt cocoa.
│                                      │   *becoming* inline italic Fraunces.
│                                      │   32pt top padding.
│                                      │
│                                      │
│   142.4                              │ ← Hero weight. Fraunces Light 64pt
│                                      │   tabular cocoa 100%. left-flush.
│   lb · down 1.4 in 14 days           │ ← Delta. DM Sans Reg 15pt cocoa 72%.
│                                      │
│   ╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╱╲╲╱╲╱╲╱╲╱╲   │ ← Sparkline 1pt jeweledRose.
│                                      │   No fill, no axis, ~80pt tall.
│                                      │
│   ────────────────────────────       │ ← 0.5pt cocoa-12 hairline.
│                                      │
│   STREAK    PLANK PR    THIS WEEK    │ ← Labels 11pt DM Sans Reg uppercase
│   12        1:42        4            │   tracking +0.06em cocoa 48%.
│                                      │ ← Numbers 22pt DM Sans Med tabular
│                                      │   cocoa 100%.
│                                      │
└──────────────────────────────────────┘
```

Below: chapter sections (Ch I-V) with the existing chapter header pattern (roman numeral + italic punch-word title) — same as today, but the numeral typography in each chapter's data gets retreated to the new system.

**Killed from current Becoming:**
- Second masthead ("becoming vol. xii ♥")
- "the june issue" eyebrow
- IN THIS ISSUE TOC block (5 chapter rows + fake page numbers)
- Subhero "you said you wanted to build the body you want. this is the proof."
- Sunday Feature card (hidden on Becoming; deferred to dedicated weekly recap surface in next phase — Sunday push currently still points at Becoming, accepted regression until recap ships)

---

## Home tab reorder (cohort data-driven)

JeniMethod lesson completion **75%+** vs workout completion **23%** → workout-as-hero is misaligned. Cohort wants LEARN + LOG more than DO.

1. **Hero slot** → JeniMethod lesson of the day. Tappable card, today's title (italic punch word), 2-min read estimate. Lessons are the retention engine.
2. **Health anchor slot** → weight log + steps pulse, side-by-side. Single-tap log. Last-7 trend behind number. Fixes weight-logging-near-zero by moving the ask to the highest-traffic surface.
3. **Utility nav** → workout + breathwork as peer entries. Both clear 75%+; workout becomes a *choice*, not the assumption.
4. **Future rails** → food camera, body scan, expanded JeniMethod library.

Expected funnel impact (iOS UX brief):
- Trial conversion +30-50% relative (Cal AI's home redesign Q3-2024 = +41%, Lasta chart-as-hero D7 +28%)
- Workout completion likely UP in absolute terms despite losing hero slot — users who *choose* workout are higher-intent.
- Lesson + weight-log frequency carries D7 → D7 carries trial conversion → trial conversion carries the business.

---

## What's deferred to next phase

- **Sunday Feature dedicated weekly recap surface** — its own design brief. Needs masthead, long-form barrier reflection, plank Mastery Curve, BMI banding context, share-card export. This is where the editorial register survives once a week, accessed via Sunday 7pm push.
- **3-tier cocoa Palette tokens** — added as named tokens this phase, but not all surfaces migrate yet. Becoming + Home migrate; everything else stays on the old 2-tier scale until next polish pass.

---

## Unified principle

> **Editorial is a retention frame, not an acquisition frame. Magazine dies on the daily dashboard, lives on the weekly recap.**

## Cited briefs (parallel + follow-up rounds)

- `becoming_home_redesign_briefs_2026_06_06.md` — first round (The Row, Miu Miu, Cal AI, iOS UX)
- Second round (this synthesis): Whoop/Apple Health utility-density, Aesop/Sweet July warm-minimal, Typography systems specialist
