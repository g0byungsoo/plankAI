# JeniFit GLP-1 Cohort Strategy
**Status:** Authoritative reference for any feature work touching the GLP-1 cohort
**Date:** 2026-06-16
**Founder:** Han Jen (anyonecanbeartist@gmail.com / kobyungsoo@gmail.com)
**Read this before:** designing any new feature, writing any copy targeted at GLP-1 cohorts, adjusting the paywall, drafting App Store assets, or scoping a feature roadmap

---

## TL;DR — the operating principle

JeniFit is converting **slowly** toward the GLP-1 cohort (on / post / GLP-1-alternative-seeking) as its primary audience while continuing to serve the generic women's-WL audience that currently uses the app. **This is convergence, not pivot.** Three rules govern every decision:

1. **Build for the existing generic-WL audience first**, but layer cohort routing on every change so a GLP-1-cohort user gets the right identity acknowledgment without the engine forking.
2. **Cohort signal lives in the noun phrase / identity acknowledgment, not in feature promises.** JeniFit does not ship a protein floor, a food noise tracker, a post-shot rhythm module, a keep-it-off curriculum, an injection log, or a side-effect log. Until those features exist, copy never names them. Every promise must be cashable in-app within 3 sessions.
3. **Compliance floors are non-negotiable.** No drug brand names on app-controlled surfaces (Apple 5.2.1). No drug-equivalence claims (FTC NextMed $150K precedent). No "GLP-1 alternative" / "natural Ozempic" framing (FDA Feb 2026 warning letters). No first-party numeric weight-loss claims.

When in doubt, default to the generic-WL register. Cohort routing is additive optionality, not the primary brand voice.

---

## Cohort taxonomy

Cohort is read from a single onboarding question (`OnboardingView.swift` case 164):

> any weight meds right now?
> — no (none)
> — considering it (considering)
> — in the past (past)
> — on a GLP-1 now (current)
> — prefer not to say (prefer_not_say)

The persisted AppStorage key is `onboarding_glp1_status`. Code-level routing maps to four buckets via `Glp1Cohort` (defined in `PlankApp/Notifications/RetentionNotifications.swift`):

| Onboarding answer | `Glp1Cohort` case | Cohort identity (internal vocabulary) |
|---|---|---|
| `"current"` | `.onGlp1` | woman on a GLP-1 now; living with nausea, dose calendar, food noise return between doses, muscle-loss anxiety |
| `"past"` | `.postGlp1` | woman off a GLP-1 in the 0-12mo window; the 47-65% JAMA 2025 discontinuation cohort; existential regain fear |
| `"considering"` | `.considering` | woman who has weighed the shot but didn't start; needle-averse, affordability-blocked, philosophical |
| `"none"` / `"prefer_not_say"` / empty / any unrecognized | `.generalWL` | general WL audience; the safe default; what JeniFit serves today |

**Founder reasoning for the cohort lead:** the post-GLP-1 cohort is the structurally-unbundlable wedge — telehealth+app competitors (Noom Rx, WW Med+, Found, Sequence, Calibrate) cannot serve them without cannibalizing their drug revenue. ~4-8M US women in the trailing-12mo discontinuation window, paying nothing for the drug they just lost, with no consumer iOS app built for them today. See `docs/positioning_research_r2_final_2026_06_16.md` for the full positioning research.

**Volume reality:** per onboarding code comments, the GLP-1 cohort (current + past + considering) is ~30% of v1 traffic. Generic-WL still dominates volume. Hence the convergence-not-pivot posture.

---

## The reality-check rule (the founder's 2026-06-16 directive)

The product does not currently ship GLP-1-specific features. **Until it does, no surface promises them.** This is the most-violated rule in the previous strategy work and the founder explicitly course-corrected on it.

