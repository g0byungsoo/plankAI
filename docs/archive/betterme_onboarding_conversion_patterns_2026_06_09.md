# BetterMe Onboarding Conversion Science — Pattern Extraction

**Date:** 2026-06-09
**Source:** 33 screenshots of BetterMe's onboarding flow (paths: `screenshots/betterme[1-33].PNG`)
**Purpose:** Extract proven conversion patterns from BetterMe (7+ years A/B tested) and map to JeniFit onboarding v2 for v1.1 adoption.

---

## The 14 patterns

### 1. Justification co-located with question
**Pattern:** Inline education card UNDER the question, BEFORE the answer.
**Example:** Birthday wheel → "Creating your personal plan: Older people may have more body fat compared to younger people with the same BMI."
**Why it works:** User sees WHY before answering → answers feel like collaboration, not interrogation.
**JeniFit status:** Partial — some screens have eyebrow microcopy but not consistent inline education cards.
**Adoption priority for v1.1:** **HIGH** — wire into GoalDateRevealScreen + every screen that asks for a sensitive input (weight, age, GLP-1).

### 2. Self-narration option descriptors
**Pattern:** Options labeled as first-person sentences the user "voices" in their head while reading.
**Example:** "Meal Plans · I want to have a set menu to achieve fastest results" / "Calorie Counting · I like to be precise and know the exact macros I consume"
**Why it works:** User commits to identity-as-self-narration, not just labeling a preference.
**JeniFit status:** Partial — bodyFocus + goal questions already use this pattern; barrier/eating-window questions don't.
**Adoption priority:** **HIGH** — sweep existing v2 options, convert label-only to first-person.

### 3. Bridge / affirmation-only screens
**Pattern:** Emotion-only screen with NO question between two data-gathering screens. Trust-building, free of cognitive load.
**Example:** "We know how to make that happen! · Life is 99 problems, but your fitness routine doesn't have to be one. · BetterMe workouts are perfect for slimming down at your own pace and with pleasure!"
**Why it works:** Breaks monotony, builds rapport, primes the next question with affirmation.
**JeniFit status:** Has *some* (the "we hear you" screens) but not enough between data phases.
**Adoption priority:** **HIGH** — insert 2-3 bridge screens between Habits/Nutrition/Motivation phases. Cheap; no schema impact.

### 4. Dynamic in-page reframing on numeric inputs
**Pattern:** Goal-weight picker RECOMPUTES its own inline education card based on the picked number.
**Examples:**
- 97 lb → "Attention · Your target BMI is too low · You might be at risk of some health problems"
- 143 lb → "Challenging choice · You will lose 48.6% of your weight · Drop extra pounds for a healthier you: - Decreased joints pain - More energy"
- 146 lb → "Challenging choice · You will lose 47.5% of your weight · …"

**Why it works:** Personalization-theater that's actually real personalization. Anchors the goal in reframe + benefit stack.
**JeniFit status:** Partial — `BecomingProjectionCard` reframes goal but not on goal-weight input itself.
**Adoption priority:** **CRITICAL** — wire into the new `GoalDateRevealScreen` (Phase 1 work). Show pct + benefit stack + ACSM safety chip based on picked weight.

### 5. Psychometric Yes/No statements
**Pattern:** "Do you relate to the statement below?" + first-person fear/pain statement → Yes/No buttons.
**Examples:**
- "I often require external motivation to keep going. I can easily give up when I feel stressed."
- "I'm afraid I won't have time to do the other things I love because I'll be so busy exercising and planning meals."

**Why it works:** Forces ID-priming moment. Either user admits the fear (now JeniFit is the resolver) or denies it (low-friction tap). Either way, advances. The data is gold for downstream notification + paywall copy.
**JeniFit status:** **DOES NOT HAVE.** Highest-value missing pattern.
**Adoption priority:** **CRITICAL** — add 2-3 statements in v1.1 (insertable without changing schema: just AppStorage bool flags). Recommended statements aligned to JeniFit cohort:
- *"i've tried something like this before and given up after the first hard day."*
- *"i don't trust apps that promise quick results."*
- *"i'm afraid this is going to feel like another diet."*

