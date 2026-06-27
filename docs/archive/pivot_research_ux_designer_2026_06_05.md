# JeniFit Diet-First Pivot — Design Research Brief

**Date:** 2026-06-05 · **For:** JeniFit (v1.0.7+ planning) · **Author:** Research agent #2 (UX/UI designer for Gen-Z women iOS apps), research-only.

---

## 0. Framing

The user's instinct is correct that the design lift for "diet-first weight-loss app" is not the same as "fitness app with a food tab." It's a different category in the App Store taxonomy, a different cohort search behavior, and a different visual-trust contract. Cal AI-trained Gen-Z women open a calorie app expecting a **camera-as-canvas** experience, a daily number anchor, and minutes-to-first-value. JeniFit is currently a coach app with a session-as-canvas experience, a 14-day lesson anchor, and a 90-second-first-value lesson card. Every pivot proposal below threads that needle: keep the brand chrome that earns trust with this cohort (coquette warmth, italic-Fraunces, scrapbook borders) while moving the **primary affordance** from "today's session" to "what are you eating right now."

The Launch v1.0.6 telemetry is the empirical kicker: workout completion 23%, lesson completion 75%+, weight logging near-zero, US trial conversion 7–14%. Workout-as-hero is misaligned with cohort intent.

---

## 1. Reference apps — visual + interaction teardown

### Cal AI — the cohort's reference point

- **App Store screenshot strategy**: opens with a **giant calorie number** on near-white background and a single food photo. Screenshot 2 = "scan a banana." Screenshot 3 = 7-day bar chart with "on track" green chip. No people, no coach.
- **Onboarding**: 25–35 screens, friction-heavy. Big bold black headlines, white background, animated 0–100% "personalizing your plan" loader. Copy: confident-clinical.
- **Home**: huge calorie ring + remaining calories top-center. Three small macro cards. "Recently logged" food list with thumbnails. Camera button is a **floating cocoa-pink FAB**.
- **Primary action**: persistent floating camera FAB at bottom-center, lifted above tab bar.
- **Tab bar**: 3 tabs (Home / Analytics / Settings). Camera FAB above tab bar, not in it.
- **Food log viz**: ring (daily) + horizontal bar chart (week). No calendar, no heatmap.
- **Voice**: confident, neutral, slightly clinical. **NOT** warm, **NOT** anti-shame.

**Lift for JeniFit:** the floating camera FAB is the single most important interaction pattern to steal. Cal AI's voice is the **anti-reference**.

### MacroFactor — the "honest tracker"

- **Screenshots**: trend graph hero, not daily number.
- **Onboarding**: data-first, ~15 screens.
- **Home**: weekly expenditure curve top + today's intake bar below. **Hero = trend, not today.**
- **Voice**: educational, science-honest. The trust voice.

**Lift:** trend-as-hero is a direct MacroFactor borrow. Honesty register fits JeniFit's anti-shame voice better than Cal AI's confident-precise voice.

### Noom — daily course + color food system

- **Onboarding**: 40+ screens. Heavy psychographic profiling.
- **Home**: today's lesson card (top) → calorie remaining → green/yellow/orange food breakdown.
- **Tab bar**: 5 tabs.
- **Voice**: course-led, "did you know," CBT-flavored. Verbose.

**Lift:** Noom's "today's lesson card at top of home" is what JeniMethod already does. **Anti-reference**: don't categorize food by color. Don't write paragraphs.

### WW (WeightWatchers)

- **Voice**: warmer than Cal AI, but stuck in 90s diet-club register.
- **Tab bar**: 5 tabs.

**Lift:** anti-reference. No points abstraction.

### MyFitnessPal (post Cal-AI acquisition)

- **Screenshots**: now leads with "Cal AI Scan" as hero. Old MFP red-bar shame UI being phased out.

**Lift:** confirms direction. Even the giant is moving to camera-first.

### Lifesum, Lose It!, Yazio

- Lifesum: lifestyle photography, plan-led, bright voice. **Lift:** plan-of-the-day card validates JeniFit's hybrid.
- Lose It!: anti-reference, looks 2014.
- Yazio: recipe-led with diet plan chips. Out of scope.

