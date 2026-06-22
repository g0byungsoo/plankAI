# Home + Becoming redesign — UX2 independent brief

> Second-voice UX brief for JeniFit v1.0.7 Home + Becoming. Independent of the parallel UX1 brief. Written for synthesis, not consensus.
> Date: 2026-06-06.

---

## Executive recommendation (1 paragraph)

**Push back hard on the founder's "calories matter most" hypothesis as a Home framing — but agree completely on the diagnosis that the current Home feels bolted-on.** The fix is not to elevate calories; it is to collapse the *five-card scroll* into a **single above-the-fold "Today" hero** that fuses three rails (food, movement, weight trend) into one composed surface, then below the fold offer a *single "next action" cocoa-pill* (lesson, workout, or breath, whichever the model picks). The Cal-AI-trained cohort already has a calorie tracker — what they don't have is a *program* that tells them, in 4 seconds at app open, **what today is for**. Becoming should be re-narrated from a calendar story ("your week / what you ate / how you moved") into a **becoming story** ("where you are → what's shifting → what you did → who you're becoming"). Identity, not calendar. Three structural moves: (1) Home above-the-fold = identity sticker + trend pill + cocoa CTA. (2) Replace 5 stacked cards with a **bento "Today"** tile + single next-action. (3) Becoming = 4 chapters with a *future-facing* opener, not a calendar opener. Everything else (chrome, voice, sticker scatter) is already correct and should not be touched.

---

## 1. The "bolted-on" diagnosis — founder is right, but for the wrong reason

The founder's intuition is correct. The current Home reads as bolted-on. But the diagnosis isn't "food was added late" — it's that **every slot is the same weight class** and the *order is calendar-arbitrary rather than journey-arbitrary*.

### Concrete evidence from the current composition

```
┌─ Cocoa note (greeting)           ← chrome: cocoa pill, ~80pt
├─ Food card (ring + weekly)       ← chrome: scrapbook, ~220pt
├─ JeniMethod card (today's)       ← chrome: scrapbook, ~180pt
├─ StepsPulseTile                  ← chrome: scrapbook half-width
├─ BreathworkHomeCard              ← chrome: scrapbook half-width
└─ Workout card (demoted)          ← chrome: scrapbook lite, ~140pt
```

Three things make this feel like a rail collage, not a program:

