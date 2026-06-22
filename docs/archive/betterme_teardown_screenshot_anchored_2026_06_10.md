# BetterMe Onboarding Teardown — Screenshot-Anchored

**Date:** 2026-06-10
**Source:** 33 native screenshots `/Users/bko/plankAI/screenshots/betterme[1-33].PNG`
**Prior research:** `/Users/bko/plankAI/docs/betterme_onboarding_conversion_patterns_2026_06_09.md` (yesterday — 14 patterns extracted, this doc verifies + extends + cites)
**Purpose:** Give the JeniFit founder a verifiable, screenshot-anchored copy/conversion map. Every claim has a `betterme#` cite so the founder can pull the PNG and check.

> Verified screens read in full: betterme1-33 (all 33 sampled).

---

## 1. The 33-screen map (one-line per screen)

| # | Chapter | Screen | Type |
|---|---|---|---|
| 1 | Intro | "Let's personalize your plan" privacy intro w/ body imagery + I AGREE | Consent + value-promise |
| 2 | About You | "What is your sex?" — Female (selected) / Male, microcopy "Your sex impacts key body metrics" | Data + justification |
| 3 | About You | "When is your birthday?" — date wheel + inline card "Older people may have more body fat compared to younger…" | Data + dynamic justification card |
| 4 | About You | Cohort proof: "Over 7 million women in their 30s already tried BetterMe" + 5 body avatars | Bridge / social proof |
| 5 | About You | "What's your main goal?" — Lose Weight (sel) / Find Self-Love / Build Muscle / Keep Fit w/ first-person sub-labels | Data, self-narration |
| 6 | About You | "When was the last time you were at your ideal weight?" — bucketed | Data, identity-anchoring |
| 7 | About You | "What are you interested in?" — Meal Plans / Calorie Counting / Workout Plans / Fasting / Cycle Tracking w/ first-person descriptors | Data, multi-select, self-narration |
| 8 | About You | Native iOS notification permission prompt over "We know how to make that happen!" bridge | OS permission timed to bridge |
| 9 | About You | Bridge "We know how to make that happen! Life is 99 problems, but your fitness routine doesn't have to be one" | Affirmation-only |
| 10 | About You | "Do you want to include special programs?" pg1 — No Thanks / Sensitive Back / Knees / Type 1 / Type 2 / Recovery | Data, health-flags |
| 11 | About You | Special programs pg2 — Prenatal / Postnatal / Limited Mobility / Limb Loss | Data, health-flags |
| 12 | About You | Prenatal selected → inline "Please note · If you're pregnant, consult your doctor" | Duty-of-care disclosure |
| 13 | About You | Health Data Processing — 2 checkboxes (Analytical + Personalization) + I AGREE | Explicit consent |
| 14 | About You | "Choose up to 3 activities" — Walking / Stretching / Yoga (selected) / etc. | Data, multi-select cap |
| 15 | Habits | "How are your energy levels during the day?" — Even / Lunch dip / Nap after meals | Data |
| 16 | Habits | "How much sleep do you get?" — buckets | Data |
| 17 | Nutrition | "Choose your diet type" pg1 — Traditional / Vegetarian / Keto / Pescatarian / Vegan / Paleo / Mediterranean | Data, label-soup |
| 18 | Nutrition | Diet types pg2 — Diabetes 1/2, High-Protein, Traditional Easy, Calorie-Cutting/High, Time-Saving | Data, label-soup |
| 19 | Nutrition | Diet types pg3 — Menopausal added | Data, label-soup |
| 20 | Nutrition | "What bad habits hinder you from reaching your goals?" — Don't Rest Enough / Sweet Tooth / Too Much Soda / Salty / Midnight Snacks | Data, multi-select, shame-adjacent |
| 21 | Nutrition | "What's your daily water intake?" — About 2 / 2-6 (sel) / More than 6 / I Only Have Coffee or Tea | Data, with self-narration last option |
| 22 | Motivation | Psychometric Yes/No — "I'm afraid I won't have time to do the other things I love because I'll be so busy exercising and planning meals." | Psychometric commitment |
| 23 | Motivation | Psychometric Yes/No — "I often require external motivation to keep going. I can easily give up when I feel stressed." | Psychometric commitment |
| 24 | Almost There | "What is your goal weight?" — 97 lb (entered) + Attention card "Your target BMI is too low — You might be at risk of some health problems" | Dynamic reframe (safety variant) |
| 25 | Almost There | "What is your goal weight?" — 146 lb + Challenging choice card "You will lose 47.5% of your weight — Decreased joints pain — More energy" | Dynamic reframe (benefit variant) |
| 26 | Almost There | "What is your goal weight?" — 143 lb + Challenging choice card "You will lose 48.6% of your weight…" | Dynamic reframe (variant continues) |
| 27 | Almost There | "What's your name?" — `jen` lowercase | Data + identity priming |
| 28 | (no header) | Loading carousel "Creating Your Plan · 3% · Analyzing your profile / Estimating your metabolic age / Adapting the plan to your busy schedule / Selecting suitable workouts & recipes" | Justification-theater |
| 29 | (no header) | Loading carousel at 18% — same bullets | Justification-theater |
| 30 | Reveal | "Your Custom Program" — 5 rails: Psychology (9 Chapters) / Workouts (Prenatal Yoga) / Meal Plan (1,996 Cal) / Steps (9,000) / Water (128 fl oz) + "Sources of recommendations" link + GET MY PLAN | Quantified-goals reveal |
| 31 | Paywall | "How does trial work?" — 3-row timeline (Today / Day 5 / Day 7), default state = trial OFF, $14.99/mo ($3.69/wk), SUBSCRIBE NOW | Trial-as-toggle, no-trial default |
| 32 | Paywall | Same screen, trial TOGGLED ON — top pill "7 days free trial", $19.99/mo ($4.99/wk), START MY FREE WEEK | Trial-as-toggle, trial state |
| 33 | Paywall | Decline → modal "SAVE 50% — Only $9.99/month (was $19.99) — This offer is one-time…" + CLAIM NOW! + Decline one-time offer | Closing downsell |