### Aesthetic references (NOT diet apps) — for cohort-fit

- **Flo** — soft pastel coral/cream, **hero card pattern**, anti-shame copy. Strongest visual cousin to JeniFit. Tabs: 4.
- **Headspace** — calm + welcoming + sticker-warmth. Tab bar: 4. "Today's session" hero card pattern.
- **Finch** — soft-girl wellness gamification, sticker-aesthetic, anti-productivity reframe. Voice cousin. Tabs: 5 but home is single bird hero.
- **WeeMee / Stardust** — y2k coquette UI patterns. Locked JeniFit's aesthetic.

**Synthesis pattern:** **one hero object on a warm field** + **soft pastel palette** + **rounded everything** + **the primary action is a single dominant button**. Diet-first apps have replaced the "hero object" with **today's calorie number**. JeniFit's pivot is choosing which hero object replaces JeniMethod's lesson card.

---

## 2. Visual hierarchy for diet-first hero

The current JeniFit home (per `project-home-architecture` v1.0.7):

```
1. JenisNoteCard          — coach voice
2. JeniMethodJourneyCard  — HERO lesson
3. jenifitWorkoutCard     — today's session
4. WeekProgressStrip      — momentum
5. StepsPulseTile + Breathwork
6. quickActions + FutureRailRow
```

This is **program-first**. JeniMethod earns retention; workout is daily action. Food is buried.

### Proposal A — Soft pivot home (keep JeniMethod hero)

```
┌────────────────────────────────────────┐
│  jeni's note                            │  ← voice
├────────────────────────────────────────┤
│  ✿  today's lesson — *food noise*       │  ← JeniMethod HERO (unchanged)
│      day 3 of 14   [tap to read]       │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │  📷    1,420 / 1,800              │  │  ← NEW food hero card
│  │        averaging 1,650 this week  │  │     (cocoa CTA pill on right)
│  │        [ snap your plate ]        │  │
│  └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│  today's plate    🥣 🍳 🥗            │  ← horizontal plate timeline
├────────────────────────────────────────┤
│  today's session — 8 min plank         │  ← workout DEMOTED
├────────────────────────────────────────┤
│  WeekProgressStrip                      │
│  StepsPulseTile + BreathworkHomeCard    │
└────────────────────────────────────────┘
```

What changed: food card between JeniMethod and workout. JeniMethod stays hero (75%+ completion). Workout demoted.

### Proposal B — Medium pivot home (food becomes hero)

```
┌────────────────────────────────────────┐
│  jeni's note                            │
├────────────────────────────────────────┤
│  ┌──────────────────────────────────┐  │
│  │   ●●●○  1,420 of 1,800           │  │  ← FOOD HERO RING
│  │   averaging 1,650 — easy week    │  │     (full scrapbook chrome)
│  │   ┌──────────────────────────┐   │  │
│  │   │  📷  snap your plate     │   │  │  ← cocoa pill primary CTA
│  │   └──────────────────────────┘   │  │
│  │   🥣  🍳  🥗  🧋                  │  │  ← today's plate timeline
│  │   8a   10a  1p  4p               │  │
│  └──────────────────────────────────┘  │
├────────────────────────────────────────┤
│  today's lesson — *food noise*          │  ← JeniMethod demoted
├────────────────────────────────────────┤
│  today's plank — 5 min                  │  ← workout demoted further
├────────────────────────────────────────┤
│  health anchor: steps + breath          │
└────────────────────────────────────────┘
```

What changed: food is dominant slot. JeniMethod and workout equally subordinate. **This matches Cal AI's "calorie ring is universe" but with JeniFit's chrome + interpretation copy.**

### Proposal C — Hard pivot home (camera-first)