1. **Five hero-class surfaces with no clear primary.** Mobile UX research in 2026 is consistent: a home screen should answer "what is today for?" in a single glance, and carousels/long stacks suffer banner-blindness past the first card ([Memorable.design 2026](https://memorable.design/hero-section-examples/), [Attention Insight 2026](https://attentioninsight.com/above-the-fold-testing-improving-cta/)). With five equal-weight cards, none earns the hero slot — so the cocoa greeting (which is *chrome*, not action) ends up doing it by accident.
2. **The food card is the only data-rich tile, which makes it look like a feature graft.** Steps shows a pulse. Breath shows a CTA. Workout shows a CTA. Method shows a lesson title. Food shows a *ring + a weekly average + an evening-review trigger*. It's a 3-piece data-visualization tile sitting in a row of action tiles. That's the bolted-on signal users feel.
3. **The calendar story ("today's lesson, today's workout, today's steps, today's food") fragments identity.** Cal AI nails this by having *one* outcome on Home: calories left ([Screensdesign 2026](https://screensdesign.com/showcase/cal-ai-calorie-tracker)). Noom nails it by having *one* outcome: today's task list ([RevenueCat web-to-app teardown](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel/)). JeniFit currently has five.

### Counter to the founder framing

> "Calories matter most for WL Gen-Z program."

For the *outcome*, yes. For the *Home* of a program that includes lessons, breath, plank, steps, and weight — no. If calories are the hero, JeniFit is competing with Cal AI on Cal AI's home turf, and the [MyFitnessPal April 2026 redesign backlash](https://platelens.app/blog/myfitnesspal-alternatives-2026) shows that "logging-front-and-center" is no longer felt as care — it's felt as obligation. The cohort *just left MFP*. Don't rebuild it.

The right framing: **calories are the input the program reads. The Home shows the program reading them back to her as identity.**

---

## 2. Home hero priority — identity + trend, not calories

Three camps to pick from:

| Camp | Reference | Strength | Failure mode for JeniFit |
|------|-----------|----------|--------------------------|
| **Daily action** | Cal AI, Noom | Zero ambiguity about what to do | Becomes a calorie calculator; loses program voice |
| **Trend** | MacroFactor, Happy Scale | Honest, anti-obsession, GLP-1-safe | Cold for beginners; reads as "dashboard" not "coach" |
| **Identity** | Become, Atoms, Headway | Casts every action as a vote; high LTV | Empty until evidence accumulates; needs 7+ days |

### The 2026 evidence on which wins for this cohort

- **GLP-1 era killed the daily-calorie hero.** ~37% of Gen-Z report intent to use GLP-1s ([eMarketer 2025](https://www.emarketer.com/content/gen-z-says-weight-loss-drugs-part-of-their-new-year-s-resolutions)). The dominant 2026 vocabulary is *food noise / satiety / permission / fits* ([Nature 2025 food noise paper](https://www.nature.com/articles/s41387-025-00382-x), [Nutrisense 2026](https://www.nutrisense.io/blog/food-noise)). A daily-calorie hero re-anchors the user in the cognitive load the GLP-1 generation defines themselves *against*.
- **Trend-as-hero is the rising pattern, but cold-start fails the first-week user.** MacroFactor's expenditure trend is universally praised by experienced trackers ([Mealift 2026](https://www.mealift.app/blog/macrofactor-review)) but is widely cited as intimidating for newer users ([Nutrola 2026](https://nutrola.app/en/blog/apps-like-macrofactor-but-simpler)).
- **Identity-as-hero is winning long-LTV cohorts.** Become and Atoms have built entire products on the James Clear "cast a vote for who you're becoming" frame ([getbecomeapp.com](https://getbecomeapp.com/), [Atoms](https://atoms.jamesclear.com/)). Insight Timer's 2026 resolution feature displays *the user's stated identity goal* on Home as the first thing they see ([Insight Timer blog 2026](https://insighttimer.com/blog/insight-timer-launches-new-years-resolution-and-intention-setting-features-with-ai-recommendation-engine/)).
- **JeniFit's brand IS identity.** "Becoming" is already the tab name. "Becoming-ritual" is locked paywall copy. The brand voice is *italic-Fraunces on punch words*. The product has already pre-committed to identity — Home should land the punch.

### The recommendation

**Home hero = identity line + 7-day trend pill + one next-action cocoa CTA.** Single composed surface. ~340pt tall. Above the fold.

```
┌──────────────────────────────────────────┐
│   *becoming* lighter ♥                   │  ← Fraunces identity line (Q140 goal-restated)
│                                          │
│   -2.3 lb · 14 days                      │  ← trend pill (EMA), tap → Becoming
│   ▁▂▃▃▂▁▁  ⌃ steady                     │  ← micro-sparkline, label uses ↑/↓/⌃ steady
│                                          │
│   [ open today ♥ ]                       │  ← cocoa pill, single CTA
└──────────────────────────────────────────┘
```

This frame works *even on day 0* (when there's no trend) because the identity line + CTA carry it. The trend pill is a progressive-disclosure earned reward — once data exists it fills in.

---

## 3. Becoming chapter narrative — disagree with current calendar order

Current chapters: `your week → what you ate → how you moved → what's changing → what's worked`.

This is a *calendar story* (week, ate, moved) interrupted by a *journey story* (changing, worked). The seams show. The 2026 research-led approach for identity-driven WL apps is the inverse — **start with the future-self, end with the receipts**.

### Proposed chapter order

1. **where you are** — identity hero + EMA trend + adaptive home subtitle (already shipped; promote to chapter 1). Anchors the user in *who she is right now* without shame copy. Pulls from Q140 + Q111 + weight trend. Replaces "your week" which is calendar-anchored.

2. **what's *shifting*** — barrier-resolved card + plank mastery curve + (NEW) food-noise self-report 1-tap pill. This is the *change* chapter; it captures qualitative + mastery + relationship-with-food. Pulled forward from chapter 4 because it is the highest-emotional-payoff content and should not be buried.

3. **what you *did*** — 7-day food bars + steps + breath + session count. Calendar evidence, but reframed as *evidence of the becoming*, not as a recap. Single chapter, not two. Calorie language stays absent here per locked voice.

4. **what's *worked*** — NSV wins, lesson streak, longest plank hold, weight-low-marker. Receipts chapter. Ends the scroll on a win.

### Why this re-ordering matters

- **Identity opener** matches the Become/Atoms/Headway 2026 playbook (`cast a vote for who you're becoming` — [getbecomeapp.com](https://getbecomeapp.com/)).
- **Shifting before doing** front-loads the qualitative change (barrier resolution, mastery curve) which is what *retains* — users open Becoming to feel something, not to audit ([Smashing Magazine on streak psychology 2026](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/)).
- **Collapse "ate" + "moved" into one chapter** removes the cognitive whiplash of the current 5-chapter scroll. Five chapters is a recap. Four chapters with a narrative arc is a story.
- **"Where you are → what's shifting → what you did → what's worked"** is a complete past-tense arc that lands the user at receipts. This is the structure CalAI users *say* they wish CalAI had ([Cal AI review 2026](https://www.trygaya.com/review/cal-ai-review) — "feels like a calculator").

### Push-back on the founder's framing

Don't add a "calories" chapter to Becoming. The chapter `what you ate` already does the food work. Adding kcal-burned anywhere on Becoming reactivates the burn/earn frame the project has spent four pages explicitly killing.

---

## 4. Visual hierarchy unification — collapse the chrome zoo

Current chrome zoo (observed):
- Scrapbook chrome (24pt corner, 1.5pt cocoa border, hard offset shadow)
- Cocoa-fill pills (CTAs)
- Soft pills (informational, no border)
- Cocoa note (greeting card — pure cocoa fill)
- Sticker scatter (peripheral)

This is too many chrome systems for one Home. The 2026 best-practice is **two surface tiers, max** ([thisisglance 2026](https://thisisglance.com/learning-centre/how-do-i-create-consistent-visual-hierarchy-in-mobile-apps)).

### Unified system (proposal — KEEPS the brand)

| Surface | Use | Chrome |
|---------|-----|--------|
| **Hero** | Today, identity, primary trend | Cream fill, 28pt corner, 1.5pt cocoa border, hard offset shadow, italic-Fraunces headline |
| **Bento tile** | Steps, breath, lesson, workout, food (when below-the-fold) | Scrapbook chrome (24pt corner, 1.5pt cocoa border, hard offset shadow) |
| **Pill** | CTAs (cocoa fill) and metric labels (soft fill, no border) | Cocoa-fill OR soft-fill, never both shadow + border |
| **Sticker** | Periphery only, never inside hero | y2k 3D coquette sticker pack |

The cocoa note becomes *typography, not chrome* — the greeting renders as a line of italic-Fraunces directly on the cream background, not in a pill. This recovers the visual budget for the hero.

### Bento-as-secondary, not as Home pattern

2026 design research is loud about bento grids driving 23% faster task-completion and 35% longer dwell ([Senorit.de 2026](https://senorit.de/en/blog/bento-grid-design-trend-2025), [Studiomeyer 2026](https://studiomeyer.io/en/blog/bento-grid-layouts)). But bento is *not* a hero pattern — it's a secondary pattern. The Home should be **hero + bento**, not bento-all-the-way-down.

Becoming already uses bento. Home should mirror that *only below the fold*.

---

## 5. Retention mechanics on Home — beyond the food camera

Five 2026 retention patterns ranked for THIS cohort:

### Tier 1 — adopt
1. **Identity reinforcement on Home open.** First text the user sees is who-she-is-becoming, not what-she-must-do. Become and Atoms have made this a category-defining pattern; Insight Timer's 2026 resolution feature ships exactly this. Aligns with locked Voice signal #1 (italic-Fraunces punch word).
2. **Trend-pill that fills in over 7 days.** A small EMA sparkline that goes from "logging your first week ♥" → "−1.4 lb · 9 days ⌃ steady" earns the reward gradually. This is the *anti-Cal-AI move* — Cal AI shows the number; JeniFit shows the *direction*. Pattern reference: Happy Scale ([happyscale.com](https://happyscale.com/)) — built entirely around "the line goes down even when the scale won't budge."
3. **Adaptive next-action.** A single cocoa CTA whose copy and destination changes based on time-of-day + last engagement. Morning → lesson. Afternoon → log lunch. Evening → tomorrow-resets review. This is the "App adapts to User" 2026 pattern ([Abdul Aziz Ahwan 2026](https://www.abdulazizahwan.com/2026/02/beyond-the-glass-7-mobile-ui-trends-defining-2026.html), [thisisglance 2026](https://thisisglance.com/learning-centre/how-can-i-reduce-cognitive-load-in-my-app-interface)).

### Tier 2 — adopt with caveats
4. **Soft streak — engagement-day count, not loss-aversion streak.** Show "day 9 of *becoming*" not "9-day streak — don't break it!" The Smashing Magazine 2026 piece is explicit that streak-loss psychology crosses into dark-pattern territory for vulnerable cohorts ([Smashing 2026](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/), [UX Magazine 2026 hot-streak piece](https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame)). Locked Voice prohibits shame copy — a fire-emoji streak that "dies" violates it.

### Tier 3 — reject
5. **Variable rewards / spin-the-wheel / mystery unlocks.** Manipulative for WL cohort; user-base is already burnt out on MFP red bars and Cal AI promises. Brand voice signal "no fabricated stats" precludes any reward whose value isn't earned. ([The Brink 2026 on app dark psychology](https://www.thebrink.me/gamified-life-dark-psychology-app-addiction/))
6. **Social/leaderboard.** Anti-femvertising lock means no comparison to other women. Skip.

---

## 6. Luxury-coquette aesthetic read

Today the app reads **coquette warm + 70%** and **luxury minimal + 30%**. The imbalance shows up specifically on Home because the cards are doing all the work and the typography is doing none.

### What's missing for "always-keep-in-mind" clean & luxury

- **Whitespace above the hero.** Right now the cocoa greeting sits ~24pt below the safe-area top. Push that to ~72pt. Chanel/Tiffany composition is whitespace-first; the cocoa pill loses gravity when it crowds the top edge.
- **Type doing the brand work, not chrome.** Currently the chrome (scrapbook borders, sticker scatter) carries the brand. In a luxury composition the *typography is the brand* and the chrome retreats. The italic-Fraunces punch-word system is already locked — let it carry the Home hero unchaperoned. Move the sticker scatter farther into the periphery (Becoming chapter dividers, not Home hero edges).
- **Hierarchy of weight, not color.** The current cocoa-pill greeting + scrapbook food card creates two same-weight focal points. Resolve by making the identity line ~28pt italic-Fraunces with no chrome, and the trend pill ~14pt cocoa text on cream — different weights, same color. WCAG-AA palette is already locked; lean into one-color hierarchy.
- **Sticker restraint on Home, scatter on Becoming.** The scatter sticker scatter is the brand's spine — but it competes with the Home CTA for attention. Move it to Becoming chapter dividers where it belongs narratively (*receipts of the journey*).

This is the "premium-restraint" frame from your locked feedback note — applied to *composition*, not to *removing* the coquette layer.

---

## 7. Concrete redesign proposal

### Home — slot by slot

```
┌──────────────────────────────────────────┐ ← safe area + 72pt
│                                          │
│   morning, jeni ♥                        │  ~20pt Fraunces italic — greeting, NO chrome
│                                          │
├──── HERO (cream, 28pt corner, 1.5pt cocoa border, hard shadow) ─────┐
│                                          │
│   you're *becoming* lighter ♥            │  ~28pt Fraunces, italic on punch word
│                                          │
│   -2.3 lb · 14 days                      │  ~14pt cocoa text
│   ▁▂▃▃▂▁  ⌃ steady                       │  micro-sparkline + label
│                                          │
│   [   open today ♥   ]                   │  cocoa pill CTA, ~52pt tall
│                                          │
└──────────────────────────────────────────┘  ~340pt total

   ↓ ~32pt gap

┌────────── BENTO (below-fold) ───────────┐
│ ┌────────┐ ┌──────────────────────────┐ │
│ │ steps  │ │  today's plate           │ │   ← Steps (small, ~120pt) + Food (wide, ~180pt)
│ │ 7,420  │ │  3 items · ~1,180 kcal   │ │      Food shows 3 sticker-icon thumbnails, NOT a ring
│ │  ▮▮▮▯  │ │  [ snap a meal ♥ ]       │ │      kcal in *secondary* type, never the headline
│ └────────┘ └──────────────────────────┘ │
│ ┌──────────────────────────┐ ┌────────┐ │
│ │  today's lesson          │ │ breath │ │   ← Lesson (wide) + Breath (small)
│ │  day 9 · ~3 min          │ │ ~2 min │ │
│ └──────────────────────────┘ └────────┘ │
│ ┌────────────────────────────────────┐  │
│ │  today's session  ·  15 min plank  │  │   ← Workout (full-width, demoted footer)
│ └────────────────────────────────────┘  │
└──────────────────────────────────────────┘
```

**Heights**: hero ~340pt, gap 32pt, bento ~520pt total. Total Home ~890pt — fits on iPhone 14/15/16 plus scrollable buffer for the workout footer.

**Why this works**:
- Above-the-fold = 1 question answered ("who am I becoming, and where am I?"), 1 action.
- Food card *demoted* from hero to bento — addresses the bolted-on diagnosis without making calories hero.
- Steps and breath stay where they earned their place ([locked steps note](feedback_steps_feature)).
- Workout footer position is *deliberate* — Gen-Z WL cohort opens for food/identity, not for a workout; recent data ([lesson engagement signal note](feedback_lesson_engagement_signal)) confirms workouts complete at 23% vs lessons 75%+.

### Becoming — chapter by chapter

```
Chapter 1 — where you are                      ~280pt
┌──────────────────────────────────────────┐
│  you, this week ♥                        │
│  -2.3 lb · *steady*                      │
│  [identity hero, EMA trend, adaptive    │
│   subtitle: "barrier-tagged: time"]      │
└──────────────────────────────────────────┘

Chapter 2 — what's *shifting*                  ~420pt
┌─ barrier-resolved card ──────────────────┐
│ "time" — 4 sessions in 12 days ♥         │
└──────────────────────────────────────────┘
┌─ plank mastery curve ────────────────────┐
│ 42s → 1m18s · 87% of beginner norm       │
└──────────────────────────────────────────┘
┌─ NEW: food-noise self-report (1-tap) ────┐
│ "how loud was food this week?" ♥         │
│ [ quieter · same · louder ]              │
└──────────────────────────────────────────┘

Chapter 3 — what you *did*                     ~360pt
┌─ today's plate week (7 bars) ────────────┐
│ ▁▂▃▂▃▂▁  ← intake bars, no red over     │
└──────────────────────────────────────────┘
┌─ moved this week ────────────────────────┐
│ steps  ●●●●●○○                           │
│ breath ●●○○○○○                           │
│ sess.  ●●●●○○○                           │
└──────────────────────────────────────────┘

Chapter 4 — what's *worked*                    ~320pt
┌─ NSV wins (carousel of 3) ───────────────┐
│ ♥ slept through                          │
│ ♥ no afternoon crash                     │
│ ♥ tighter waistband                      │
└──────────────────────────────────────────┘
┌─ receipts ───────────────────────────────┐
│ longest plank: 1m18s ♥                   │
│ low-water mark: 138.4 lb ♥               │
│ day 14 of *becoming* ♥                   │
└──────────────────────────────────────────┘
```

**Heights**: ~1,380pt total scroll, broken by 3 sticker-scatter chapter dividers (sticker layer lives here, NOT on Home).

---

## 8. What to KEEP — equally important

These already work and should not be touched. If the parallel UX1 brief proposes changing any of these, push back:

1. **Italic-Fraunces punch word signal.** Brand spine. Not negotiable. The proposed redesign leans harder on it.
2. **Cocoa pill CTA.** Single-color CTA system is locked and correct. The recommendation here is to use *fewer* of them (one per surface), not redesign them.
3. **Scrapbook chrome (24pt corner, 1.5pt cocoa border, hard offset shadow).** Brand chrome. Keep on bento tiles and on the hero. Just stop using it on greeting + chrome that isn't a tile.
4. **Sticker scatter (coquette y2k pack).** Locked aesthetic. Move *placement* to Becoming chapter dividers, do not remove.
5. **EMA-smoothed weight trend.** Anti-shame, Helander-2014-grounded, post-Ozempic-safe. Becomes the trend pill in the new hero.
6. **Adaptive home subtitle (barrier/experience tagged).** Already research-led. Pulls into Becoming chapter 1.
7. **Steps + Breath + Plank composition.** Three rails are correctly modeled as small-anchor (steps), short-CTA (breath), mastery-track (plank). Keep their internals.
8. **Becoming research modules** (WHO Activity Ring, Goal Pace, BMI banding, Bandura mastery curve). Internals are gold; the chapter *order* is what changes.
9. **Anti-femvertising lock** — no body imagery, no before/after, no shame copy. Don't let any retention-pattern proposal break this.
10. **Plank check-in screen** (McGill Waterloo norms, last-hold pill). Untouched.

---

## Closing — one more independent take

The single biggest risk to this redesign is the founder's correct-feeling-but-wrong instinct that the answer to "bolted-on" is "make food bigger." It isn't. The answer to bolted-on is *promote the program to hero, demote every rail (including food) to bento*. Cal AI is winning the calorie hero. JeniFit's wedge is **becoming**, and *becoming* lives in identity copy + trend honesty + a single next-action, not in a 5-card calorie-led stack. Make the cohort feel like the app *reads them back to themselves* the moment it opens — and the calorie tracker becomes a tool inside the program rather than the program itself.

---

## Sources

- [Cal AI — Calorie Tracker UI Breakdown (Screensdesign 2026)](https://screensdesign.com/showcase/cal-ai-calorie-tracker)
- [Cal AI Review 2026: Is It Worth It? Honest Analysis (Gaya)](https://www.trygaya.com/review/cal-ai-review)
- [Best Apps for Weight Loss 2026 (Human Fuel Guide)](https://humanfuelguide.com/en/articles/tools/best-apps-for-weight-loss-2026)
- [Best Weight Loss App for Women in 2026 (Fitia)](https://fitia.app/learn/article/best-weight-loss-app-for-women/)
- [MyFitnessPal Alternatives 2026: Why Users Are Switching After the Redesign (PlateLens)](https://platelens.app/blog/myfitnesspal-alternatives-2026)
- [MyFitnessPal's New Today Screen & Progress Tab (MFP Blog)](https://blog.myfitnesspal.com/myfitnesspal-today-screen-progress-tab-update/)
- [MacroFactor Review 2026 (Mealift)](https://www.mealift.app/blog/macrofactor-review)
- [Apps Like MacroFactor But Simpler (Nutrola 2026)](https://nutrola.app/en/blog/apps-like-macrofactor-but-simpler)
- [Happy Scale — trend-line tame-the-scale framing](https://happyscale.com/)
- [Inside Noom's Web-to-App Onboarding Funnel (RevenueCat 2025)](https://www.revenuecat.com/blog/growth/web-to-app-onboarding-funnel/)
- [Noom Product Critique: Onboarding (The Behavioral Scientist)](https://www.thebehavioralscientist.com/articles/noom-product-critique-onboarding)
- [Become — Build Habits That Prove Who You Are](https://getbecomeapp.com/)
- [Atoms — Official Atomic Habits App (James Clear)](https://atoms.jamesclear.com/)
- [Insight Timer Launches Resolution + Intention-Setting Features 2026](https://insighttimer.com/blog/insight-timer-launches-new-years-resolution-and-intention-setting-features-with-ai-recommendation-engine/)
- [Insight Timer minimalist interface (DesignRush)](https://www.designrush.com/best-designs/apps/insight-timer)
- [Designing A Streak System: The UX And Psychology Of Streaks (Smashing Magazine, Feb 2026)](https://www.smashingmagazine.com/2026/02/designing-streak-system-ux-psychology/)
- [The Psychology of Hot Streak Game Design (UX Magazine 2026)](https://uxmag.com/articles/the-psychology-of-hot-streak-game-design-how-to-keep-players-coming-back-every-day-without-shame)
- [How Streaks and Daily Rewards Engineer Habit Loops (Bootcamp/Medium)](https://medium.com/design-bootcamp/streaks-and-daily-rewards-as-habit-forming-systems-dab7f5a34539)
- [The Dark Psychology Behind Your Everyday Apps (The Brink 2026)](https://www.thebrink.me/gamified-life-dark-psychology-app-addiction/)
- [Food noise: definition, measurement, future directions (Nature, 2025)](https://www.nature.com/articles/s41387-025-00382-x)
- [What Is Food Noise (Nutrisense 2026)](https://www.nutrisense.io/blog/food-noise)
- [Gen Z says weight-loss drugs are part of New Year's resolutions (eMarketer)](https://www.emarketer.com/content/gen-z-says-weight-loss-drugs-part-of-their-new-year-s-resolutions)
- [Guilty Displeasures? How Gen-Z Women Perceive (In)Authentic Femvertising Messages](https://www.tandfonline.com/doi/full/10.1080/10641734.2024.2305753)
- [How rise of Ozempic is reversing progress on body positivity (Irish Times 2026)](https://www.irishtimes.com/life-style/people/2026/01/17/how-the-rise-of-ozempic-is-reversing-the-progress-on-body-positivity/)
- [Beyond the Glass: 7 Mobile UI Trends Defining 2026 (Abdul Aziz Ahwan)](https://www.abdulazizahwan.com/2026/02/beyond-the-glass-7-mobile-ui-trends-defining-2026.html)
- [How Do I Create Consistent Visual Hierarchy in Mobile Apps (thisisglance)](https://thisisglance.com/learning-centre/how-do-i-create-consistent-visual-hierarchy-in-mobile-apps)
- [How Can I Reduce Cognitive Load In My App Interface (thisisglance)](https://thisisglance.com/learning-centre/how-can-i-reduce-cognitive-load-in-my-app-interface)
- [Bento Grid CSS Tutorial — Apple-Style Layout 2026 (Senorit.de)](https://senorit.de/en/blog/bento-grid-design-trend-2025)
- [Bento Grid Layouts 2026: Why Apple + Google Use Them (Studiomeyer)](https://studiomeyer.io/en/blog/bento-grid-layouts)
- [Top Hero Section Examples for 2026 (Memorable.design)](https://memorable.design/hero-section-examples/)
- [Above the Fold Testing — CTA Visibility (Attention Insight 2026)](https://attentioninsight.com/above-the-fold-testing-improving-cta/)
- [2026 UX/UI Design Trends (Tanmay Vatsa / Medium)](https://medium.com/@tanmayvatsa1507/2026-ux-ui-design-trends-that-will-be-everywhere-0cb83b572319)