---

## 2. Top conversion levers (ranked)

Ranking key: **S** = ship this for v1.1, near-zero risk + outsized impact. **A** = ship in Phase 1 if budget. **B** = experimental / needs A/B. **C** = reject for JeniFit (see §5).

### S-tier

#### S1. Dynamic in-page reframing on the goal-weight picker — `betterme24, 25, 26`
The same screen ("What is your goal weight?") swaps its inline education card based on the picked number. At 97 lb → amber "Attention · Your target BMI is too low — You might be at risk of some health problems". At 146 lb → sage "Challenging choice · You will lose 47.5% of your weight — Decreased joints pain — More energy". At 143 lb → sage "48.6%…".
**Cost:** Low. Card view + 3 state variants (too-low, on-target, ambitious) driven by computed BMI + delta%.
**Mechanism:** Personalization theater that is actually real. Anchors the user to a benefit stack and a safety floor without an extra screen.
**Citation/principle:** Implementation intentions (Gollwitzer 1999) + loss-aversion framing (Kahneman & Tversky 1979) + the BetterMe a/b record: this is the #1 differentiator vs Cal AI's static reveal.
**JeniFit translation:** Wire into the planned `GoalDateRevealScreen`. Three states:
- Under-target BMI 18.5: "your goal is below what's clinically safe. let's set a kinder target together." (NO red bar; cocoa with amber dot.)
- 0.5-1%/wk pace (ACSM): "*on pace.* this is a sustainable rate — energy, sleep, and mood usually follow." (sage chip)
- >1%/wk: "*ambitious.* we'll need a steady food rhythm and a soft week if life gets loud." (cocoa with sage dot)
- NEVER use "lose X% of your weight" copy verbatim — per locked vocab the percent-of-self phrasing reads as scale-shame. Reframe as "your *becoming* window: ~12 weeks" or similar trend-language. (See `feedback_weightloss_ux_principles`.)

#### S2. Psychometric Yes/No commitment statements — `betterme22, 23`
"Do you relate to the statement below?" + first-person fear-statement in a quote card + Yes/No tiles (Yes = cocoa fill + check; No = cream + X). Two consecutive screens, both fear-flavored: time-cost ("I'm afraid I won't have time…"), self-efficacy ("I often require external motivation…").
**Cost:** Low. New `OnboardingView` case per statement. 2 AppStorage bool flags. No schema.
**Mechanism:** Cognitive dissonance + ID priming. Either the user names the fear (now JeniFit is the resolver), or denies it (cheap tap forward). Either branch advances. The flag is gold for downstream paywall + notification copy.
**Citation/principle:** Self-perception theory (Bem 1972); commitment-and-consistency (Cialdini); the universal SCT mechanism behind effective Gen-Z survey-tech (Wysa, Replika 2024 retention work).
**JeniFit translation:** Add 3 statements between Habits and Nutrition (or right before the new program-era screens). Use JeniFit-voiced first-person, lowercase, italic punch words:
- *"i've tried something like this before and given up after the first hard day."*
- *"i don't trust apps that promise quick results."*
- *"i'm afraid this is going to feel like another diet."*