### What exists today (use freely in copy + product)
- **JeniMethod CBT lessons** — manifest-driven curriculum, 42 hero photos shipped
- **Breath cards / breathwork primer** — Stanford Balban-cited
- **Becoming tab** — identity hero, WHO Activity Ring, weight EMA, goal pace projection, BMI, barrier-resolved card, plank mastery curve
- **Food rail** — photo→calorie via vision AI, pre-eat decision mode, restaurant mode, scrapbook polaroid layer
- **Weight tracking** — kg/lb, EMA trend, one-per-day
- **Steps** — HealthKit, 7,500 anchor
- **Plank-rotation workouts** — research-led engine
- **Jeni coach persona** — voice cascade

### What does NOT exist (do NOT mention in copy, do NOT promise in onboarding)
- ❌ Protein floor / adaptive protein target
- ❌ Food noise daily tracker / hunger-return scale
- ❌ "Keep-it-off" curriculum (12-week post-GLP-1 maintenance module)
- ❌ Post-shot rhythm / cohort-specific lesson sequence
- ❌ Injection log / dose tracker / side-effect log
- ❌ Site rotation map
- ❌ Nausea-rescue protocol
- ❌ Hair-shedding correlation
- ❌ Injection-day eating mode
- ❌ Resistance-training program (separate from plank)
- ❌ Hydration tracker
- ❌ Off-ramp readiness module
- ❌ Sister-cohort community

### Pre-existing credibility risk (open cleanup item)
The onboarding question at case 164 currently has inline feedback that over-promises:

```
"current":     ("we adjust for GLP-1.", "satiety-aware portions, protein floor, no restrictive windows. we lean into what your appetite is already telling you.")
"past":        ("we adjust for post-GLP-1.", "the first 12 weeks off-meds are about keeping what you built. we match the cadence + protein.")
"considering": ("med or no med, we work.", "the plan reads your data the same way either path you choose ♥")
```

These promise "protein floor," "satiety-aware portions," "cadence + protein matching" — none of which currently ship. **This copy should be walked back to identity acknowledgment only** before more users see it. Suggested rewrite (defer until founder signs off):

```
"current":     ("we see you, on a GLP-1.", "the daily ritual is the same shape either path. lessons, breath cards, becoming ♥")
"past":        ("we see you, in the after.", "the daily ritual is the same shape either path. lessons, breath cards, becoming ♥")
"considering": ("we see you, weighing it.", "the daily ritual is the same shape either path. lessons, breath cards, becoming ♥")
```

Same body for all three (universal); title differs by identity acknowledgment. Matches the v2 notification pattern.

---

## Cohort routing implementation pattern

**The rule: cohort routing lives in the noun phrase / identity acknowledgment. Bodies reference only shipping features.**

### Pattern, applied to push notifications (shipped 2026-06-16)

```swift
// Cohort-aware push: cohort routes the TITLE (identity); body
// universal, references only real features.
public func day1MorningContent(opener: String) -> (title: String, body: String) {
    let title: String
    switch self {
    case .generalWL:   title = "your first morning here."
    case .onGlp1:      title = "day one, alongside the shot."
    case .postGlp1:    title = "the rhythm that keeps it."
    case .considering: title = "the daily piece, day one."
    }
    return (
        title,
        "\(opener)five minutes today. that's how the rhythm begins ♥"
    )
}
```

### Pattern, applied to paywall variants

The paywall already segments by `onboarding_glp1_status` (`PlankApp/Views/Paywall/PaywallView.swift` line 66). The cohort-routed paywall H1 + sub should follow the same pattern: identity acknowledgment in the headline, universal value pitch in the body. Specifically:

- ❌ Don't say: "the protein floor, the food noise quieting, the post-shot rhythm"
- ✅ Do say: "the lessons, the breath cards, the becoming tab" — what actually unlocks

### Pattern, applied to Becoming tab modules

When adding a new Becoming module (e.g., fiber tile, sleep card), build it cohort-agnostic and have a single inline copy variant per cohort that frames the same data through her identity. Example for sleep:

