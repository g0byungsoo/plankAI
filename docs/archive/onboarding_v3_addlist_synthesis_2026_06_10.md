# Onboarding v3 — ADD-list Synthesis (2026-06-10)

**Sources (all four agent outputs):**
- `docs/calai_teardown_screenshot_anchored_2026_06_10.md` — Cal AI 43-screen, 5 S-tier, 15 ADDs
- `docs/betterme_teardown_screenshot_anchored_2026_06_10.md` — BetterMe 33-screen, 5 S-tier + 6 A-tier, 14 ADDs, 6 commitment-architecture patterns
- `docs/her75_design_extraction_2026_06_10.md` — typography (42pt heroHeadline), 5 tokens, 5 Grok prompts
- `docs/jenifit_current_onboarding_map_2026_06_10.md` — **48 screens already in v2FlowOrder, 49 signals collected, only 12% used by WorkoutGenerator, 10 signals dead/underused**

**Headline finding:** post-compaction summary said "post-cut target ~25 screens" — that's wrong. **Current code has 48 screens.** The recent cuts that landed were 2 body-image AI sliders + coach selector. The bulk of the flow is intact. So this is an ADD-on-top-of-48 conversation, not a re-add-after-aggressive-cut conversation.

---

## 1. The leverage matrix — both apps independently arrived at these (highest signal)

| Pattern | Cal AI cite | BetterMe cite | Status in JeniFit | Action |
|---------|-------------|---------------|-------------------|--------|
| **Multi-tile / quantified-rails reveal** | calai36, calai37 | betterme30 | partial (`ProjectionPresentation` + `FirstWeekPresentation` exist but not unified into one reveal card) | **MUST-ADD** — both apps land the same screen as the cognitive cash-out before paywall |
| **Date-target pill** ("~6 lbs by Aug 14") | calai36 | implicit in betterme30 | not shipped | **MUST-ADD** — Gollwitzer implementation intentions, +11% per Adapty |
| **3-stage loader w/ checklist** | calai33-35 | betterme28-29 | already shipped (BuildingPlanLoadingView ~25s) | **TUNE** — needs sub-label clustering (data → synthesis → completion) + mid-loader ATT |
| **Sunk-cost "tried apps" Q** | calai5 | (not present) | **already shipped** (case 168) | already done |

Three independent convergences = highest confidence. **All three must ship in v1.0.7.**

---

## 2. Cal AI S-tier (distinct from BetterMe — Cal AI's unique adds)

| Cal AI lever | Mechanism | JeniFit ADD | Net new screens | Cost |
|--------------|-----------|-------------|-----------------|------|
| **S1. Two-step paywall (commit first, choose second)** | Splits "yes-to-trial" from "tier choice" — kills 35% drop from double cognitive load | New "commit step" (bell + "1" + no payment today) before existing paywall (which becomes "choose step") | **+1 screen** (refactor of 1 → 2) | medium |
| **S2. Pace selector w/ live "weeks to becoming" callout** | Bandura self-efficacy + Sunsteinian default + screenshottable TikTok flywheel | 3-position selector: *gentle* / *steady* (selected) / *focused*, coquette glossy snail/bunny/bow-cheetah stickers, live callout "~16 / ~12 / ~8 weeks" | **+1 screen** | medium |
| **S3. 3-stage loader sub-label clustering + ATT mid-flow** | Buell & Norton labor-illusion + ATT pre-prime at peak investment = 27% lower CAC | Cluster existing sub-labels into 3 acts; add ATT iOS dialog at ~30% (pause progress) | **+0 screens** (tune existing) | small |
| **S4. Sign-in immediately pre-paywall** | Sunk-cost lock + StoreKit 1-tap purchase pipeline | New "save your *becoming* ♥" screen between plan reveal and paywall step 1; upgrades existing anonymous Supabase account | **+1 screen** | medium |
| **S5. Apple Health connect mid-onboarding (relocate from post-paywall)** | +5-9% paywall→trial + retention infrastructure pre-paywall | Move HealthKit ask into onboarding; 4-corner sticker composition (steps / heart / sleep / mindful-min) | **+0 screens** (relocate) | small |

**Cal AI net new: +3 screens.**

---

## 3. BetterMe S-tier (distinct from Cal AI — BetterMe's unique adds)