Yes branch → store flag (`onb_fear_quickResults` etc.) → resurface in the paywall closing line and in Day-2 trial notification. **CRITICAL: do not gamify or score the answers. No "0/3" register.** Tile UI matches `betterme22` 2-up — cocoa-fill Yes left, cream-outline No right.

#### S3. Chapter-based IA in the top bar — `betterme2-23 (chapter shifts visible)`
Header reads "About You" then "Habits" then "Nutrition" then "Motivation" then "Almost There" — with a 5-segment sub-progress bar. There is no "Question 12 of 33" anywhere. Crossing a chapter feels like real progress.
**Cost:** Low. JeniFit already has phase metadata internally; just surface it.
**Mechanism:** Goal-gradient effect (Kivetz et al. 2006) — perceived completion accelerates near a salient sub-goal. Chapter boundaries create more sub-goals.
**Citation/principle:** Hides total length, replaces dread-with-momentum.
**JeniFit translation:** 5-chapter header for onboarding v2:
- "about you" (sex, age, body focus, goal weight)
- "your rhythm" (sleep, stress, eating window) (NEW data in v2)
- "what fits" (food relationship, prior attempts, GLP-1)
- "your *why*" (psychometric statements + barrier)
- "*almost there*" (name, reveal)

Italic-Fraunces "*why*" + "*almost there*" matches the locked voice signal.

#### S4. "Almost There" framing on the last chapter — `betterme24-27`
The same psychological lever as the chapter IA, but the final cluster is literally labelled "Almost There" — making the sunk-cost amplifier explicit. The user is told they are close to done at the highest-friction screens (goal weight reframe + name entry).
**Cost:** Trivial. String change in the chapter map.
**Mechanism:** Sunk-cost fallacy weaponized for completion. Most users will not abandon at "almost there".
**JeniFit translation:** Last 3-4 cases of onboarding v2 wrapped in chapter labelled `"*almost there*"` (italic on "almost"). Pair with goal-date reveal as the LAST data input.

#### S5. Quantified-rails reveal screen — `betterme30`
"Your Custom Program" with 5 rails each showing one daily number: Psychology (9 Chapters), Workouts (Prenatal Yoga), Meal Plan (1,996 Cal), Steps (9,000 steps), Water (128 fl oz). Single primary CTA: "GET MY PLAN". Tiny secondary "Sources of recommendations →".
**Cost:** Low if JeniFit reuses BecomingProjectionCard + adds a 5-row stack.
**Mechanism:** Every prior question pays off here in a concrete number. The reveal screen is the cognitive cash-out for 5 minutes of friction.
**Citation/principle:** IKEA effect — the more the user co-built, the more they value the output.
**JeniFit translation:** Build `ProgramRevealCard` with 4-5 rows:
- "your *plan* · ~14 weeks · custom pace based on your goal"
- "workouts · 4 days/week, 20 min"
- "food rail · ~1,520 kcal/day window, 5 meals"
- "steps · 7,500 anchor"
- "breathwork · 5 min, evenings"

Sticker theme: tiny coquette glossy sticker on each rail thumbnail (gummy heart, iridescent bow, flower3D), NOT BetterMe's photo thumbnails (which break the JeniFit palette + drift toward body imagery).

Secondary link: `"sources of recommendations →"` opens a sheet listing ACSM, NIH, Helander 2014, Bandura — already true for JeniFit and gives credibility. (Adopt this UI literally; the founder owns the citations.)

CTA copy: `"see my plan"` (not "GET MY PLAN" — labor-coded). Final reveal cta = single button + post-paywall.

### A-tier

#### A1. Justification co-located with the question — `betterme2, 3`
Microcopy "Your sex impacts key body metrics" sits under the question on `betterme2`. On `betterme3` ("When is your birthday?"), the inline card says "Creating your personal plan: Older people may have more body fat compared to younger people with the same BMI." The user sees WHY before answering.
**Cost:** Low. Per-screen string.
**Mechanism:** Costless justification (Langer 1978 — "the copy machine study"). Any "because…" raises compliance.
**JeniFit translation:** Sweep onboarding v2. Every sensitive input (weight, age, GLP-1, eating cadence) gets an inline cocoa-tinted card. Voice rules:
- Lowercase casual.
- One sentence.
- No labor verbs.
- Cite a study when honest (e.g. "Helander 2014: daily weigh-ins reduce regain by 47% over 12 months").