- `.generalWL`: "your sleep this week"
- `.onGlp1`: "your sleep alongside the shot" (no claim, just acknowledgment)
- `.postGlp1`: "your sleep, keeping the rhythm"
- `.considering`: "your sleep, the daily piece"

The DATA showing is the same. The framing varies by cohort. No cohort-specific feature is promised.

### Pattern, applied to App Store CPPs (per `docs/positioning_research_r2_final_2026_06_16.md`)

Three Custom Product Pages already speced:
- **Post-GLP-1 lead** (default organic + post-GLP-1 paid traffic): conviction-led, identity hook on "for after the shot, beside it, or building the habits the drug never taught you"
- **GLP-1-curious / behavior-first** (paid traffic): permission frame, "results without a prescription," no substitution claim
- **Generic-WL / brand-voice-led** (broader audience): JeniFit's anti-Noom anti-Cal-AI specific differentiation

Bodies in all three reference shipping features (food noise as cohort vocabulary is OK — clinically validated term, not a JeniFit-built feature; pre-eat decision mode is shipped; JeniMethod CBT lessons are shipped). See `docs/positioning_research_r2_final_2026_06_16.md` for copy detail.

---

## Compliance floors (non-negotiable, audit before any cohort-touching ship)

### Apple App Review Guideline 5.2.1 (trademark / IP)
- ❌ Never use "Ozempic" / "Wegovy" / "Mounjaro" / "Zepbound" / "semaglutide" / "tirzepatide" in: app name, subtitle, keywords, screenshots, paid creative, push titles/bodies, paywall H1/sub, in-app coach voice, onboarding chrome.
- ✅ Safe class noun: "GLP-1" (lowercase or hyphenated forms acceptable).
- ✅ Safe euphemism: "the shot," "the medication," "the meds," "weight-loss medication."
- ✅ Brand names ARE allowed in user-entered fields (medication picker, journal entries) — user content, not app-controlled.

### FTC Click-to-Cancel + NextMed precedent ($150K, December 2025)
- ❌ Never make first-party numeric weight-loss claims ("lose X lbs," "burn X cal," "drop X% body weight").
- ❌ Never claim drug-equivalence ("works like Ozempic," "as effective as," "comparable to").
- ❌ Never claim "guaranteed" / "miracle" / "easy" outcomes.
- ✅ Third-party cited statistics OK if accurately quoted ("47% discontinue within a year" per JAMA Jan 2025).
- ✅ Process-conviction OK ("the daily work," "the lessons," "the rhythm").

### FDA February 2026 warning letters (30 telehealth firms)
- ❌ Never use "GLP-1 alternative."
- ❌ Never use "natural GLP-1" / "natural Ozempic."
- ❌ Never frame the app as a substitution for medication.
- ✅ "Without an Rx" / "without one" / "your own way" / "the daily piece" — all framings of agency, not substitution.

### Meta + TikTok ad policy (2025-2026 tightening)
- ❌ No before/after body imagery in paid creative.
- ❌ No AI-generated faces or hands (Arizona AG specifically flagged AI portraits).
- ❌ No body imagery in lock-screen-visible copy.
- ✅ User-generated creator testimonials are policy-distinct from brand promotion; first-person creator content can speak brand drug names (the platform treats that as user speech).

### JeniFit voice spec (per `docs/notification_system_spec_2026_06_16.md` §2)
- ❌ em-dash between words (the glyph is OK as a no-data placeholder)
- ❌ double-hyphen between words
- ❌ `*italic*` markdown markers in copy strings (italic-Fraunces is a UI render, not a string)
- ❌ ALL CAPS words, exclamation points (1/week ceiling across entire library)
- ❌ Labor verbs: crush, shred, burn, earn, grind, smash, dominate, push, work
- ❌ Scale words: pounds, lbs, kg, weight, scale, weigh, before, after (in push/marketing copy)
- ❌ Streak-loss threats
- ❌ AI-coded language: "AI coach," "smart suggestions," "intelligent insights"
- ❌ Accusation questions: "haven't tried X yet?" "where've you been?"