```
┌────────────────────────────────────────┐
│  jeni's note                            │
├────────────────────────────────────────┤
│            ●●●●●○                        │
│         1,420 / 1,800                    │  ← MASSIVE ring centered
│         averaging 1,650                  │
├────────────────────────────────────────┤
│  🥣  🍳  🥗  🧋                          │  ← plate timeline (flat)
├────────────────────────────────────────┤
│  more on your day ↓                     │  ← collapsible "more" section
│    today's lesson                        │
│    today's plank                         │
│    health anchor                         │
└────────────────────────────────────────┘
   floating  ┌────────┐
             │   📷   │  ← persistent camera FAB
             └────────┘
```

### Recommendation

**B (Medium pivot) is the right level for v1.5.** Moves primary affordance to food while keeping JeniMethod as the brand differentiator the cohort has empirically rewarded (75%+). C is a Cal AI clone risk. A is a half-measure.

**Decision rule:** the screen the user lands on should answer "what kind of app is this?" within 1 second. A says "fitness app with food." B says "weight-loss program with food at the center." C says "calorie tracker."

---

## 3. Onboarding visual restructure

Current JeniFit onboarding v2: 57 screens, 6 acts. First screen is identity-feeling (brand-aligned per `feedback-first-screen-strategy`).

### Should the first screen become food-led?

**No.** Per locked strategy, screen 1 stays brand-aligned (no before/after, no body imagery). The pivot signal lives on **screen 2 and the plan reveal**, not screen 1.

Screen 2 becomes a food-relationship question:

> *"what's the hardest part of eating right now?"*
> - the noise — too many opinions
> - the snacking — afternoons especially
> - the going-out — restaurants and friends
> - the all-or-nothing cycle
> - the late-night decisions
> - i don't know yet

### Visual treatment

- **Tall pill chips, single-select** for relationship state (matches CalAI pattern).
- **Multi-select chips with check-pill** for cuisines + exclusions.
- **NO sliders** for emotional intensity.
- **NO long-press**.
- **Optional skip** on every emotional question.

### Analyzing screen

```
analyzing your relationship with food...
matching cuisine to vision model...
mapping eating windows to meal slots...
seeding your calorie pattern...
                 87%
```

Surfaces both food-related AND weight-prediction.

### Plan reveal

```
┌────────────────────────────────────────┐
│  hi sarah                               │
│  here's your *becoming*                  │
│  ┌──────────────────────────────────┐  │
│  │  1,650 calories                  │  │  ← FOOD target hero
│  │  90g protein floor               │  │
│  │  with luteal-week flex           │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │  −0.8 lb / wk projected          │  │  ← weight curve secondary
│  │  goal by aug 14 ♥                │  │
│  └──────────────────────────────────┘  │
│  ┌──────────────────────────────────┐  │
│  │  5-min daily plank ritual        │  │  ← workout demoted
│  └──────────────────────────────────┘  │
│  [ continue ]                            │
└────────────────────────────────────────┘
```

**Calories first, weight curve second, workout third.** That ordering IS the pivot.

### Pre-eat permission education screen (new)

```
┌────────────────────────────────────────┐
│           🧋                             │
│  here's something *different*            │
│  most apps make you log after.           │
│  jenifit lets you decide before.         │
│  snap a photo. see if it fits.           │
│  no shame either way ♥                   │
│  [ continue ]                            │
└────────────────────────────────────────┘
```

This screen teaches the wedge before the paywall sees it.

---

## 4. Tab bar restructure

Current: 2 tabs (Present / Becoming).

### Cohort app tab counts

| App | Tabs |
|---|---|
| Cal AI | 3 (Home / Analytics / Settings) |
| MacroFactor | 4 (Diary / Stats / Coach / More) |
| Noom | 5 |
| MFP | 5 |
| Lifesum | 5 |
| Flo | 4 |
| Finch | 5 |

**The mode is 4–5 tabs.** 2 is uniquely sparse.

### Recommendation: Option 4 — 3-tab visual with central FAB

```
┌────────────────────────────────────────┐
│                                          │
│     [ present ]              [ becoming]│
│              ┌────────┐                  │
│              │   📷   │   ← cocoa pill   │
│              └────────┘     centered FAB │
└────────────────────────────────────────┘
```

This adds the diet-first signal (always-tappable camera) without crowding the tab bar with labels. Preserves `feedback-clean-luxury-aesthetic` AND `feedback-settings-and-intensity-research`.