#### A2. Self-narration option descriptors — `betterme5, 7, 14, 17, 21`
Options aren't labels — they're first-person sentences the user hears in their head as they tap. `betterme7`: "Meal Plans · I want to have a set menu to achieve fastest results" / "Calorie Counting · I like to be precise and know the exact macros I consume". `betterme21`: "I Only Have Coffee or Tea". `betterme5`: goals each have a self-narration sub-label.
**Cost:** Low. Copy sweep.
**Mechanism:** Self-perception theory (Bem 1972) — saying "I am someone who…" while tapping commits the user to the identity.
**JeniFit translation:** Sweep all option-lists in `OnboardingView`. Examples:
- Barrier picker: "*time* · my evenings disappear before i notice" / "*motivation* · i start strong and lose it by week 2" / "*food noise* · i think about eating way more than i want to"
- Food relationship: "*neutral* · i eat when i'm hungry, mostly" / "*emotional* · food is how i comfort, reward, decompress" / "*restrictive* · i over-control then crash"

#### A3. Bridge / affirmation-only screens — `betterme4, 9`
`betterme9` is pure affirmation: "We know how to make that happen! · Life is 99 problems, but your fitness routine doesn't have to be one. · BetterMe workouts are perfect for slimming down at your own pace and with pleasure!" No question. `betterme4` is the same structure with cohort proof.
**Cost:** Low. ~2-3 new cases.
**Mechanism:** Pacing variance — drops the cognitive load between data clusters, builds rapport, primes the next chapter with a positive frame.
**JeniFit translation:** Insert 2 bridge screens. Voice rules: NO sticker scatter (program register, see `feedback_visual_richness_over_restraint`), NO "slim down" or "lose" verb. Examples:
- After "your rhythm" chapter: `"sleep and stress aren't separate from food. we'll factor them both in."`
- After "your *why*" chapter: `"the cohort of women who match your profile usually feel different by week 3 — not the scale, the *noise*."` (post-Ozempic vocab.)

#### A4. Duty-of-care inline disclosures — `betterme12`
Prenatal selected → inline cocoa card "Please note · If you're pregnant, consult your doctor before working out". Renders only on cohort-specific selections (Prenatal, Recovery, etc.).
**Cost:** Low. Conditional card on existing health-flag screens.
**Mechanism:** Signals seriousness without adding a full friction screen. Reads as care, not a wall.
**JeniFit translation:** Wire to:
- GLP-1 selected → "if you're on a GLP-1, we'll lean into satiety-aware portions and skip restrictive windows."
- Pregnancy/postpartum → "we don't program any plank or supine work in the second trimester+. talk to your doctor before starting."
- Hard tier selected (per `project_program_pivot_v1_1`) → "this is for women with 3+ months of consistent movement. you can downshift anytime."

#### A5. Cohort-specific social proof — `betterme4`
"Over 7 million women in their 30s already tried BetterMe" — renders the count tied to the user's sex + age cohort that was just collected on `betterme2, 3`.
**Cost:** Low (UI). Real cost: JeniFit needs the count, which it doesn't have at launch.
**Mechanism:** Social proof specificity wins over generic. "10M downloads" reads as ad; "47K women in their 20s started this week" reads as peer signal.
**JeniFit translation:** Design the slot now, swap real numbers when JeniFit hits ~250 paid users (per memory `project_launch_v106b11_findings` — currently too small to be honest). Slot can launch with credibility framing instead: `"based on patterns we see in your cohort — women 25-34 with food noise as the #1 barrier"`. Cohort-tied without a count.

#### A6. Explicit health-data two-checkbox consent — `betterme13`
Dedicated screen with two checkboxes (Analytical Purposes + Personalization Purposes) + I AGREE. Friction-positive: explicit consent IS a commitment device.
**Cost:** Low UI, medium legal review.
**Mechanism:** Foot-in-the-door + commitment-consistency. Also defensible under GDPR/CCPA.
**JeniFit translation:** Insert before the reveal. Two checkboxes:
- "use my answers to *personalize* my plan" (must be checked to continue)
- "send me a *day-2* check-in so i don't lose momentum" (default checked, optional)

This also unlocks the trial-week notification system (per `project_trial_week_notifications`) with explicit affirmative opt-in rather than implicit OS-permission only.

### B-tier (experimental, A/B only)

