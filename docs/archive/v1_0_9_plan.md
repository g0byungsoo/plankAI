# v1.0.9 plan

Status: planning · 2026-06-08
Previous: v1.0.8 build 15 (TestFlight, food-rail rewrite)
Target ship: TBD after v1.0.8 cohort signal

## Why this version

v1.0.8 shipped a complete food-rail rewrite — instant-freeze camera,
inline result carousel, real macro data, multi-slide share, gallery
upload parity. It's the first build where the food rail feels like
a product, not a prototype.

v1.0.9 should NOT be another food-rail rewrite. The wedge now is
either:
1. Convert the camera-only food moment into a sustained daily habit
   (retention features, JeniMethod, notifications)
2. Deepen the food rail into "real nutrition tracking" (USDA join,
   true micronutrients on slide 2, daily macro dashboard)
3. International users (Azure regional EF, latency improvements)
4. Onboarding v2 Phase B (aesthetic upgrade — gated behind
   onboarding_v2_enabled)

Pick 2-3 themes. Don't try all four.

---

## Theme A — Food rail deepening (medium-large)

**Premise**: the founder explicitly asked for "real data" on slide 2.
v1.0.8 wired calories + macros to real today-totals but the
Vitamins/Minerals/Amino-acids rows are still derived from macro
proxies. Slide-2 wellness scores (Energy/Mood/Skin/Focus) also use
proxy math.

**Scope:**
- USDA FDC join for per-item micronutrient data (the legacy
  AppSideNutritionLookup path is already in the codebase but disabled
  for v1.0.7+ — we'd revive it for the carousel data layer)
- Per-item Vitamins[], Minerals[], AminoAcids[] returned alongside
  macros
- NutrientsBreakdownCard rewires to real micronutrient % targets
- Optional: a "see full breakdown" sheet from slide 2 showing every
  nutrient with target %

**Risks:**
- USDA API can be slow/unreachable (we removed this path partly for
  latency reasons — see EF index.ts header)
- More schema migration on FoodLogPersister.Entry
- 2-3 days of work minimum

**Pre-req:**
- Need to decide which nutrient set is cohort-relevant. The
  Berding/Pullar/Adan citations in v1.0.8's lifestyle scores point to
  ~12 specific micronutrients (B-complex, omega-3, iron, magnesium,
  zinc, vit D, vit C, vit E, calcium, fiber-soluble, polyphenols).
  Most have research-backed cohort relevance.

---

## Theme B — Retention features (medium)

From [[project-retention-features]] memory: notification system + a
JeniMethod swipe card on Home that surfaces past/today/locked-future
lessons engagement-gated.

**Scope:**
- 4 new local notification categories with frequency caps + voice-
  locked copy (no scale-shame, no streak-loss threats)
- JeniMethod Home card with horizontal swipe between past lesson /
  today lesson / locked-future preview
- Engagement gating — lessons only unlock once prior days complete
- AnalyticsManager hooks for lesson-tap rate, notification-tap rate

**Risks:**
- Notification copy needs the voice-lock review (Berding-Pullar-Adan
  rigor for what FIRES, not just what's said)
- Engagement-gate logic interacts with the EngagementDayCalculator
  (already derived, no schema change needed)

---

## Theme C — Azure regional EF (small-medium)

From deferred v1.0.8 plan + memory.

**Scope:**
- Azure OpenAI deployment in Japan East + Sweden Central regions
- Region-routing EF wrapper that picks the closest deployment based
  on Supabase request headers (CF country code)
- Fallback to OpenAI direct if Azure region is down

**Risks:**
- $300 Azure credit covers ~1 month of cohort scan volume
- Need to monitor Azure quota separately
- 2 days of work + ongoing ops

**Why now:**
- US trial → paid conversion gap (memory: us-paywall-conversion-gap)
- Asian users especially slow on the current us-west-2 EF
- Cohort acquisition is broadening (Philippines, UK per launch
  findings memory)

---

## Theme D — Onboarding v2 Phase B (medium)

From [[project-onboarding-v2-plan]] memory: "Phase A SHIPPED
2026-05-31; Phase B aesthetic upgrade next; gated behind
onboarding_v2_enabled."

**Scope:**
- Visual polish pass on the 9 new credibility-grade screens (Phase A
  added the content; Phase B does the design)
- Coquette sticker scatter, italic-Fraunces hero copy, video micro-
  intros
- Live AB test against onboarding_v2_enabled flag — measure pass-
  through + paid conversion delta

**Risks:**
- Onboarding has 200+ teardown data behind it — easy to over-tweak
- Need PostHog A/B framework wired (may already be there)

---

## Cleanup carried into v1.0.9

- [x] Strip food-vision STEP_N debug logs (done in this commit)
- [x] Strip iOS gallery picker debug prints (done in this commit)
- [ ] Bracket animation polish (deferred from v1.0.8; minor)
- [ ] Flash button SF Symbol icon-only states (minor)
- [ ] Bake brand cherries + flower_3d sticker assets into PlankFood
      bundle (currently using emoji fallback in MealSummaryCard +
      JeniEvaluationCard — switch to Image asset)

---

## Recommended starter pack (founder picks)

Two themes max for first iteration:
- **Theme A (micronutrients)** + **Theme B (retention)** — deepens
  the existing product without external infra
- **Theme C (Azure)** + **Theme B (retention)** — international +
  retention; defers the micronutrient lift to v1.0.10
- **Theme D (onboarding)** + **Theme B (retention)** — funnel
  improvements top-of-funnel + retention down-funnel

Theme A alone is the riskiest standalone (lots of work, no retention
win). Theme C alone is the cheapest (smallest cohort impact).

Pick when cohort signal from v1.0.8 lands (probably 7-14 days).

---

## Version bump

- MARKETING_VERSION: 1.0.8 → 1.0.9
- CURRENT_PROJECT_VERSION: 15 → 16 (continuing the sequence; Apple
  requires monotonic builds within the same release stream)
- EF stays on the v1.0.8 deployed version unless theme requires it