Stretch: when v2 ships body scan, FAB expands to a 2-action speed-dial.

---

## 5. Anti-shame visualization patterns

### Daily calorie display

**Ring, not bar.** Bars feel like budgets/depletion (MFP-era). Rings feel like Apple Watch / Cal AI — neutral.

```
       ●●●○
    1,420 / 1,800
  averaging 1,650 this week
       (easy day)
```

- Caption is **always weekly avg**, daily number secondary.
- Ring color: cocoa when under, desaturated cocoa (NOT red) when over.
- Copy when over: *"you ate a bit more today — happens. tomorrow resets."*
- Copy when under by >300: *"your body needs more than this. add the snack."*

### Weekly average

```
this week
▆▆▅▆█▅▆     ← bars
 ─ ─ ─       ← rolling avg overlay (rose)
averaging 1,750
tracking your goal pace 🌷
```

### Over-target days

- **Never red.** Desaturated cocoa.
- Copy adapts: "a bit higher today" / "tomorrow resets"
- **No streak penalty.** Streak counts days logged, not days under target.

### Under-target safety net

- Gentle Jeni note: *"fuel matters more than restriction right now. add the snack."*
- Only triggers below 1,000 kcal at 6pm OR below 80% three days in a row.

---

## 6. Brand chrome — what survives the pivot

| Signal | Verdict | Rationale |
|---|---|---|
| Coquette sticker scatter | **SURVIVES** | The brand. Cal AI clone defense. Apply sparingly. |
| Italic-Fraunces punch words | **SURVIVES** | Single most differentiated voice signal. |
| Cocoa CTA pills | **SURVIVES & STRENGTHENS** | Camera FAB IS a cocoa pill. |
| Scrapbook borders | **SURVIVES on hero cards** | Apply to food hero, restaurant sheet, result card. Skip on dense plate timeline. |
| Hard offset shadow | **SURVIVES** | Premium reading depends on this. |
| Lowercase casual | **SURVIVES** | Voice lock. |
| Hearts ♥ | **SURVIVES, sparingly** | Under-target day notes, tracking-well captions. |
| Pink mat / accent-subtle backgrounds | **SURVIVES** | Background warmth carries brand. |
| JeniFit wordmark | **SURVIVES** | Brand presence at top. |
| Jeni avatar in JenisNoteCard | **SURVIVES** | Coach voice differentiator vs Cal AI. |
| 14-day JeniMethod arc | **SURVIVES, absorbs 3 new food lessons** | `.foodNoise`, `.permissionToFit`, `.trendOverSnap`. |
| Plank as ritual | **EVOLVES** | Stays as daily action but no longer hero. |
| Breathwork module | **SURVIVES** | Cortisol angle ties to food. |

**Nothing dies.** The pivot is *demotion + reframing*, not destruction.

---

## 7. Workout / plank / breath in a diet-first world

The cohort signal: **lesson 75%+, workout 23%**.

### Recommendation: D (demoted visual weight)

```
┌────────────────────────────────────────┐
│  ... food hero above ...                 │
├────────────────────────────────────────┤
│  today's lesson — *the noise*  →         │  ← flat, single-line
├────────────────────────────────────────┤
│  today's 5-min ritual                    │  ← demoted, no chrome
│  beginner core • 5 min               →   │
├────────────────────────────────────────┤
│  health anchor                           │
│  👟 4,238   🌬 last logged 2d ago        │  ← compact strip
└────────────────────────────────────────┘
```

Present, but not competing for the hero slot. Once JeniMethod content matures (v2), workout becomes an option inside a lesson; standalone card can go away.

---

## 8. Name + App Store positioning

### Does "JeniFit" hurt diet search?

**Yes, moderately.** "Fit" cues fitness. Apple Search Ads top terms for diet-app cohort: "calorie counter," "food tracker," "weight loss." JeniFit doesn't get organic match.

### Three options

1. **Keep JeniFit, lean keyword field hard into calorie/food terms.** App name = "JeniFit: Food + Body."
2. **Rename to something food-cohort-native.** "Jeni" / "becoming with jeni." Risk: loses install-base + TikTok creator content.
3. **JeniFit + aggressive subtitle.** "JeniFit — calorie tracker for women becoming."