#### B1. Trial-as-toggle pricing — `betterme31, 32`
Default state: trial OFF, $14.99/mo ($3.69/wk). User must flip the toggle to ON to get the 7-day free trial — flipping ALSO bumps the price tier to $19.99/mo ($4.99/wk). The pill at the top changes too: empty → "7 days free trial".
**Mechanism:** Decoy effect + opt-in commitment. The "no-trial" price is the anchor; trial feels like a value-add the user chooses.
**JeniFit translation:** **EXPERIMENTAL ONLY** — JeniFit pricing is locked (`project_pricing_locked_v1_0_7`: $47.99 annual + $24.99 quarterly + $5.99 weekly + 3-day trial annual-only). The trial-toggle mechanic requires a new SKU pair (no-trial annual at slight discount + trial annual at full price). Defer past Phase 1; revisit when there's enough US-cohort traffic to A/B with 90% power (per `feedback_us_paywall_conversion_gap`, US conversion is the bottleneck — this lever might be the wedge).

**Risk:** The "trial OFF default" reads as anti-Apple guideline if it's not crystal clear which option is which. Apple has rejected apps for confusing toggle states. Need legal/AR review first.

#### B2. Loading carousel justification — `betterme28, 29`
3% → 18% → 100% circular progress + 4 bullets being checked off. Each bullet is justification-theater: "Analyzing your profile / Estimating your metabolic age / Adapting the plan to your busy schedule / Selecting suitable workouts & recipes."
**JeniFit status:** **ALREADY SHIPPED** per `project_onboarding_v2_plan`. Verify the bullets match JeniFit voice (no "metabolic age" — too 2010s. Use "*food noise* baseline" instead).

#### B3. Closing 50% downsell — `betterme33`
Decline → modal "SAVE 50% · Only $9.99/month (was $19.99) · This offer is one-time and will not be available later · CLAIM NOW!" + "Decline one-time offer" link.
**JeniFit status:** **ALREADY SHIPPED** per `project_trial_downsell_locked`. Verify the urgency line ("one-time and will not be available later") matches — JeniFit can hedge to "this is the only time we'll offer this" to soften.

---

## 3. Psychometric / commitment-architecture patterns mapped to screens

This is where BetterMe's flow is interesting beyond UI patterns. Six commitment levers, in the order they fire:

### CA-1. Identity-anchoring via "ideal weight" past — `betterme6`
"When was the last time you were at your ideal weight?" — surfaces a memory of self-as-someone-who-was-lighter. This is identity priming before any goal entry.
**JeniFit translation:** This works for the cohort but is risky in post-Ozempic + anti-femvertising land. SKIP — replace with a more permission-coded version: "what does *better* look like for you?" with non-scale options (energy / clothes / mood / mirror).

### CA-2. Goal verb commitment — `betterme5`
"What's your main goal?" with verb-led options (Lose Weight / Find Self-Love / Build Muscle / Keep Fit). The verb is the commitment.
**JeniFit translation:** JeniFit already has goal capture in onboarding v2. Audit verbs against the post-Ozempic vocab list. Reject: "lose weight" (use "feel *lighter*"), "build muscle" (use "feel *strong*"), "keep fit" (use "stay *steady*"). Verb-first option labels.

### CA-3. Interest-as-self-narration — `betterme7`
"What are you interested in?" multi-select with first-person sub-labels — user commits to multiple identities at once ("I want a set menu" + "I like to be precise about macros").
**JeniFit translation:** Direct adopt. The food-rail value prop is best framed as a chosen identity, not a feature toggle. (See `project_food_rail_v3_locked`.)

### CA-4. Health-flag self-disclosure — `betterme10, 11, 12`
Special programs surface visible health flags (Sensitive Back, Knees, Type 2 Diabetes, Prenatal, Limb Loss) — user opts into the flag with full agency. The inline disclaimer card on Prenatal (betterme12) signals BetterMe takes the flag seriously.
**JeniFit translation:** v1.1 program pivot already has Sensitive Joints + GLP-1 + Pregnancy/Postpartum flags planned (per `project_program_pivot_v1_1`). Wire the duty-of-care card per A4 above.

### CA-5. Fear-as-statement (psychometric) — `betterme22, 23`
Two Yes/No fear statements. Different from a "do you struggle with…" multi-select — these are full first-person sentences that the user explicitly affirms or denies. The architecture forces dichotomous commitment, not a vague pick-3.
**JeniFit translation:** Adopt per S2. The dichotomous tile UI matters — multi-select doesn't carry the same commitment force.