---

## The convergent product roadmap

Per `docs/feature_gap_synthesis_2026_06_16.md`: of 44 features identified across 3 cohort gap analyses, **11 serve 2+ cohorts simultaneously**. The product converges — same engine, cohort-translated copy + threshold tuning. Build phase order:

### Phase 1 — convergent foundation (weeks 1-3, ~14-19 dev days)
Serves all 3 cohorts. Closes the 7-14% US conversion leak. Substantiates the GLP-1 positioning when paired with App Store CPP rewrite.

Top 5 P0 ships:
1. **Cohort onboarding question** (✅ already shipped per the `onboarding_glp1_status` key + `Glp1Cohort` enum)
2. **Adaptive protein floor** (1-2 days) — `ProgramGoalCalculator` extended with cohort-tuned `proteinTargetGramsPerDay`; food rail elevates protein as primary macro for GLP-1 cohorts
3. **Pre-eat permission card promotion** (3-4 days) — already 80% built; surface on Home, daily count badge, Jeni-voice response variants
4. **Food noise / hunger-return tracker** (4-5 days) — daily 0-10 + 3 chips; weekly trend in Becoming
5. **Daily Plate Score** (5-7 days) — 4-up grid + 1-line caption + share-as-image; closes the missing 20-second daily ritual

After these 5 ship, JeniFit can run the App Store CPP test + paid creative test with substantiating product behind it.

### Phase 2 — post-GLP-1 specific stack (weeks 4-5, ~6-7 dev days)
- **12-week "Keep-It-Off" curriculum** (4-5 days) — JeniMethod manifest extended with cohort-tagged 12-week sequence
- **"We're not Calibrate" non-Rx trust strip** (1 day) — paywall + settings
- **30-day "first month off" milestone** (1 day) — earned-moment sticker scatter trigger

### Phase 3 — on-GLP-1 specific stack (weeks 6-10, ~26-32 dev days)
Heavy: injection-tracker lite, side-effect log, nausea-rescue, injection-day eating mode, resistance routines, off-ramp module, dose-cadence notifications. See `docs/feature_gap_on_glp1_2026_06_16.md` for the 12 features.

### Phase 4 — generic-WL polish + cycle-aware program (deferred, v1.2+)
- Day-1 first-scan magic moment
- Voice food logging
- NSV chips
- Cycle-aware adaptive program

**The key gate:** Phase 2+3 ships ONLY after Phase 1 has validated the conviction-led GLP-1 positioning via App Store CPP + paid creative + onboarding question response distribution. If <20% of users answer `current` / `past` / `considering`, the cohort-specific stack is misaligned with the channel and we hold.

---

## Decision rules for any feature work

When designing or copy-reviewing any new feature, run these checks:

### Check 1: Does this ship something real?
- ✅ Is the feature actually built and verifiable in a TestFlight build?
- ❌ Or does it promise behavior the product can't deliver?

If the copy mentions a feature, that feature must exist and be reachable in ≤3 user actions.

### Check 2: Does it route per cohort cleanly?
- ✅ Title (identity acknowledgment) varies by `Glp1Cohort.current`
- ✅ Body (value pitch) is universal OR references only shipping features
- ❌ Don't bifurcate the underlying engine per cohort — that's not convergence

### Check 3: Does it survive the compliance floors?
- Walk through Apple 5.2.1 + FTC + FDA + Meta/TikTok per §"Compliance floors"
- If any banned phrase appears, rewrite or kill

### Check 4: Does it match the JeniFit voice spec?
- Lowercase, ♥ as terminal only, no em-dash, no AI-coded, no labor verbs
- See `docs/notification_system_spec_2026_06_16.md` §2 for the full spec

### Check 5: Is it convergent or cohort-specific?
- **Convergent (preferred):** ship in Phase 1. Serves all 3 cohorts. Cohort routes via copy.
- **Cohort-specific:** defer to Phase 2/3. Validate cohort lead first.