| BetterMe lever | Mechanism | JeniFit ADD | Net new screens | Cost |
|----------------|-----------|-------------|-----------------|------|
| **S1. Dynamic goal-weight reframe on same screen** | Same screen swaps inline education card based on picked number (BMI<18.5 / on-pace / ambitious) | Wire into existing goal-weight Q (case 132) — 3 states: amber-low (kinder target), sage on-pace, cocoa ambitious. **NEVER "lose X%" copy** (anti-shame lock) | **+0 screens** (modify existing) | medium |
| **S2. Psychometric Yes/No fear statements** | Bem self-perception + Cialdini commitment — fear-coded first-person ("i'm afraid…") forces dichotomous identity commitment | 2-3 new Yes/No screens between Habits and Reveal. Flags drive paywall copy + Day-2 notification | **+2 to +3 screens** | small |
| **S3. 5-chapter IA in header** | Goal-gradient effect (Kivetz 2006) — perceived completion accelerates near salient sub-goals | Header chips: "about you" / "your *rhythm*" / "what *fits*" / "your *why*" / "*almost there*" with 5-segment sub-progress | **+0 screens** (modify header) | small |
| **S4. "Almost There" label on final chapter** | Sunk-cost weaponized for completion — most users won't abandon at "almost there" | String change in chapter map for last 3-4 screens | **+0 screens** (string) | XS |
| **S5. Quantified-rails reveal card (5 rails + sources link)** | IKEA effect — every prior Q pays off in one number | Build `ProgramRevealCard`: plan / workouts / food rail / steps / breathwork — each with coquette sticker thumbnail | **+1 screen** (replaces current reveal) | medium |

**BetterMe net new: +2 to +3 screens.**

---

## 4. A-tier additions (both apps, ranked)

| ID | Pattern | Source | Net new | Cost |
|----|---------|--------|---------|------|
| A1 | Justification co-located on every sensitive Q ("Helander 2014: daily weigh-ins reduce regain by 47%") | betterme2,3 | +0 (copy sweep) | small |
| A2 | Self-narration option descriptors ("*time* · my evenings disappear before i notice") | betterme5,7,14,17,21 | +0 (copy sweep) | small |
| A3 | 2 bridge screens between chapters | betterme4,9 + calai22 | **+2** | small |
| A4 | Duty-of-care inline disclosure on health flags (GLP-1 / pregnancy / Hard tier) | betterme12 | +0 (conditional card) | small |
| A5 | Cohort-credibility slot ("women 25-34 with *food noise* as #1 barrier — your patterns match") | betterme4 | **+1** | small |
| A6 | Two-checkbox health-data consent | betterme13 | **+1** | small (medium legal) |
| A7 | Reciprocity beat ("thank you for being honest ♥") after vulnerability cluster | calai22 | **+1** | small |
| A8 | Notification pre-prime w/ mockup iOS dialog in JeniFit voice (NO pointing finger) | calai28 | **+1** (or modify existing) | small |
| A9 | Date-target pill in plan reveal | calai36 | +0 (inside reveal card) | XS |
| A10 | "No payment today" safety strip + bell+1 trial-reminder sticker on paywall | calai40,43 | +0 (paywall enhancement) | XS |

**A-tier net new: +6 screens.**

---

## 5. Dead weight to CUT (from current 48)

From `jenifit_current_onboarding_map_2026_06_10.md`:

| Cut | Case | Why |
|-----|------|-----|
| **C1** | 165 (commitConfidence) | Fully dead — written, never read. Replaced by Cal AI sunk-cost effect from S4 sign-in. |
| **C2** | 270 (habit-quiz teach) | `habitQuizSelected` read 0 times. Educational, no signal. |
| **C3** | 170 (re-prediction) | Redundant with case 161 (first prediction) — same numbers, same chrome. |
| **C4** | 142 (comparison frame) | Off-brand "you vs them" copy; replaced by N5 cohort-credibility slot. |
| **C5** | 145 (video demo) | Conversion impact unverified; ages fast; defer to v1.5 A/B. |
| **C6** | 169 (cuisine multi-select) | Defer to food rail in-app personalization — `onboardingCuisinePreference` is only consumed by FoodSettings. |

**Cuts: -6 screens.** Plus dead-signal wiring: keep collecting sleep/GLP-1/hormonal/eatingCadence (now load-bearing in ProgramGoalCalculator v2 — P11.2), drop priorWin + stressLevel + nsvPriority from generator consumption (these stay only as Becoming-tab seeds).