### CA-6. Goal-weight as the highest-friction terminal commitment — `betterme24, 25, 26`
Last data input before name. Goal weight is the most loaded number in the flow. BetterMe softens it with the dynamic reframe card so the moment of commitment ALSO is the moment of reassurance.
**JeniFit translation:** Per S1. **CRITICAL:** in JeniFit this becomes the goal-date reveal (`GoalDateRevealScreen`), which is already planned. The dynamic card MUST appear on the same screen.

---

## 4. Data BetterMe extracts (every field; is JeniFit asking; does the program engine need it?)

| # | Field | BetterMe screen | Type | JeniFit has it? | Program engine needs? | Action |
|---|---|---|---|---|---|---|
| 1 | Sex | `betterme2` | enum {F, M} | yes | yes (TDEE, BMI) | ✓ keep |
| 2 | Birthday → age | `betterme3` | date | yes | yes | ✓ keep |
| 3 | Main goal verb | `betterme5` | enum | yes | yes (program shape) | ✓ keep, audit verbs (CA-2) |
| 4 | Last-ideal-weight date | `betterme6` | enum (bucket) | no | no | REJECT (CA-1) |
| 5 | Interest tags | `betterme7` | multi-select | partial (goalFocus) | yes (which rails to surface) | EXPAND in v2 — see below |
| 6 | Notification opt-in | `betterme8` | OS permission | yes | for retention notifications | ✓ keep, time per A3 (after a bridge) |
| 7 | Special programs / health flags | `betterme10-12` | multi-select | planned (v1.1) | YES (tier downshift) | ✓ ship with A4 |
| 8 | Health-data consent | `betterme13` | 2x checkbox | NO | for compliance + retention notif | NEW — see A6 |
| 9 | Activities (up to 3) | `betterme14` | multi-select cap 3 | partial (bodyFocus) | yes (movement style) | EXPAND — see below |
| 10 | Energy levels | `betterme15` | enum | NO | could feed workout time-of-day | NEW field if engine uses it; else skip |
| 11 | Sleep hours | `betterme16` | enum (bucket) | yes (v2 has sleep field per `project_onboarding_v2_fields`) | yes (recovery + cortisol) | ✓ keep |
| 12 | Diet type | `betterme17-19` | enum (15+ options) | partial (food relationship) | yes (food rail) | EXPAND — see below |
| 13 | Bad habits | `betterme20` | multi-select | partial (barrier) | yes (paywall copy + notif copy) | EXPAND in v2 |
| 14 | Water intake | `betterme21` | enum | no | no for v1 | DEFER (until water rail ships) |
| 15 | Psychometric fear 1 (time) | `betterme22` | yes/no | NO | yes (paywall + day-2 copy) | NEW — S2 |
| 16 | Psychometric fear 2 (motivation) | `betterme23` | yes/no | NO | yes (notif copy + bridge) | NEW — S2 |
| 17 | Goal weight | `betterme24-26` | float | yes | YES (ProgramGoalCalculator) | ✓ keep + wire S1 dynamic reframe |
| 18 | Name | `betterme27` | string | yes | yes (personalization throughout) | ✓ keep, force lowercase per `betterme27` |

**Gaps JeniFit must fill in v2 (cross-checked with `project_onboarding_v2_fields`):**
- Interest tags expanded to include food-rail surfaces: Meal Photo Counting / Pre-eat Permission / Restaurant Mode / Today's Plate. (per `project_food_rail_v3_locked`)
- Activities expanded beyond bodyFocus — collect a 3-cap "what feels good": Walking / Stretching / Yoga / Pilates / Strength / Dance / Outdoor. Drives initial workout-rail seed.
- Bad-habits/barrier multi-select expanded to include 2026 post-Ozempic options: "*food noise* — i think about food more than i want to" / "*plateau* — i've stalled on a GLP-1 or post-deficit" / "*permission* — eating out wrecks the rest of the day".

**Fields BetterMe extracts that JeniFit should REJECT (with cite + reason):**
- `betterme6` last-ideal-weight: backward-looking identity priming. Anti-cohort fit (femvertising, scale-shame).
- `betterme24-26` weight as `% of your weight`: see §5 below.

---

## 5. Patterns to REJECT for JeniFit (cited)

### R1. Body imagery on screen 1 — `betterme1`
The intro screen shows a glamour-photo woman in fitness wear holding a coffee. Anti-cohort fit per `feedback_first_screen_strategy` (TikTok-acquired Gen-Z + millennial women reject AI-generated/stock body imagery). JeniFit screen 1 stays brand-aligned: coquette sticker scatter on cream, no people.