**Recommendation: Option 3 for v1.5; reconsider Option 2 for v2 only if ASO data shows ceiling.**

### App Store category

Health & Fitness. **Don't change.**

### New first three screenshots

1. **The food ring** — JeniFit's hero card, italic-Fraunces "today" headline, scrapbook chrome.
2. **The pre-eat moment** — phone showing matcha latte on camera + "you have room" result. **This is the wedge.**
3. **The Jeni interpretation** — coach voice line + plate result. **This is the brand.**

Workout moves to position 6+. Becoming moves to position 4.

---

## 9. Risk: looking like a Cal AI clone

### Where JeniFit differentiates

1. **Anti-shame copy register** — Cal AI is confident-clinical; JeniFit warm-permission.
2. **Pre-eat mode** — Cal AI retrospective-only.
3. **Jeni voice interpretation** — Cal AI returns numbers; JeniFit returns numbers + Jeni's read.
4. **Restaurant "i'm out" mode** — Cal AI has nothing for this.
5. **Becoming arc** — Cal AI has no 14-day program.
6. **Plank ritual** — Cal AI has no workout content.
7. **Coquette scrapbook chrome** — Cal AI is clinical-white.
8. **Trend-as-hero on home** — Cal AI keeps daily-as-hero.

### "Single image that explains JeniFit's wedge"

```
┌────────────────────────────────────────┐
│  🧋  matcha latte                        │
│  around 220.                             │
│  you're at 980 today — easy yes.         │
│  luteal-phase tuesday, this is the       │
│  right call ♥                            │
│  [ have it ]    skip this one →          │
└────────────────────────────────────────┘
```

This card screenshot, used as App Store hero, **cannot be confused with Cal AI**. No Cal AI screen has "permission" or "have it." That's the wedge.

---

## 10. Three concrete pivot proposals

### A. Soft pivot
- Insert food hero card between JeniMethod and workout
- Tab bar unchanged (2 tabs)
- Camera FAB added but secondary
- App Store: screenshots reordered, subtitle adjusted
- **Dev: 8–12 days + 3 design-days**

### B. Medium pivot — RECOMMENDED
- Food becomes hero card (Proposal B from §2)
- JeniMethod demoted to flat single-line
- 3-tab structure via FAB pattern (central cocoa camera circle)
- Becoming: FoodWeekBentoTile + dual-axis weight×intake
- New JeniMethod food lessons in v1.0.7
- Full App Store reshoot + new subtitle
- **Dev: 18–25 days + 6 design-days**

### C. Hard pivot
- B + rename to "Jeni" or "becoming" + new bundle + icon + brand-system refresh
- Cal-AI-clone Camera-first dashboard
- **Dev: 60–90 days + 15 design-days**

### Decision matrix

| | A | B | C |
|---|---|---|---|
| Cohort alignment | partial | strong | strong but Cal-AI-shaped |
| Brand integrity | preserved | preserved | compromised |
| Cal-AI-clone risk | low | low–moderate | high |
| Dev cost | 8–12 days | 18–25 days | 60–90 days |
| Reversibility | high | moderate | low |
| US trial conversion lift | small | medium | medium-large but identity risk |
| Time to ship | 3–4 weeks | 6–8 weeks | 12+ weeks |

**Recommendation: B (Medium pivot).** Signals "diet-first weight-loss program" without becoming Cal AI clone. Founder pricing intuition + v1.0.6 findings + cohort-fit research all point to B.

---

## Cross-references for next design session

- §2-B Home re-architecture conflicts with `project-home-architecture`'s JeniMethod-stays-hero lock. Needs explicit re-litigation.
- §4 tab FAB conflicts with `feedback-clean-luxury-aesthetic`'s thin-marks register. Founder sign-off needed.
- §3 plan reveal supersedes workout-as-plan-hero in onboarding v2.
- §9 anti-Cal-AI result card mockup is the single image to put in front of the founder before any other UX decision.