### Check 6: Would the existing generic-WL audience be confused / alienated?
- Default to NO for non-cohort-routed surfaces (Home, Becoming, lessons, etc.)
- Cohort-routed copy should be invisible to `.generalWL` users (they see the default branch)

---

## Strategic risks to monitor

These are the known failure modes that would invalidate the strategy. Watch for any of them in PostHog / TestFlight data / App Review correspondence:

1. **Apple App Review flags any drug-related surface** — pull immediately, retreat to "Weight Care for women" with GLP-1 references removed entirely.
2. **FTC / state AG inquiry** — same-day rollback of all cohort-specific copy. Engage health-advertising counsel within 48h.
3. **TikTok ban rate >40% on UGC creator creative** — pivot acquisition to Apple Search Ads + Reddit.
4. **Cohort response distribution <20% `current`/`past`/`considering`** — current channel doesn't reach the cohort; hold Phase 2+3, pivot acquisition or revert to Round 1's "Quiet" positioning.
5. **Telehealth giants ship behavioral-companion apps that absorb the cohort** — Noom GLP-1 Companion already exists; Embla is €10M-raised; the window is 6-12 months.
6. **30-day star rating drops ≥0.3** post-pivot — bait-and-switch detected; pull every cohort-specific claim until the substantiating product (Phase 2/3) ships.

Each risk has a specific kill trigger in `docs/positioning_research_r2_final_2026_06_16.md` §"If founder is wrong about X, here's what" — read that passage when making the post-Phase-1 decision.

---

## Related documents (read in order if you're new to this strategy)

1. **`docs/positioning_research_r2_final_2026_06_16.md`** — the conviction-led GLP-1 positioning research (round 2; 7 experts), with revised positioning hierarchy, kill triggers, 30/60/90 plan
2. **`docs/positioning_research_final_2026_06_16.md`** — round 1 positioning research (12 experts; converged on "Quiet" register before founder course-correction)
3. **`docs/feature_gap_synthesis_2026_06_16.md`** — the 11 convergent features + cohort-specific stacks; the "build phase" decision framework
4. **`docs/feature_gap_post_glp1_2026_06_16.md`** — post-GLP-1 cohort feature deep-dive (16 features)
5. **`docs/feature_gap_on_glp1_2026_06_16.md`** — on-GLP-1 cohort feature deep-dive (16 features)
6. **`docs/feature_gap_generic_wl_2026_06_16.md`** — generic-WL feature deep-dive (12 features); explains the 7-14% US conversion leak
7. **`docs/notification_system_spec_2026_06_16.md`** — notification voice spec + cadence architecture
8. **`docs/notification_per_cohort_preview_v2_2026_06_16.md`** — exact per-cohort notification copy as shipped

---

## Founder-only decisions still open

These are the load-bearing decisions that need founder input before further Phase 1 work:

1. **Walk back the onboarding case 164 inline feedback** to remove "protein floor" / "satiety-aware portions" / "cadence + protein matching" promises. Suggested rewrite in §"Pre-existing credibility risk" above. Effort: 5-min copy edit.

2. **Cohort-update reactivity:** is there a settings UI to change `onboarding_glp1_status` post-onboarding? If yes, wire `RetentionNotifications.reschedule()` to fire on that change. If no, defer.

3. **Phase 1 ship order:** the synthesis recommends cohort onboarding question first (✅ shipped), then adaptive protein floor → pre-eat promotion → food noise tracker → daily plate score. Confirm or reorder.

4. **App Store CPP rollout timing:** the v2 positioning research has 3 ready-to-paste prompts (`docs/positioning_research_r2_final_2026_06_16.md` §"Recommended Positioning v2"). Confirm timing — recommended after Phase 1 ships so the conviction copy has substantiating product behind it.

5. **Pricing test:** revised positioning supports $79.99 annual anchor. Confirm timing of the price A/B (current $47.99 baseline).

When any of these decisions land, update this doc + the memory pointer in `MEMORY.md` so the strategy stays current.