### 6. Cohort-specific social proof
**Pattern:** "Over 7 million women in their 30s already tried BetterMe" — proof renders ONLY when matched to user's sex + age cohort.
**Why it works:** Generic "10M downloads" reads as advertising; cohort-specific reads as "people like me did this".
**JeniFit status:** Doesn't have. JeniFit has no real enrollment count yet (per memory).
**Adoption priority:** **MEDIUM** — defer to Phase 4 (social proof pill on PlanView), but design the slot now so the variable swap is trivial when we hit 250+ enrollments.

### 7. Trial as opt-in toggle with price tier
**Pattern:** Trial is a SECONDARY OPTION the user must toggle ON. Default = no-trial subscription at LOWER price ($14.99). Trial = HIGHER price ($19.99 + 7-day free).
**Why it works:** Frames trial as something you opt INTO, not the default — increases intent + filters lower-quality trials.
**JeniFit status:** Doesn't have this mechanic. JeniFit pricing locked at $47.99 annual + $24.99 quarterly + $5.99 weekly (per `project_pricing_locked_v1_0_7`).
**Adoption priority:** **EXPERIMENTAL** — A/B test only. Requires new SKU pair + RC offering update. Defer until Phase 5+; do not block Phase 1.

### 8. Custom Program reveal screen
**Pattern:** Between data-gathering and paywall: 5 cards each showing one program rail with photo thumbnail + title + **quantified daily goal**.
**Example:**
- "Psychology · Includes: 9 Chapters"
- "Workouts · Prenatal Yoga"
- "Meal Plan · Daily Goal: 1,996 Cal"
- "Steps · Daily Goal: 9,000 steps"
- "Water · Daily Goal: 128 fl oz"

CTA: "GET MY PLAN" + "Sources of recommendations →" link below.
**Why it works:** EVERY prior question pays off here. The cognitive payoff for completing the questionnaire is concrete daily numbers.
**JeniFit status:** Has `BecomingProjectionCard` + `OnboardingRevealView` but not the quantified-daily-goals card grid.
**Adoption priority:** **HIGH** — extend `BecomingProjectionCard` or build new `ProgramRevealCard` for v1.1. This is the screen right before paywall — it sells.

### 9. Duty-of-care inline disclosures
**Pattern:** On cohort-specific selections (Prenatal, GLP-1, etc.), an inline safety/disclaimer card appears underneath the selected option.
**Example:** "Prenatal ✓ · Please note · If you're pregnant, consult your doctor before working out"
**Why it works:** Signals seriousness, protects from medical liability, reads as care not friction.
**JeniFit status:** Has GLP-1 + pregnancy questions but no inline disclosure card.
**Adoption priority:** **MEDIUM** — add to existing health-flag screens. Same pattern, low effort.

### 10. Explicit "Health Data Processing" two-checkbox consent flow
**Pattern:** Dedicated screen with 2 checkboxes (Analytical Purposes + Personalization Purposes) + I AGREE button. Explains that WITHOUT consent the program can't be personalized.
**Why it works:** Friction-positive — explicit consent is a commitment device. GDPR-compliant. Makes data collection feel intentional.
**JeniFit status:** Privacy policy lives in settings + linkout; no explicit consent moment in onboarding.
**Adoption priority:** **MEDIUM** — adds friction but increases commitment. Decide based on legal posture + EU exposure.

### 11. IA progress segmented by chapter (not %)
**Pattern:** Top bar shows chapter name ("About You" / "Habits" / "Nutrition" / "Motivation" / "Almost There") with a sub-progress bar PER chapter. NOT "Question 12 of 43".
**Why it works:** Each chapter feels short. Crossing into a new chapter feels like progress, not slog. Hides total length.
**JeniFit status:** Onboarding v2 has 6 phases but doesn't surface them with chapter-name + sub-progress in the header.
**Adoption priority:** **HIGH** — same data we already have. Just header redesign. Cheap, high-perceived-impact.

### 12. "Almost There" framing on last 3-4 questions
**Pattern:** Last cluster of questions is wrapped in a chapter literally called "Almost There" — psychological commitment device + sunk-cost amplifier.
**Why it works:** Tells the user they're close enough that quitting now is dumb.
**JeniFit status:** Doesn't tag the final cluster.
**Adoption priority:** **HIGH** — bundled with #11 (chapter IA). Cheap.

