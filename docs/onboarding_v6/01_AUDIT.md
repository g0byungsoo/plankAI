# Onboarding v6 — Current-State Audit

2026-08-02. Substrate: the founder's 62-frame device walk of the live
1.2.0(27) build (`jeni-onboarding/`, IMG_8798–8861, walked 2026-08-01
as "ben", male 6'2" 204→196 lb, generalWL path) + a complete read of
`PlankApp/Views/OnboardingV5/` (16 files, ~5.2k lines),
`OnboardingRevealView.swift` (2.9k), `BuildingPlanLoadingView.swift`,
`RatingSentimentScreen.swift`, `PaywallView.swift` (1.7k), and a fresh
sim build. This file is FACTS ONLY — the design answers live in
`00_DIRECTION.md`.

## 1. The flow as walked (map)

Acts (OV5Flow router, generalWL path; cohort branches swap 1:1):

| # | act | beats | archetypes |
|---|-----|-------|-----------|
| I | her arrival | welcome (device-demo carousel) → anti-shame teach → outcome → attribution → credibility bridge → name | collage · teach · question ×2 · bridge · bespoke |
| II | her food story | glp1Status (+branch: phase/rhythm/shotDay/muscleMath · stopWindow/return/regainTruth · agency) → foodRelationship → foodNoise teach → preEat teach → SNAP DEMO → cadence → priorWin → cuisine chips → dietary → supports → receipt | question ×~8 · teach ×2–3 · demo · multi ×2 · bridge |
| III | the numbers, gently | bridge → movement → sleep → stress → gender → age/height/weight rulers → trend → direction → goal ruler → targetReframe teach → nsv → careBridge → medication → SAFETY GATE (pregnancy + SCOFF) → receipt | bridge ×2 · question ×6 · ruler ×4 · teach · multi · bespoke |
| IV | the part nobody asks | identity photo grid → hormonal → startedOver → dataMirror receipt → fears ×3 (strike-the-fear) → whyItCameBack (rebound curve) → receipt | photoGrid · question ×2 · bridge ×2 · statement ×3 · teach |
| V | almost hers | herFile dossier → signature (consent ×3) → healthKit → hold-to-build | bespoke ×4 |
| reveal | (fullScreenCover) | receipt-tape loader (ATT fires at 30%) → pace picker → projection (6 proof tiles + curve) → first week → reviewGate (once/install) → fear resolution → commitment ritual → nudge ask | — |
| wall | PaywallView | headline + promise chart + 3 tier rows + authority line + reclaim row + guarantee/renewal + keep CTA | single screen, above-the-fold |

~46 question beats + 8 reveal beats + the wall. The founder's walk
ends at the nudge ask — no wall frames in the capture set (IMG_8818,
8845 deleted; the wall was never shot).

## 2. Visual composition census

Of 62 walked frames:
- **~52 frames (84%) are type-only cream screens** sharing ONE
  composition: caps eyebrow → centered italic-serif question →
  hairline rows / plain paragraphs → dark pill CTA.
- Visual moments, complete list: device-demo welcome (3 frames), snap
  demo (3), identity photo grid (1), rebound curve (1, small),
  HealthKit rings mini-card (1), first-week it-girl cutout (1),
  rating heart (1, off-law — see §3), notification banner mock (1).
- Longest unbroken type-only runs: numbers act beats 22–32 (11
  consecutive), post-demo food beats 16–21 (6).
- The four rulers are the strongest recurring interaction (tick rail,
  serif digit-roll pill, rose delta band, live weeks math) — they
  carry the numbers act almost alone.
- Act structure is legible in the chrome (5-segment hairline + act
  eyebrow) but almost nothing else changes per act — no per-act
  visual signature beyond copy register.

The reveal — the conversion peak — is visually THINNER than the quiz:
loader = headline + 2pt bar + caption lines; "your plan, ready" =
headline + button on empty cream; projection = the 6-tile stat card
with the CURVE BELOW THE FOLD (founder frame IMG_8856 shows tiles
only); pace picker = three plain cards. The single most persuasive
object in the funnel (her curve) requires a scroll to see.

## 3. Defects found (all verified in code)

**P0 — stale product truth on the projection.** The proof tiles sell
"5-min plank a day" (eyebrow "ritual") and "14-day becoming arc"
(eyebrow "method") — D74-era (v1.0.7) artifacts. The shipped product
composes a checklist day from CarePlanEngine; there is no daily plank
ritual and no 14-day arc contract. The reveal promises a product that
no longer exists, one beat before the wall
(`OnboardingRevealView.swift:1478-1495`).

**P0 — "jenifit" brand strings still user-visible.** The 1.2.0 sweep
missed: `RatingSentimentScreen.swift:42` ("enjoying jenifit so
far?" — renders pre-wall in the reveal's reviewGate),
`NudgeNotificationBanner.swift:50` (the mock banner's app name — the
notification preview one beat before the wall says "jenifit"),
`BecomingDayCard.swift:74`, `SundayCard.swift:165`,
`LastNightSleepCard.swift:421,508` (in-app, lower priority).

**P1 — heart ornaments on the reveal path.** The voice pass retired
hearts app-wide; the pre-wall review gate is a 240pt breathing
`sticker_heart_glossy` bloom (`RatingHeartBloom`), and the welcome
scatter includes `heartGlossy` (`OV5Collage.swift:38-40`). Welcome is
earned-moment #1 (scatter allowed) but the heart asset specifically
contradicts the retired-hearts law; the rating bloom is the largest
heart in the shipping app.

**P1 — dead italic on the welcome headline.** Line 2 passes
`italic: ["simple."]` but the string is "made around real days." —
the punch word never renders; the approved lockup ships without its
italic beat (`OV5Collage.swift:84`).

**P2 — paywall stickers are pre-voice-pass ornaments.** The bow
(`sticker_bow_iridescent`) rides the money headline and the flower
(`sticker_flower_3d`) blooms at the curve terminus. The voice pass
converted rose-ornament slots to the dose-dot / ink JeniMark seal
elsewhere; the wall kept its coquette pair.

**P2 — "an estimate, not a promise." floats loose** under the date
tile at 10pt inside a 130pt-wide column (IMG_8856) — honest line,
orphaned placement.

**P2 — ATT fires at ~30% of the loader bar** (`BuildingPlanLoadingView
.swift:354`), a system dialog inside the purchase corridor at the
reciprocity peak. (Placement is an attribution-vs-conversion
trade-off — founder decision; see 00_DIRECTION.)

**Observations, not defects:** the male-walker path renders "her
table" / "JENI · HER PLAN" / "sign her in" (deliberate — the product
is she/her-voiced for its audience); "free to start." rides the
welcome CTA above a hard wall (true — the quiz is free — but worth a
conscious keep/kill); STATE.md §2 still says "3-day trial on annual +
quarterly" while the shipped wall is the no-trial keep wall (doc rot,
fix in STATE).