### R2. "Lose X% of your weight" framing — `betterme25, 26`
"You will lose 47.5% of your weight" / "48.6% of your weight". Reads as scale-shame to the post-Ozempic cohort (per `feedback_post_ozempic_vocabulary` + `feedback_food_ux_antishame`). JeniFit's reframe MUST be:
- Trend-language ("your *becoming* window: ~14 weeks").
- Non-scale signals ("expect energy and clothes-fit changes first, scale later").
- ACSM safety chip (not a "challenging choice" badge).

### R3. "Slimming down at your own pace and with pleasure" — `betterme9`
The labor verb "slim down" violates locked vocab. JeniFit's bridge copy uses post-Ozempic vocabulary: *food noise*, *satiety*, *permission*, *fits*, *tomorrow resets*. Per `feedback_post_ozempic_vocabulary` + `feedback_voice_signals`.

### R4. "Bad habits" framing — `betterme20`
"What BAD habits hinder you from reaching your goals?" — Sweet Tooth / Midnight Snacks etc. The "bad" qualifier + the foods-as-character-flaws labelling violates the anti-shame food UX rule (`feedback_food_ux_antishame`). JeniFit's parallel question reframes as `"where does food *noise* show up for you most?"` with neutral, non-moralized options (Evening Cravings / Boredom Eating / Stress / Restriction-Binge Cycle).

### R5. Photo thumbnails on Custom Program reveal — `betterme30`
Three of the 5 rails use stock photos of women's bodies (pregnant belly twice, smaller fit-woman). Anti-cohort. JeniFit's `ProgramRevealCard` uses coquette glossy stickers per `feedback_design_theme`.

### R6. "Your target BMI is too low" amber Attention card — `betterme24`
The amber color + the word "Attention" + "risk of some health problems" lands as scolding. JeniFit's S1 variant uses a sage-toned cocoa card (no red/amber for low BMI) and copy: `"this goal is below what's *kind* to your body — let's pick a number that has room to feel good."` Permission-frame, not warning-frame.

### R7. "Find Self-Love" as a primary weight-loss goal — `betterme5`
This option in the goal list reads as bait. JeniFit's locked stance is that self-love is the *output* of the program (per `project_jenifit_vision`), not a goal choice the user picks alongside "lose weight". Risk: framing self-love as a fitness goal feels manipulative to the anti-femvertising cohort. Use straight verbs + identity terms instead (per CA-2).

### R8. "How does trial work?" + auto-renew fine-print only — `betterme31, 32`
The legal copy under the CTA is gray-on-cream 8pt — barely legible. JeniFit must be cleaner here for App Review safety + post-Cal-AI-lawsuit posture (per `project_pricing_locked_v1_0_7`). Use the JeniFit paywall single-screen pattern already locked, NOT a clone of `betterme31`.

### R9. Native iOS permission prompt timed to bridge — `betterme8`
The OS prompt is placed in-flow OVER a bridge screen. This blocks the bridge and creates an OS-permission rejection if the user picks "Don't Allow" — and on iOS, the second ask of the same permission is silent (deny is permanent). High-risk for JeniFit's retention-notification strategy (per `project_trial_week_notifications`). **JeniFit's order:** Soft-ask in-app (S6-like opt-in toggle) → OS-permission ONLY after soft-yes.

---

## 6. ADD-list for JeniFit (proposed new screens, in order, with `betterme#` origins)

This proposes the v1.1 onboarding additions. Numbers are insertion points; existing onboarding v2 screens stay in their slots.