### 13. Closing offer 50% downsell
**Pattern:** When user declines the no-trial CTA, modal pops: "SAVE 50% · Only $9.99/month (was $19.99) · This offer is one-time and will not be available later · CLAIM NOW!"
**JeniFit status:** **ALREADY SHIPPED** per `project_trial_downsell_locked`. ✓

### 14. "Creating Your Plan" loading carousel with bullet list
**Pattern:** Circular progress 3% → 18% → 100% + bullet list of "things being computed" (Analyzing your profile / Estimating your metabolic age / Adapting the plan to your busy schedule / Selecting suitable workouts & recipes).
**JeniFit status:** **ALREADY SHIPPED** per `project_onboarding_v2_plan`. ✓

---

## Adoption priority summary for v1.1

### CRITICAL (must do in Phase 1 with the 3 new program screens)
- **#4 — Dynamic reframing on goal weight input** → wire into `GoalDateRevealScreen` (the new screen)
- **#5 — Psychometric Yes/No statements** → add 2-3 to onboarding v2 *before* the new program screens

### HIGH (Phase 1 if budget allows, else Phase 1.5)
- **#1 — Inline justification cards** → sweep existing v2 screens + add to all 3 new screens
- **#2 — Self-narration option descriptors** → sweep + convert label-only options
- **#3 — Bridge/affirmation screens** → insert 2-3 between phases
- **#8 — Quantified daily goals reveal card** → extend `BecomingProjectionCard` with the 5-card rail breakdown
- **#11 — Chapter IA in header** → header redesign with chapter name + sub-progress bar
- **#12 — "Almost There" framing** → bundled with #11

### MEDIUM (Phase 2-3)
- **#6 — Cohort social proof** → design slot now, swap real numbers later
- **#9 — Duty-of-care disclosures** → add to GLP-1 + pregnancy + Hard-tier-locked
- **#10 — Two-checkbox health consent** → legal review first

### EXPERIMENTAL / DEFER
- **#7 — Trial-as-toggle with price tier** → A/B test only, requires new SKU; defer to Phase 5+

### ALREADY SHIPPED
- **#13 — 50% closing downsell** ✓
- **#14 — "Creating your plan" loading carousel** ✓

---

## What BetterMe also reveals (meta-lessons)

1. **They ASK A LOT.** ~30+ questions across the flow before paywall. Friction is the conversion lever, not the killer — *but only with bridge screens + chapter IA hiding the length*.
2. **Every question pays off somewhere.** Bad habits → meal plan picks; energy levels → workout intensity; motivation statements → notification copy. Data without payoff = burnout.
3. **The cocoa-on-cream palette is identical to ours.** Validates JeniFit's pink-cream + dark cocoa CTA register. We're not behind; we're in the same conversion-coded design genre.
4. **NO sticker scatter on data-gathering screens.** Confirms the program/celebration register split in the v1.1 plan.
5. **Lowercase casual on the name field** ("jen" not "Jen"). Same brand signal as JeniFit's lowercase-casual rule.
6. **15+ diet types in the diet picker.** Personalization-theater at scale. JeniFit's "we ask what fits" frame can absorb this without going full label-soup.

---

## Notes for implementation in Phase 1

The 3 new program-era onboarding screens (cases 171/172/173 in `OnboardingView.swift`) MUST adopt:
- Pattern #1 (inline justification card on intensity choice — ACSM citation chip)
- Pattern #4 (dynamic reframing on goal weight + intensity slider position)
- Pattern #11/#12 (header chapter = "Your Plan" with its own sub-progress bar)

Sweep retrofit for existing v2 screens (separate sub-task within Phase 1):
- Pattern #2 (self-narration sweep — audit all options)
- Pattern #3 (insert 2-3 bridge screens)
- Pattern #5 (insert 2-3 psychometric Yes/No statements as new cases)

Defer to Phase 1.5 or later:
- Pattern #8 (program reveal card with quantified daily goals)
- Pattern #9, #10 (duty-of-care + consent)
- Pattern #6 (cohort social proof slot)