---

## 6. Net flow math

```
Current:                           48 screens
Cuts (C1-C6):                       -6
Cal AI S-tier net new:              +3   (pace, sign-in, paywall-split delta)
BetterMe S-tier net new:           +2-3  (2-3 psychometric Yes/No)
S-tier modifications (no count):    +0   (loader tune, goal-weight reframe, chapter IA, "almost there", quantified reveal)
A-tier net new (A3+A5+A6+A7+A8):    +6
                                  ─────
Target:                            53-54 screens
```

Cal AI ships 43. BetterMe ships 33. her75 ships ~30. JeniFit at 53 is the high end but **acceptable IF every screen earns its weight** — and the cuts (C1-C6) prove the screens being added are higher-leverage than the screens being removed.

---

## 7. her75 design overlay (applied to ALL screens, old + new)

From `docs/her75_design_extraction_2026_06_10.md`:

| Token / treatment | Spec | Apply to |
|-------------------|------|----------|
| `heroHeadline` | **42pt** Fraunces serif (vs current 38pt `displayHero`) | Plan reveal, paywall step 1, ChapterCompleteView, brand-statement screens |
| Italic Fraunces punch placement | **Possessives / prepositions / verbs only** (your, with, it, ready) — NEVER first or last word | Audit ALL existing italic copy |
| `editorialCard` variant | White, 28pt corners, **shadow-only, no stroke** | Reveal cards, social-proof, justification cards |
| Sticker compositional role | **56-72pt, 30-40% edge-bleed** (load-bearing, not decoration) | Bridge screens, reveal hero, paywall hero |
| LineCascadeText | Already exists | Apply to plan reveal, paywall hero, ChapterCompleteView (currently un-cascaded) |

---

## 8. Grok Imagine illustrations (5 prompts ready)

From the her75 agent — locked style suffix so the 5 illustrations render coherent:

1. **Heart-padlock** (goal commitment) — for goal-weight reframe screen
2. **Iridescent bow huddle** (social proof) — for cohort-credibility slot (N5)
3. **Open mirror compact** (future self) — for plan-reveal hero
4. **Perfume bottle** (ritual / habit anchor) — for bridge screen between rhythm and fits chapters
5. **Disco-ball cluster** (celebration / projection) — for projection presentation

Each prompt is no-people, no-text, edge-tilt, ready to paste into Grok Imagine API.

---

## 9. The unified ADD-list (ship order, prioritized)

### Phase 1 — Week 1 (low-risk modifications, no new screens)
| # | Change | Source | Cost |
|---|--------|--------|------|
| 1 | 5-chapter IA header redesign | BetterMe S3 | small |
| 2 | "Almost there" label on final chapter | BetterMe S4 | XS |
| 3 | Inline justification cards on every sensitive Q | BetterMe A1 | small |
| 4 | Self-narration option-label sweep | BetterMe A2 | small |
| 5 | her75 typography: bump `heroHeadline` 38pt → 42pt; italic-punch position audit | her75 | small |
| 6 | LineCascadeText applied to plan reveal + ChapterCompleteView | her75 | small |
| 7 | 3-stage loader sub-label clustering + ATT mid-flow at ~30% | Cal AI S3 | small |
| 8 | Bell+1 + "no payment today" safety strip on existing paywall | Cal AI A10 | XS |
| 9 | Dynamic goal-weight reframe card on existing case 132 (3 states) | BetterMe S1 | medium |
| 10 | Date-target pill in plan reveal ("~6 lbs by Aug 14 ♥") | Cal AI A9 | XS |
| 11 | Duty-of-care inline disclosures on GLP-1/pregnancy/Hard tier | BetterMe A4 | small |
| 12 | CUT C1-C6 (commitConfidence, habit-quiz, re-prediction, comparison frame, video demo, cuisine) | dead-weight | XS |