| Order | Screen | Origin | Voice (lowercase + italic punch) | Rationale |
|---|---|---|---|---|
| **N1** | Chapter header redesign: 5 chapters with sub-progress | `betterme2-23` (chapter shift visible) | "about you" / "your *rhythm*" / "what *fits*" / "your *why*" / "*almost there*" | S3 — goal-gradient effect; hides total length. Cheap. |
| **N2** | Inline justification cards on every sensitive input | `betterme2, 3` | "*helander 2014:* daily weigh-ins reduce regain by 47% over 12 months — that's why we ask." | A1 — costless justification raises compliance. |
| **N3** | Self-narration sweep on existing options | `betterme5, 7, 14, 17, 21` | "*time* · my evenings disappear before i notice" | A2 — identity-as-self-narration commits the user. |
| **N4** | Bridge screen #1 (after "your *rhythm*" chapter) | `betterme4, 9` | "sleep and stress aren't separate from food. we'll factor them both in." | A3 — pacing variance, rapport, primes next chapter. |
| **N5** | Cohort-credibility framing slot (NOT a count yet) | `betterme4` | "women 25-34 with *food noise* as the #1 barrier — your patterns match" | A5 — placeholder for real count post-250 users. |
| **N6** | Bridge screen #2 (after "what *fits*" chapter) | `betterme4, 9` | "the women who match your profile usually feel different by week 3. not the scale — the *noise*." | A3 — second affirmation; post-Ozempic vocab. |
| **N7** | Psychometric Yes/No #1 — *quick results fear* | `betterme22` | "i don't trust apps that *promise* quick results." | S2 — fear-as-commitment; flag drives paywall copy. |
| **N8** | Psychometric Yes/No #2 — *another diet fear* | `betterme22` | "i'm afraid this is going to feel like *another* diet." | S2 — flag drives bridge + day-2 notif copy. |
| **N9** | Psychometric Yes/No #3 — *prior attempt fear* | `betterme23` | "i've tried something like this before and given up after the first hard day." | S2 — flag drives commitment language at goal weight + reveal. |
| **N10** | Duty-of-care card on health flags | `betterme12` | "if you're on a GLP-1, we'll lean into *satiety* and skip restrictive windows." | A4 — care-coded, low-effort. |
| **N11** | Two-checkbox health-data consent | `betterme13` | "use my answers to *personalize* my plan" + "send me a *day-2* check-in" | A6 — commitment device + GDPR-friendly. |
| **N12** | Goal weight WITH dynamic reframe card | `betterme24, 25, 26` | "*on pace* · your goal lands ~14 weeks out. energy + clothes-fit shift first; the scale follows." | S1 — the highest-leverage adopt, period. |
| **N13** | "Almost there" chapter wrap (header label only) | `betterme24-27` | (header) "*almost there*" | S4 — sunk-cost amplifier on the highest-friction screens. |
| **N14** | Quantified-rails reveal (`ProgramRevealCard`) | `betterme30` | 5 rails: plan / workouts / food rail / steps / breathwork. CTA: "see my *plan*" | S5 — the cognitive cash-out before paywall. |

### Ship order (Phase 1 v1.1)

**Week 1 (low-risk sweep):** N1, N2, N3 — header redesign + justification sweep + self-narration sweep. No new cases, just edits.

**Week 2 (additive cases):** N4, N6, N7, N8, N9, N13 — bridge screens + 3 psychometric screens + chapter label. Each is one new `OnboardingView` case + one AppStorage flag where applicable.

**Week 3 (the big ones):** N12, N14 — dynamic goal-weight reframe + quantified-rails reveal card. These touch the existing reveal flow + the new program-pivot screens; pair with engineering review.

**Defer to Phase 2:** N5 (cohort count needs real number), N10 (needs v1.1 health-flag screens to ship first), N11 (legal review).

---

## Quick reference: every `betterme#` cite in this doc

`betterme1` (R1) | `betterme2` (S3, A1, table#1) | `betterme3` (S3, A1, table#2) | `betterme4` (A3, A5, N4, N5, N6) | `betterme5` (A2, CA-2, R7, table#3) | `betterme6` (CA-1, R-skip, table#4) | `betterme7` (A2, CA-3, table#5) | `betterme8` (R9, table#6) | `betterme9` (A3, R3, N4, N6) | `betterme10` (CA-4, table#7) | `betterme11` (CA-4, table#7) | `betterme12` (A4, CA-4, N10) | `betterme13` (A6, N11, table#8) | `betterme14` (A2, table#9) | `betterme15` (table#10) | `betterme16` (table#11) | `betterme17` (A2, table#12) | `betterme18` (table#12) | `betterme19` (table#12) | `betterme20` (R4, table#13) | `betterme21` (A2, table#14) | `betterme22` (S2, CA-5, N7, N8, table#15) | `betterme23` (S2, CA-5, N9, table#16) | `betterme24` (S1, CA-6, R6, N12, table#17) | `betterme25` (S1, CA-6, R2, N12) | `betterme26` (S1, CA-6, R2, N12) | `betterme27` (S3, S4, table#18) | `betterme28` (B2) | `betterme29` (B2) | `betterme30` (S5, R5, N14) | `betterme31` (B1, R8) | `betterme32` (B1, R8) | `betterme33` (B3)

All 33 screens cited. 14 verified S/A patterns. 9 patterns to reject with copy-level alternatives. 14 new screens proposed in ship order.