## 4. What is already strong (preserve list)

- **The typed machine** (OV5Step/OV5Router/OV5Store): pure-function
  routing, canonical-key writes at answer time, resume-safe,
  cohort-branch-safe. Untouchable architecture.
- **The interaction language**: cross-off strikethrough selects with
  auto-advance; tick rulers with haptic detents + live derived lines;
  strike-the-fear statements; act receipts that mirror answers;
  hold-to-build / hold-to-promise seals. This IS the brand.
- **Provenance discipline**: the loader narrates only live keys;
  causal receipts render only when the engine modifier actually
  fired; live StoreKit prices only, skeletons otherwise; save-%
  claims are checkable arithmetic on visible prices.
- **The safety layer as trust**: relocated pre-paywall gate (SCOFF +
  pregnancy + BMI + medication), access-for-all adapted plans,
  numeric suppression for ED/pregnant cohorts, "safety-screened
  before you started" receipt on the credibility strip.
- **The wall's honesty mechanics**: billed-today on the row + CTA +
  receipt line; renewal date with year; per-week equivalents
  subordinate (3.1.2c); money-back line; Apple-sheet bridge line;
  reclaim row keeps the downsell reachable; sign-in door for
  reinstalled payers.
- **Give-back beats that already exist**: glp1 ackLine, regain-window
  ack, started-over mirror ("that's not failure. that's data."),
  hormonal care notes, weight "okay. that's the hard one",
  data-mirror receipt, fear-resolution beat answering HER named fear.
- **The commitment ritual** (WHEN/WHAT/TIME chip instrument → live
  serif replay → hold-to-promise) and the nudge ask carrying her
  literal promise as the banner payload.

## 5. Current wall anatomy vs the target anatomy

Shipped wall (one screen, fold-fit): headline ("{name}, your plan to
151 lb." + bow) → promise chart (56–80pt) → "pick how you start" +
three tier rows (year badged/pre-selected · quarter · week w/
annualized truth) → ACSM/safety line → guarantee + renewal →
"keep my plan · $X today" → Apple bridge line → terms/privacy.

Not present anywhere on the wall: social proof (zero), what's
included (zero), why-it-works mechanism (one caption line), her plan
summary (the headline number only), the identity/fear echoes
(closing line only, 10pt). The wall trusts the preceding reveal arc
to have done those jobs and keeps itself to a decision surface.