### Phase 2 — Week 2 (additive new screens)
| # | New screen | Source | Cost |
|---|------------|--------|------|
| 13 | Pace selector w/ live callout (coquette stickers + "weeks to becoming") | Cal AI S2 | medium |
| 14 | Psychometric Yes/No #1 (*quick results fear*) | BetterMe S2 | small |
| 15 | Psychometric Yes/No #2 (*another diet fear*) | BetterMe S2 | small |
| 16 | Psychometric Yes/No #3 (*prior attempt fear*) — optional, can defer | BetterMe S2 | small |
| 17 | Bridge #1 after "your *rhythm*" chapter | BetterMe A3 | small |
| 18 | Bridge #2 after "what *fits*" chapter | BetterMe A3 | small |
| 19 | Reciprocity beat ("thank you for being honest ♥") | Cal AI A7 | small |
| 20 | Cohort-credibility slot ("women 25-34 with food noise…") | BetterMe A5 | small |
| 21 | Notification pre-prime w/ mockup iOS dialog (NO pointing finger) | Cal AI A8 | small-medium |
| 22 | Apple Health connect relocated to mid-onboarding | Cal AI S5 | small |

### Phase 3 — Week 3 (the structural changes, paired with engineering review)
| # | New screen | Source | Cost |
|---|------------|--------|------|
| 23 | Sign-in "save your *becoming* ♥" between plan reveal and paywall | Cal AI S4 | medium |
| 24 | Paywall step 1 (commit step — bell + "1" + no payment today + continue) | Cal AI S1 | medium |
| 25 | Paywall step 2 (choose step — tier cards + timeline) — modify existing PaywallView | Cal AI S1 | medium |
| 26 | Quantified-rails reveal card (5 rails + sources link) | BetterMe S5 | medium |
| 27 | Two-checkbox health-data consent | BetterMe A6 | small (medium legal) |

### Defer to v1.5
- Referral code (Cal AI B2 — needs Branch SDK + creator deals)
- Trial-as-toggle pricing (BetterMe B1 — needs no-trial SKU + Apple AR review)
- 4th+ psychometric Yes/No statements

---

## 10. The 20 things to REJECT (locked, cited)

From Cal AI teardown §4 + BetterMe teardown §5 — these patterns are off-brand for JeniFit's cohort. Verified to not appear in any ADD above:

**Cal AI rejects:** "AI" word, labor verbs (crush/shred/burn/earn), explicit decimal kg, Health Score 7/10, "Congratulations!" trophy-pop, 👆 pointing-finger emoji, AI-generated body imagery, rollover-calories preference (ED-adjacent), Ozempic-substitute testimonial, all-caps "3 DAYS FREE" badge, line-art (not 3D sticker) illustrations, "Let's get started!" CTA, pure-white background, "10M+ users" volume claim, "$0.92/wk · billed $47.99" weekly-equivalent display.

**BetterMe rejects:** body imagery on screen 1, "lose X% of your weight" framing, "slim down" verb, "bad habits" framing, photo thumbnails on reveal, amber Attention card on low BMI, "Find Self-Love" as primary goal, fine-print paywall legal copy, native OS permission timed over a bridge screen.

---

## 11. Founder decisions to surface BEFORE any code edits

These 6 decisions block downstream work:

1. **Screen budget** — target ~53 (cuts + S/A adds) vs ~48 (cuts + S only) vs ~60+ (S+A+B)?
2. **Psychometric Yes/No count** — 3 / 2 / 1 / 0 fear statements?
3. **Sign-in placement** — mid-onboarding (Cal AI pattern) vs pre-paywall (Cal AI's actual placement) vs defer (rely on Supabase anon upgrade)?
4. **Two-step paywall** — split current single-screen into commit + choose, or keep single-screen + add the bell+1 + "no payment today" strip only?
5. **Dead signals (sleep, GLP-1, hormonal, eatingCadence, priorWin, stressLevel, nsvPriority)** — wire into ProgramGoalCalculator v2 (load-bearing) or drop the collecting screens?
6. **Grok illustration generation** — generate all 5 now in parallel, or wait for screen approvals + generate per screen as we build?

---

## 12. What NOT to do (the meta-lesson from teardowns)

Cal AI and BetterMe both get **conversion** right but get **brand** wrong for JeniFit's cohort. The synthesis principle:
- **Adopt the architecture** (chapter IA, dynamic reframe, two-step paywall, pace selector, justification co-location, psychometric Yes/No).
- **Reject the register** (every "AI", labor verb, scolding card, body image, line-art, ALL CAPS, manipulative urgency, fabricated cohort counts).
- **Layer her75's typography** (42pt hero, possessive italic-punch, shadow-only editorial card, sticker-as-composition).

**Cal AI's onboarding is question-engineered, not designed. JeniFit's depth + voice are the moat. The teardown shows the structural moves to copy without copying the brand, the claims, or the price.**
