# JeniFit Food Rail — Implementation Plan

Status: **APPROVED for v1.0.7 ticketing (2026-06-04)**. All founder gates closed per delta v5 (search below for "ALL CLOSED 2026-06-04"). Sprint Week 1 can start; execution tickets live in `food_rail_sprint_v1_0_7.md`. Deltas v2–v6 below supersede the original v1 spec section in any conflict — read top-down chronologically for the full decision trail.
Originally drafted 2026-06-01. Last delta 2026-06-04.
Target ship: v1.0.7 (after 1.0.6 build 11 archive lands and is approved — ✓ DONE 2026-06-03)

---

## TL;DR

- **Build the photo→calorie feature that beats Cal AI on cohort fit** (Gen-Z women 22–35, TikTok-acquired, weight-loss-motivated, anti-shame). Validated demand: PostHog shows 12 of 13 food-rail-tappers converted to paid (~92% correlation), 5× more taps than other "coming soon" rails.
- **The wedge (v2 update): the camera is bidirectional.** Phase 1 ships with a `before / after` toggle on the camera. Pre-eat mode reframes the scan as a *decision aide* ("this is around 480, you've got room"), not a verdict. No competitor positions this way — every calorie app on App Store assumes you already ate it. For an anti-shame cohort, this is the strongest positioning lever and costs almost nothing to add (same pipeline, copy variants, one toggle).
- **Model stack locked:** GPT-5 base primary + Claude Opus 4.7 confidence-gated fallback + Gemini 2.5 Flash food-or-not pre-filter. Cuisine profile from onboarding fed into system prompt as anti-cultural-bias lift Cal AI lacks. Cost at current scale (~80 paid users, $500 MRR): ≈$15/mo. At 1,000 paid: ≈$195/mo. At 10k paid: ≈$443/mo (the original anchor). Model quality is not compromised for cost — Gemini Flash pre-filter ($0.0011/image) and confidence-gated Opus (~20% trigger rate) do the cost work.
- **Nutrition DB:** USDA FoodData Central + Open Food Facts + JeniFit canonical pantry (~2k hand-curated entries covering boba, açaí, protein shakes, oat-milk lattes — the cohort-specific gaps). LLM returns identity + grams only; calorie math happens app-side from the DB join. Never trust the LLM for nutrition numbers.
- **Cohort wedge:** GLP-1-aware protein floor + Jeni interpretation layer + 3 meal slots default + "showing up" streak (not "under-target" streak) + camera→result in one tap. No "AI" word, no red bars, no good/bad food labels. Cycle-aware target adjustment **deferred** — evidence is small and noisy, and we'd need cycle-date infra we don't have.
- **Phase 1 ships in 4–6 weeks** behind premium gate, with pre-eat mode as the differentiation wedge. **Phase 1.5 (week 7–8)** adds restaurant mode + today's-plate timeline. Phase 2 adds two-photo workflow + cycle integration via HealthKit. Phase 3 fine-tunes own model on corrections dataset at ~100k labeled scans — Cal AI's exact playbook.

---

## The wedge

Cal AI's accuracy is commodity (vision is a saturated arms race). Their *moat* is the conversion machine — 123 paywall experiments, 46 trigger points, ~$50M ARR. JeniFit's moat is **the layer above the calorie number**: cuisine profile from onboarding feeds the prompt (anti-bias accuracy lift), Coach Jeni voice interprets ("luteal-phase wednesday, eat the snack" / "GLP-1 days the protein matters more than the deficit"), anti-shame visualizations replace MFP's red bars. **Three wedges stack:** better accuracy on cohort food + better interpretation of the number + **bidirectional camera (pre-eat decision aide, not just retrospective shame)**. Cal AI was just acquired by MyFitnessPal (Mar 2026); their pull from the App Store in April 2026 for deceptive billing signals Apple is actively policing the category. Our existing v1.0.7 pricing compliance work already inoculates us.

---

## Differentiation wedges (v2 additions)

Three positioning levers no competitor in the calorie-tracker category executes for Gen-Z women. All three are designed to make the app feel less like "MyFitnessPal with vision" and more like "the kind app that happens to count calories."

### Wedge 1 — Pre-eat mode (Phase 1)

**The flip:** every calorie tracker on the App Store assumes you already ate it. Snap → log → guilt. JeniFit's camera screen has a **`before / after` toggle** (large, segmented, two states). The vision pipeline is identical; the result card copy changes:

- **After (default — retrospective log):** "*creamy carbonara*, around 520. logged."
- **Before (pre-eat decision aide):** "*creamy carbonara*, around 520. you're at 1,100 today — you've got room. go enjoy it."

This is genuine differentiation. The cohort lives with food anxiety; flipping the question from *"how bad was that"* to *"can I have this"* is permission, not surveillance. Marketing tagline candidate: "*decide* before you eat, not *suffer* after."

**Implementation cost:** ~0.5 day. Camera screen toggle (two states), result-card copy variants (one extra system-prompt branch), one PostHog event `food_scan_mode` with value `before|after`. Same model stack, same schema, same nutrition join. Default = `after` (don't change the mental model of users who expect retrospective logging); `before` is a deliberate flip the user picks.

**Voice rules:**
- Pre-eat copy is encouraging, not warning. Never "watch out for…" or "be careful…"
- Numerical headroom shown matter-of-factly: "you're at 1,100 today — you've got room."
- If pre-eat scan would put the user over target by >300 kcal, Jeni says: "this is around 520 — would put you a bit over. only you know if it's worth it." **Permission, not prohibition.**

### Wedge 2 — Restaurant mode (Phase 1.5)

**The gap:** going out with friends breaks every calorie app. You can't snap 4 dishes at the table without looking obsessive. Restaurant mode is a quick non-camera flow:

1. Cuisine type chips (italian / chinese / japanese / korean / mexican / thai / indian / mediterranean / american / other)
2. How hungry going in (1–5 dots)
3. How full afterwards (1–5 dots)
4. Optional: 1–3 dish names (free text)

Output: a **range** (e.g. "Thai dinner, felt 7/10 full → ~650–900 kcal range"). Logged as a single `food_logs` entry with `source = 'restaurant_estimate'` and `total_kcal_low` + `total_kcal_high` fields. The honest uncertainty is the feature — every other app fakes precision.

**Implementation cost:** ~1.5 days. New `RestaurantEstimateSheet.swift`, two new schema columns (`total_kcal_low`, `total_kcal_high`), one new `source` enum value, one new prompt template (text-only, very cheap call).

**Why this matters:** restaurants are *the* social context where calorie-tracking adherence dies for young women. Cal AI / MFP have nothing for this. The honest range is anti-shame in the most stressful eating moment.

### Wedge 3 — Today's plate timeline (Phase 1.5)

**The gap:** at 10pm, "what did I have today?" should not require scrolling a database. The Home tile gets a secondary state: **photo timeline along a time axis**, each plate as a small rounded thumbnail. No calorie numbers unless tapped — visual memory aide first, math second.

This is also the most theme-native UX in the app: the scrapbook aesthetic (`THEME.md` §3) finally has a literal scrapbook surface. Stickers can land between plates. The italic-Fraunces punch word on the header reads "your *today*" or "today's *plate*."

**Implementation cost:** ~2 days. New `TodayPlateTimelineView.swift` (horizontal scroll, thumbnails from `food_logs.items[].thumbnail_url`, time markers), gated on photo retention opt-in (else show meal-name pills with same layout). Thumbnails are 96×96px, generated app-side at log time from the original scan (never re-fetched from LLM).

**Phase 1.5 grouping rationale:** restaurant mode + plate timeline are both UX additions that need real user feedback from Phase 1 to tune. Ship Phase 1 first (4–6 weeks), let early scanners use the basic flow for 2–3 weeks, then ship Phase 1.5 (1–2 weeks) tuned by what we learn.

---

## Phase sequence

### Phase 1 — v1.0.7 — MVP behind premium gate
**Goal:** prove the loop works. Photo→identification→portion→USDA join→Jeni interpretation→logged. 3 meal slots. Manual correction. Daily ring on Home. Weekly bento on Becoming.
**Time:** 4–6 weeks after 1.0.6 archive approval.
**Decision gate to Phase 2:** ≥40% of paid users scan ≥3×/week in month 1, AND month-2 retention of scanners > non-scanners by ≥5pp.

### Phase 2 — v1.0.8 — accuracy + cohort depth
- Two-photo workflow (triggered by LLM-declared `needs_second_photo`, not blanket)
- HealthKit `menstrualFlow` read → passive luteal-week +60kcal bump for non-HC, non-GLP-1 users
- Voice + text input as photo alternatives
- Recent-foods cache (re-scan of same item = 0 API call)
- Corrections feedback loop visible to user ("we got smarter from your edits")

### Phase 3 — v1.1 — fine-tune own model
- At ~100k user-confirmed corrections, fine-tune Gemini Flash variant or train a CoreML adapter on cohort-specific food
- Cuisine-specialized routing (Korean / Mexican / "girl dinner" patterns get specialized prompts or fine-tunes)
- Evaluate Inference.net or similar deployment platform (Cal AI's exact playbook post-MyFitnessPal acquisition)

### Phase 4 — v1.2+ — premium-tier scale
- Nutritionix Pro ($1,850/mo) once MRR > $50k AND restaurant-meal correction rate documents as quit signal
- Two-stage Claude: Opus perception → Sonnet schema/USDA reconciliation
- Injection-day logging for GLP-1 users + hydration tracking (matches MyNetDiary's $59.99/yr GLP-1 Companion)

---

## Architecture

### Model pipeline (per scan)

```
1. iOS capture → resize to 1024px long edge, EXIF strip, JPEG q0.8
2. Optional pre-filter: Gemini 2.5 Flash ($0.0011/image) → "is this food?"
   - If no, prompt user to retake
3. Primary: GPT-5 base
   - system prompt: user's cuisine profile from onboarding (Korean home-cooked 3×/wk, Mediterranean weekends, etc.)
   - response_format: json_schema strict
   - reasoning_effort: minimal
   - Streaming on; first item visible at ~1.5s perceived
4. Confidence check: if items.min(confidence) < 0.55 OR macro reconciliation fails:
   - Resize photo to 2048px (Opus 4.7 retains; Sonnet 4.6 would downsample)
   - Call Claude Opus 4.7 with GPT's response in context
   - Use Claude's response as final (silent UI update with "refined ✓" pill if delta > 10%)
5. USDA join (app-side or Supabase Edge Function):
   - Walk items[].usda_search_terms in order, take highest-match-score hit
   - Fall through: USDA FDC → Open Food Facts → JeniFit canonical pantry
   - Compute calories = grams × kcal_per_g per source
6. Render result card → Jeni interpretation line
```

### Schema (LLM output)

```json
{
  "items": [{
    "name": "string",
    "usda_search_terms": ["string", "string"],
    "preparation": "raw|grilled|fried|boiled|baked|sauteed",
    "cuisine_hint": "korean|mexican|american|mediterranean|girl_dinner|...",
    "portion_grams": 0,
    "portion_grams_low": 0,
    "portion_grams_high": 0,
    "confidence": 0.0,
    "notes": "string"
  }],
  "plate_type": "single|mixed|bowl|charcuterie",
  "needs_second_photo": false,
  "second_photo_hint": "shoot from 45° to estimate rice depth"
}
```

App-side calorie math from grams × per-source nutrition density. **The LLM never returns calories directly.**

### Supabase schema additions

```sql
-- Food log entries (user-visible)
CREATE TABLE food_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  logged_at TIMESTAMPTZ NOT NULL,
  meal_slot TEXT CHECK (meal_slot IN ('breakfast','lunch','dinner','snack')),
  items JSONB NOT NULL,        -- final items[] after any corrections
  total_kcal NUMERIC,
  total_protein_g NUMERIC,
  total_carbs_g NUMERIC,
  total_fat_g NUMERIC,
  total_fiber_g NUMERIC,
  source TEXT CHECK (source IN ('photo','voice','text','barcode','quick_add')),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Corrections-as-moat data (analytics only, separate from food_logs)
CREATE TABLE food_corrections (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  scan_timestamp TIMESTAMPTZ NOT NULL,
  image_hash TEXT NOT NULL,                 -- perceptual hash, always stored
  image_url TEXT,                            -- nullable; set only if consent_to_train = true
  llm_provider TEXT,                         -- 'openai' | 'anthropic' | 'fallback_used'
  llm_model_version TEXT,
  llm_raw_output JSONB,
  user_corrections JSONB,                    -- diff between LLM and final
  final_logged JSONB,                        -- what got saved to food_logs
  cuisine_profile JSONB,                     -- at time of scan, for ablation
  consent_to_train BOOL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- JeniFit canonical pantry (hand-curated cohort-specific entries)
CREATE TABLE canonical_pantry (
  id UUID PRIMARY KEY,
  name TEXT NOT NULL,
  search_terms TEXT[] NOT NULL,
  cuisine_hint TEXT,
  default_serving_g NUMERIC NOT NULL,
  kcal_per_100g NUMERIC NOT NULL,
  protein_per_100g NUMERIC NOT NULL,
  carbs_per_100g NUMERIC NOT NULL,
  fat_per_100g NUMERIC NOT NULL,
  fiber_per_100g NUMERIC,
  source TEXT,                               -- 'starbucks_official' | 'manual_curator' | etc
  reviewed_by TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
CREATE INDEX ON canonical_pantry USING GIN (search_terms);
```

Existing `weight_logs`, `session_logs`, `day_progress` tables unchanged. RLS on `food_logs` matches existing pattern (user_id = auth.uid()). `food_corrections` is service-role-write-only (Edge Function inserts).

---

## UX spec

### Entry points

- **Home tile** (slot 5 per `home_architecture` memo) — small scrapbook card "today's plate" with current calorie ring. Tap → camera. **No dedicated tab** — keeps tab bar clean per `clean_luxury_aesthetic` memo. [FOUNDER Q11 — confirm: no food tab]
- **Becoming bento tile** — "this week's pattern" with 7-day calorie bar + trend line.
- **Quick-add rail** on Home: small horizontal row of 12 beverage tiles (matcha latte, oat-milk latte, iced coffee, brown sugar boba, fruit tea + boba, protein shake, smoothie, kombucha, sparkling water, wine, beer, cocktail). Tap → 3-tap size/milk/sweetness sheet → logged.

### First-scan onboarding (one-time sheet, opens at first camera tap) — [FOUNDER Q5 confirm]

4 screens max, dismissable on each:

1. **Dietary pattern** — 4 chips: omnivore / vegetarian / vegan / pescatarian. Skip CTA.
2. **Anything you don't eat** — chips: dairy, gluten, nuts, shellfish, eggs, soy, pork, beef + free-text "other." Skip CTA.
3. **Your goal calories** — auto-calculated from Mifflin-St Jeor (existing weight + activity), 15% deficit by default, ±300 kcal slider to adjust. Copy: "we used your weight and activity from earlier."
4. **Optional: snap your usual dinner plate** — calibration scan to anchor portion estimation. Big skip CTA, no shame.

DO NOT bolt these onto the main 57-screen onboarding v2. Trigger at first food engagement only.

### Capture flow

```
Home tile → CameraView (full-screen)
  - Large shutter (primary)
  - Barcode toggle (secondary)
  - "describe instead" → VoiceTextSheet (tertiary, ships v1)
  - Cancel (top-left X)

After shutter:
  ProcessingView (1.5–3s)
  - Jeni voice line: "let me see what we've got"
  - Skeleton shimmer where items will populate

Results card streams items in:
  - Each item: name (italic Fraunces on punch word), portion grams, confidence dot
  - Macro row: cal · P · C · F
  - Plate type chip
  - "looks good" primary CTA → logged
  - "fix something" secondary → CorrectionsSheet
  - If needs_second_photo == true: optional inline prompt "tap to add a 45° angle for sharper portion estimate" — never blocking
```

### Corrections UX (the universal complaint solver)

Tap any item in result card → edit sheet:
- Portion slider: anchored to `portion_grams_low` (min) and `portion_grams_high` (max). Haptic stops at small/medium/large.
- Tap food name → search canonical pantry + USDA + recent foods
- "this isn't right" → describe in words → re-runs LLM with text context, keeps the photo for hash
- Save → updates `food_logs` AND fires `food_corrections` insert with diff

Critical: **the result card defaults to "looks good — log it."** Correction is opt-in. User can always log and move on.

### Drinks + beverages — [research finding]

Photos work poorly for liquids. Default to **quick-add rail** for top 12 cohort beverages (see Entry points). Each opens a 3-tap edit (size: S/M/L; milk: whole/oat/almond/none; sweetness: regular/half/none). Outputs same `items[]` structure as photo flow.

Water is one tap (8oz / 16oz / 24oz). Logged separately as fluids, never counts against calories.

### Daily summary visualization

Home tile shows a 3-ring composition:
- Inner: calories (center label)
- Middle: protein (target = max(90g, 1.4 × bodyWeight_kg) for GLP-1 users, otherwise 0.8g/kg per RDA baseline)
- Outer (thin): fiber bonus

Color discipline:
- Under target: brand palette (warm cream + cocoa pill)
- Over target: ring fills past 100% but **stays in `textSecondary` color** (#7B5959). Never red.
- Caption: "you're at 1,820 today" — no judgment.

### Weekly trend (Becoming bento)

New `FoodWeekBentoTile.swift` matching the `WeightTrendBentoTile` + `StepsBentoTile` pattern (per `project_steps_feature` memo).

- 7-day bar chart with 7-day rolling average overlaid
- Bars in cocoa color; over-target bars slightly desaturated (no red)
- Caption: "this week you're averaging 1,750 — that's tracking with your goal pace"

### Empty state

Not "you haven't logged anything" (shame frame). Soft prompt:
> "ready when you are."

Camera button is the answer. No icon-blowup, no nagging copy.

### "Showing up" streak — [FOUNDER Q9 — confirm name]

Streak counts **days the user logged at least one meal** (not days they stayed under target).

- Auto-grant streak freeze on weekends + week-of-period (if HealthKit menstrual data available in Phase 2)
- Notification voice on streak: "your *showing up* streak's safe — take the day"
- Italic-Fraunces punch word per `feedback_voice_signals` memo

---

## Cycle-aware targeting — defer to Phase 2 [FOUNDER Q1]

**Recommendation: drop per-phase logic in v1.**

Evidence quality is small and noisy:
- Benton 2020 meta-analysis: post-2000 studies ES=0.23, p=0.055 (not significant)
- 2026 Frontiers review: bump ranges 37–122 kcal when significant
- Uchizawa 2025: effect only in runners, none in sedentary women (our cohort)
- ~40% of cohort doesn't qualify (hormonal contraception, GLP-1, perimenopausal)

We don't have cycle-date infra. Adding it costs:
- New onboarding screens (already at 57)
- OR HealthKit `menstrualFlow` read scope (better)

**Phase 2:** HealthKit `menstrualFlow` read as passive opt-in. If user logs periods in Apple Health, apply quiet +60 kcal bump in luteal week (days 14–28) **only if** `hormonalStage` ≠ "hormonal_contraception" AND `glp1_status` ≠ "active". Surface as Jeni note ("your body's working harder this week"), not red bar.

**v1 default:** flat target from Mifflin-St Jeor − 15% deficit. Jeni can reference cycle in copy without us doing precise math.

---

## GLP-1 differentiation — Phase 1 ships this [FOUNDER Q2]

When `glp1_status == "active"`:

1. **Protein floor surfaced** — target = max(90g, 1.4 × bodyWeight_kg). Jeni voice line each morning: "aim for around 95g protein today — your body's rebuilding while it's losing." [recommendation: option b from research, daily Jeni note]
2. **Calorie floor warning** — if logged intake < 1,000 kcal at 6pm, Jeni notes: "fuel matters more than restriction right now. add the snack."
3. **No streak penalty** — GLP-1 users frequently skip meals from suppressed appetite. Showing-up streak design already handles this.
4. **Phase 2:** hydration nudges + injection-day toggle.

This is real differentiation vs Cal AI (GLP-1-blind). MyNetDiary's $59.99/yr GLP-1 Companion is the only competitor here — and they don't have JeniFit's onboarding profile to personalize against.

---

## Privacy + Apple compliance

Critical: Apple Guideline **5.1.2(i)** (Nov 2025) requires explicit, contextual user consent for sharing data with third-party AI. This applies to every GPT/Claude/Gemini call.

### AI disclosure modal — one-time, before first scan — [FOUNDER Q12 copy review]

```
to recognize what's on your plate, JeniFit sends your photo to vision
models from OpenAI, Anthropic, and Google. they don't train on your data.

[Continue]  [Not now]
```

Block scans until explicit accept. Store consent in Supabase profile field `food_ai_consent_at`. Re-prompt if any provider changes.

Note: per locked voice rule, we don't say "AI" in marketing copy. But Apple's 5.1.2(i) requires plain-language disclosure of what's happening — "vision models from OpenAI, Anthropic, and Google" is the legally-safe phrasing that respects both. Found er to review final wording.

### App Privacy Label additions (v1.0.7 submission)

- **Photos** — linked to user, app functionality + analytics (corrections-as-moat opt-in tier)
- **Health & Fitness > Nutrition** — linked, app functionality + analytics
- **Sensitive Info > Menstrual Cycle** — linked (Phase 2 only)
- **Usage Data** — already declared, no change

### HealthKit Dietary Energy write — opt-in, default off — [FOUNDER Q3]

Add to entitlement + `NSHealthUpdateUsageDescription`. Opt-in toggle in Settings: "share my food calories with Apple Health." Default off — many users won't want food data leaking outside JeniFit context. One-time prompt at first-scan completion to ask.

### Photo retention — discard default, 30-day opt-in for correctors — [FOUNDER Q4]

- **Default:** image discarded after analysis. Only `image_hash` + LLM output + correction stored.
- **Opt-in modal at first correction:** "help JeniFit get smarter — we keep your photos for 30 days only when you correct us, to train better." Default off.
- Supabase scheduled function auto-deletes opt-in photos at 30 days.
- Storage cost at 10k paid users with 30% opt-in: ~14GB/mo (well within Supabase Pro plan).

### iCloud + photo sync

Do NOT iCloud-sync food photos. Goes directly to Supabase (if consented) or discarded.

---

## Corrections-as-moat infrastructure

This is the real long-term lever (Cal AI's actual moat per Inference.net case study).

**Storage:**
- Always: image hash + LLM output + correction event (~5KB per scan)
- Opt-in: raw photo at 512px (~80KB) retained 30 days, then auto-deleted

**Phase 3 trigger:** 100k corrected scans. At ~600k scans/mo and ~20% correction rate, this hits in ~3 months of paid scale.

**Fine-tune path:** stream `food_corrections` rows to monthly export. Cohort-specific fine-tune on Gemini Flash variant or CoreML adapter for top-50 ethnic/homemade foods. Cal AI shipped a fine-tuned own-model in ~1 week once they had the data.

---

## Voice + copy lock

Apply existing voice rules from `feedback_voice_signals` + `feedback_copy_succinct_genz`:

- **No "AI"** in user-facing copy. "JeniFit recognizes" or "Jeni reads your plate."
- **No good/bad food labels.** No red bars, no shame triggers, no "exceeded" framing.
- **No labor verbs.** Not "crush your protein goal" — "aim for around 95g protein today."
- **Italic Fraunces on punch words** in headlines. *Showing up* streak. *Today's* plate. Your *becoming*.
- **Lowercase casual.** No title case in copy.
- **Hearts as terminal punctuation only.** Never decorative.
- **Anti-shame phrasing for over-target days:** "you were a little higher today — that's a normal day, not a setback."

Sample Jeni interpretation lines:
- *"looks like creamy carbonara, around 520. that's the right call for a luteal-phase wednesday. protein's a little light — add the chicken if it's there."*
- *"three eggs and toast, ~340. solid start. you're at 88g protein today already."*
- *"matcha latte with oat — ~180. easy yes."*

---

## PostHog instrumentation

Existing event pattern (see `Analytics/AnalyticsManager.swift`). New events:

```swift
// Funnel events
food_ai_consent_shown           // first time the disclosure modal renders
food_ai_consent_accepted         // accepted, can scan
food_ai_consent_declined         // declined, scanning blocked

food_first_scan_started          // shutter tapped for the first time
food_first_scan_completed        // result card rendered
food_first_log_saved             // first meal logged

food_scan_started                // every shutter tap
food_scan_completed              // every result card render
food_scan_correction_opened      // user tapped "fix something"
food_scan_correction_saved       // user saved correction
food_scan_fallback_fired         // Claude fallback triggered

food_quick_add_tapped            // beverage tile tapped
food_voice_input_used            // voice input fallback used
food_text_input_used             // text input fallback used

food_target_overshown            // user logged > daily target — for cohort behavior research only
food_glp1_protein_floor_hit      // GLP-1 user hit protein floor
food_streak_milestone            // 7, 14, 30, 60, 90 day showing-up streak

food_retention_consent_opted_in  // user opted in to photo retention for training
food_retention_consent_opted_out
```

PostHog properties on every event: `cuisine_profile`, `meal_slot`, `confidence_min`, `glp1_status`, `paid_status`. Cohort segmentation for retention analysis.

---

## File / module map

```
PlankApp/
├── Food/                                  -- NEW MODULE
│   ├── FoodModels.swift                   -- FoodLogEntry, FoodItem, MealSlot, NutritionTotals
│   ├── FoodVisionService.swift            -- GPT-5 + Claude fallback + Gemini pre-filter pipeline
│   ├── FoodVisionPrompts.swift            -- System prompts (cuisine-profile-aware)
│   ├── NutritionLookupService.swift       -- USDA FDC + OFF + canonical pantry join
│   ├── FoodCorrectionsLogger.swift        -- corrections-as-moat insert
│   ├── CalorieTargetCalculator.swift      -- Mifflin-St Jeor + GLP-1 protein floor
│   └── FoodSelfCheck.swift                -- DEBUG harness for end-to-end validation
├── Views/
│   ├── Food/                              -- NEW VIEWS
│   │   ├── FoodCameraView.swift           -- Capture screen
│   │   ├── FoodProcessingView.swift       -- Shimmer + Jeni voice line
│   │   ├── FoodResultCardView.swift       -- Streaming items result
│   │   ├── FoodCorrectionSheet.swift      -- Edit single item
│   │   ├── FoodQuickAddRail.swift         -- 12 beverage tiles
│   │   ├── FoodOnboardingSheet.swift      -- First-scan 4-screen onboarding
│   │   ├── FoodAIConsentSheet.swift       -- Apple 5.1.2(i) disclosure
│   │   ├── VoiceTextSheet.swift           -- Voice + text fallback input
│   │   └── FoodWeekBentoTile.swift        -- Becoming tab weekly tile
│   └── Home/
│       └── TodayPlateTile.swift           -- Home tile with 3-ring composition
├── Health/
│   └── HealthKitDietaryEnergyWriter.swift -- Opt-in HealthKit write (lazy)
└── Analytics/
    └── FoodAnalytics.swift                -- PostHog events for food rail
```

Supabase Edge Functions (TypeScript):
```
supabase/functions/
├── food-vision/                           -- Server-side LLM orchestration
│   └── index.ts
├── nutrition-lookup/                      -- USDA FDC + OFF cache layer
│   └── index.ts
└── food-photo-cleanup/                    -- Scheduled 30-day auto-delete
    └── index.ts
```

---

## Open founder decisions

12 questions that gate Phase 1 start. Recommend going through these in a single review session.

| # | Question | Recommendation |
|---|---|---|
| 1 | Cycle bump in v1 or defer to Phase 2 HealthKit? | **Defer.** Evidence small + noisy, ~40% don't qualify, infra cost not justified. |
| 2 | GLP-1 protein floor: silent / Jeni note / dashboard? | **Jeni daily note** (option b). |
| 3 | HealthKit Dietary Energy write: default on or off? | **Default off, opt-in toggle**. Prompt at first-scan completion. |
| 4 | Photo retention: discard or keep? | **Discard default**, opt-in 30-day for correctors only. |
| 5 | First-scan onboarding screens: 4 or 0? | **4 screens** — dietary pattern, exclusions, target review, optional calibration. |
| 6 | Voice + text input fallback in v1? | **Yes, ship in v1** — same pipeline, big friction win. |
| 7 | Nutritionix Pro ($1,850/mo): v1 / v1.1 / v2? | **Defer to v2** past $50k MRR. |
| 8 | Canonical pantry (2k entries): founder / RD / both? | **Founder + Jeni voice** for initial 200 (boba/açaí/protein shake core). Expand via curator later. |
| 9 | Streak name: "showing up" / "becoming" / "streak"? | **"*showing up* streak"** — italic Fraunces on punch word, matches voice signals. |
| 10 | Snacks: 3 + opt-in vs anytime-add? | **3 + opt-in snacks** (locked decision). |
| 11 | Food in tab bar or Home tile only? | **Home tile + camera shortcut, no tab.** Per home_architecture + clean-luxury memos. |
| 12 | AI disclosure copy: "vision models from..." OK? | Founder review final wording. |

---

## Success metrics

**Phase 1 → Phase 2 decision gate (month 1 + 2):**

- ≥40% of paid users scan ≥3×/week in month 1
- Month-2 retention of scanners > non-scanners by ≥5pp
- Correction rate < 30% (above this = trust collapse)
- AI consent acceptance rate > 80% (below = privacy phrasing is wrong)
- Average scan-to-log latency < 4s (TTFT 1.5s perceived + 2s reading + 1 tap)

**Phase 3 fine-tune trigger:** 100k user-confirmed corrections accumulated.

**Cohort retention vs industry baseline:** Industry diet-app D30 is 30–45%. Target: D30 ≥ 50% for scanners (anti-shame design as the differentiator).

---

## Risks + revisit triggers

1. **App Review on Cal AI category.** Apple pulled Cal AI April 2026 for deceptive billing. Our v1.0.7 pricing compliance already inoculates us. Don't relax disclosure copy.
2. **MyFitnessPal-Cal AI integration Q3 2026.** Free-tier accuracy floor jumps. Our moat must be cuisine profile + Becoming feedback loop + anti-shame, NOT "we also scan."
3. **GPT-5.5 / Gemini 3.5 / Claude Opus 5 cadence (every 2–4 months).** Maintain 200-photo in-house gold set. A/B every minor bump. Never hard-code model versions.
4. **Photo storage cost compounding.** Re-evaluate at 100k paid users — if egress costs become non-trivial, drop to image-hash-only and skip raw photo retention entirely.
5. **Cycle-aware claims drifting into femvertising.** Voice lock: Jeni references the cycle gently ("your body might want the snack this week"), never makes precise quantitative claims we can't defend.
6. **Anthropic / OpenAI policy on training.** Verify "don't train on user data" claims still hold at each model contract renewal. If they change, AI disclosure copy must update before next App Store submission.
7. **The 4–6 week timeline assumes 1.0.6 archive lands cleanly.** If TestFlight 1.0.6 surfaces material bugs requiring a 1.0.7 patch, food rail slides accordingly. Don't compress at the expense of voice/safety locks.

---

## Related memory

- `[[project-food-feature-stance]]` — embrace photo→calorie counting; no "AI" word; no good/bad labels
- `[[project-jenifit-vision]]` — multi-data weight-loss program unified by Coach Jeni agent
- `[[project-home-architecture]]` — slot 5 absorbs food + scan as 3-ring TodayHealthStrip
- `[[feedback-food-vision-models]]` — GPT-5 + Opus 4.7 model verdict + corrections-as-moat
- `[[feedback-claude-model-selection]]` — Sonnet default, Opus carve-out for high-res perception
- `[[feedback-engineering-ambition-over-cost]]` — accuracy over cost when cost is rounding error
- `[[feedback-voice-signals]]` + `[[feedback-copy-succinct-genz]]` — voice + copy locks
- `[[feedback-clean-luxury-aesthetic]]` — Chanel/Tiffany restraint over coquette warmth
- `[[feedback-weightloss-ux-principles]]` — trend > number, anti-diet Gen-Z, NSV framing
- `[[project-onboarding-v2-fields]]` — onboarding AppStorage we read from (cuisine, hormonal, GLP-1)
- `[[project-pricing-locked-v1-0-7]]` — premium tier the food rail gates against

---

# Delta v2 — research synthesis 2026-06-03

Status: DRAFT. Supersedes specific decisions in v1 above. Where v1 and v2 conflict, **v2 wins**. Old text left intact for diff trail.

This delta integrates three parallel research investigations (audience research, competitor UX teardown, internal code map) and answers nine founder questions from the 2026-06-03 review session. Sources cited inline where load-bearing.

---

## Findings that changed the plan

1. **Pre-eat mode is the #1 unmet need, not a nice-to-have.** Audience evidence (Cambridge BJPsych Open + PMC ED-behavior studies + creator content) ranks pre-eat permission as the strongest leverage point for this cohort. Was Phase 1.5 in v1 — **now Phase 1 hero**.
2. **Trend, not daily calorie, is the home-screen hero number.** All seven competitors (Cal AI, MFP, MacroFactor, FoodNoms, Noom, Lifesum, Yazio) keep the daily-calorie ring as the dominant number because it drives engagement — but the cohort has explicitly told us via App Store + Reddit + ScienceDirect 2025 WIEIAD study that this drives shame. White-space gap, no competitor will take it because of engagement incentives.
3. **Cal AI's accuracy moat is shallower than the price + acquisition narrative suggests.** ScreensDesign critique + multiple TikTok accuracy tests (@the_riptor) show false-confidence is the actual trust failure. Don't compete on accuracy — compete on **honesty about uncertainty** ("around 480, give or take") and **interpretation layer above the number** (Jeni voice).
4. **Cuisine question must move into onboarding v2, not first-scan onboarding.** Audience research confirms cohort eats cuisine-diverse (korean home-cooked + boba + girl dinner + sweetgreen). Wedge depends on cuisine profile in vision prompt from day one — if it's first-scan only, non-payers never feed it and paywall hero copy can't reference it.
5. **Camera permission is already shipped.** CameraManager.swift already prompts for `.video` access for plank-form check. Food rail reuses the session. **Zero new entitlement, zero new permission prompt for existing users.** This unlocks a much cleaner rollout than v1 assumed.
6. **Only 2 tabs exist (Present + Becoming), not 4.** Confirms locked decision: no food tab. Settings is a menu modal, not a tab. Food lives as a Home tile + Becoming bento.
7. **Post-Ozempic vocabulary is now table-stakes.** "Food noise," "satiety," "protein-priority" are the words 2026 anti-diet creators + ~10% GLP-1 cohort use. Use this language for *all* users, not just GLP-1 flag.

---

## 1. Onboarding additions — questions to add to v2

**New questions to add to `OnboardingView.swift` v2FlowOrder (Act 4, after `glp1Status` case 164):**

### Case 165 — cuisine profile (NEW, required by wedge)

Multi-select chips. Saves to new `@AppStorage("onboardingCuisinePreference")` as comma-separated string. Question: *"what does your week of food usually look like?"*

Chips (multi):
- korean / japanese / chinese / vietnamese / thai
- mexican / latin
- mediterranean / italian
- indian / middle eastern
- american home-cooked
- "girl dinner" — snack plates, charcuterie
- mostly takeout / dining out
- mostly home-cooked

Default selection: none required (skippable). Defaults to "american home-cooked" if skipped — signals to LLM "use generic prompt." [Per audience research, this is the cohort's actual eating pattern, not the "Korean weeknights + Mediterranean weekends" abstraction in v1]

### Case 166 — dietary pattern (NEW, simplifies first-scan onboarding)

Single-select chips: omnivore / vegetarian / vegan / pescatarian. Saves to `@AppStorage("onboardingDietaryPattern")`. Skippable — default omnivore.

### Case 167 — exclusions (NEW, simplifies first-scan onboarding)

Multi-select chips: dairy / gluten / nuts / shellfish / eggs / soy / pork / beef. Saves to `@AppStorage("onboardingFoodExclusions")` as comma-separated. Skippable.

### What stays in `OnboardingView.swift` from existing v2

Reuse these (already collected per code-map verification):
- `foodRelationship` (case 162) — feeds paywall copy + Jeni interpretation tone
- `eatingCadence` + `eatingWindow` (cases 156–157) — informs meal-slot defaults
- `glp1Status` (case 164) — protein-floor logic + vocabulary tone
- `hormonalStage` (case 163) — informs cycle-aware copy (no per-phase math in v1)

### Net change to onboarding length

3 added screens in Act 4. Each is 2-tap (chip-select + continue). At ~5s per screen, adds ~15s to v2 onboarding. Within tolerance.

### First-scan onboarding sheet — collapses from 4 → 2 screens

Now that cuisine + dietary + exclusions move upstream, first-scan sheet becomes:
1. **Your goal calories** (Mifflin-St Jeor result + ±300 slider + MacroFactor-style honesty caption: *"we'll adjust as we learn together"*)
2. **Optional: snap your usual dinner plate** (calibration — big skip CTA)

Two screens, both dismissible. The cuisine + dietary + exclusion questions are now upstream, so existing v1 users (pre-onboarding-v2) get a slim 3-question retro-prompt at first food scan to catch them up — same chips, same AppStorage targets.

---

## 2. JeniFit Method changes

The 14-day arc (`LessonID.day1` … `.day14` in `JeniMethodContent.swift`) **stays as-is**. Do not retrofit food into the existing 14 lessons — they're locked, illustrated, and shipped.

### Add 3 new lessons that drop into the Day-15+ `.generic` loop

Add to `JeniMethodContent.swift` after the day14 case:

**`.foodNoise`** — *"the noise vs the want"* — explains the GLP-1-era vocabulary in plain terms (food noise = constant thinking-about-food, distinct from real hunger). Per audience research, this is the term the cohort actually uses; teaching it reframes the conversation. 2 pages. Illustration: rose-colored thought-bubble cluster.

**`.permissionToFit`** — *"deciding before you eat"* — explains the pre-eat mode hero flow. Plants the language of "permission" and "fits" so when users see the pre-eat result card copy ("you have room"), it reads as familiar, not novel. 2 pages. Illustration: matcha latte being lifted toward a "yes" sticker.

**`.trendOverSnap`** — *"the day that doesn't move the week"* — explains the weekly rolling average as the real signal, individual days as noise. Teaches the user to read FoodWeekBentoTile correctly before they see it. Borrows MacroFactor's "this number will be wrong, we'll learn together" honesty framing. 2 pages. Illustration: a 7-bar mini chart with a smooth line overlay.

### When these ship

Lessons ship in the same release as the food rail (v1.0.7). Earlier-ship would teach a feature that doesn't exist. Triggered from the `.generic` Day-15+ pool, weighted to surface these three lessons preferentially in the first 14 days after food-rail flag flips for a user.

### Illustration pipeline

Same Grok pipeline used for `.day1`–`.day14` per memory `feedback_jenimethod_design.md`. Three 216×216@3x illustrations + ~1 day of curator work. Total scope: ~2 dev-days for content + ~1 day for illustration.

---

## 3. Home screen layout v2.0

### Today (locked, post 1.0.6)

Per code-map (HomeView.swift lines 138–690), the 6-slot cascade is:

0. JenisNoteCard (greeting)
1. JeniMethodJourneyCard (HERO — daily lesson)
2. jenifitWorkoutCard (today's session)
3. WeekProgressStrip (momentum)
4. **Anchor: StepsPulseTile + BreathworkHomeCard**
5. Utility: quickActions + FutureRailRow (food + body-scan teases)

### After v1.0.7 food rail (component swap at Slot 4 + Slot 5)

**Slot 4 becomes `TodayHealthStrip`** — a single horizontal composition tile:

```
┌──────────────────────────────────────────┐
│  ┌─────┐   ┌─────┐   ┌─────┐            │
│  │ 🥣  │   │ 👟  │   │ 🌬   │            │  ← three rings, NOT three cards
│  │food │   │steps│   │breath│           │
│  └─────┘   └─────┘   └─────┘            │
│                                          │
│  you're tracking 1,750 avg this week    │  ← caption is THE TREND, not today's number
│  (your goal: 1,650 — close, easy)       │
└──────────────────────────────────────────┘
```

Tap food ring → CameraView. Tap steps → existing detail. Tap breath → existing detail. **Caption is always weekly avg, never today's daily number.** [Per research finding #2 — trend-as-hero is the white-space gap]

**Slot 5 gains "today's plate" timeline below the existing utility row:**

```
┌──────────────────────────────────────────┐
│  today's plate                            │
│                                          │
│  ☕   🍳    🥗    🧋                       │  ← small plate stickers along time axis
│  8a   10a   1p    4p                     │  ← no numbers visible by default
│                                          │
│  (tap a plate to see what's in it)       │
└──────────────────────────────────────────┘
```

This is the Noms-style visual journal — fits the scrapbook chrome, kills the WIEIAD shame frame, makes food logging feel like Becoming, not MyFitnessPal. [Per audience research unmet need #3 + competitor white-space gap #3]

`FutureRailRow` shrinks: `foodLog` chip is removed (no longer "coming soon"), `weeklyCheckIn` + `bodyScan` remain.

### Pre-eat vs retrospective mode toggle

Lives on CameraView, not Home. Default mode is *retrospective* ("just ate"). Toggle pill at top: `[ just ate | deciding ]`. Switching to `deciding` mode changes:
- Result card copy: *"this is around 480 — your day's at 1,100, so you have room"* instead of logging
- CTA: `[ have it ]` vs `[ skip this one ]`. `have it` → logs. `skip this one` → discards but stores the photo hash for "you considered this earlier" notification opt-in (Phase 2).

---

## 4. Becoming screen layout v2.0

Per code-map (AnalyticsView.swift lines 665–690), the bento order is:

1. coachTile
2. trendTile (weight)
3. forecastTile + milestoneTile (HStack)
4. goalTile + cadenceTile (HStack)
5. **StepsBentoTile**
6. **BreathworkBentoTile**
7. nsvTile
8. FutureRailRow (food + body-scan teases)

### After v1.0.7 (insertion + reordering)

Insert **`FoodWeekBentoTile`** after BreathworkBentoTile (line 681 site). Same `bentoChrome()` helper, same 12pt grid spacing. **Pair it visually with `trendTile` (weight)** — they tell the same story (energy in + energy out → weight trend).

Optional polish: when both food + weight data exist, render a small connection line between trendTile and FoodWeekBentoTile with Jeni copy: *"you're averaging 1,750 with weight trending −0.6 lb/wk. that's tracking."*

### FoodWeekBentoTile contents

```
┌──────────────────────────────────────────┐
│  this week                                │
│                                          │
│  ▆▆▅▆█▅▆     ← 7-day bars (cocoa)        │
│   ─ ─ ─       ← rolling avg overlay      │
│                                          │
│  averaging 1,750                          │
│  tracking your goal pace 🌷              │
└──────────────────────────────────────────┘
```

Rules:
- Over-target bars are **desaturated cocoa**, never red. [Per audience research + Noom reframe + MacroFactor philosophy]
- Caption changes by week-shape:
  - Tracking: *"averaging 1,750 — tracking your goal pace"*
  - Over: *"you ate more this week than usual — happens. tomorrow resets."*
  - Under (warning): *"averaging 1,180 — your body needs more than this. let's aim higher tomorrow."* [GLP-1 + restriction-pattern safety net]
- Empty state from day 1: *"your week shows up here once you've logged a few meals."*

### What `FutureRailRow` becomes after launch

`foodLog` chip removed. `bodyScan` + `weeklyCheckIn` chips remain.

---

## 5. Calorie tracking UX (camera + analytics)

### Camera screen — scrapbook frame, not black camera UI

Open from Home food-ring tap (`fullScreenCover`). Frame is the scrapbook chrome — cream bg, 24pt corners, 1.5pt rose border, soft shadow. Cocoa shutter button (Palette rule: pink for selection, cocoa for primary CTA).

```
┌──────────────────────────────────────────┐
│   ✕                              ⚡       │  ← cancel + flash
│                                          │
│  ┌────────────────────────────────────┐ │
│  │                                    │ │
│  │       [viewfinder feed]            │ │  ← scrapbook frame
│  │                                    │ │     around viewfinder
│  └────────────────────────────────────┘ │
│                                          │
│   [ just ate │ deciding ]               │  ← MODE TOGGLE (pre-eat wedge)
│                                          │
│        ┌──────────────┐                  │
│        │   ●  shutter │                  │  ← cocoa pill
│        └──────────────┘                  │
│                                          │
│   📷 photo    🎙 describe   🍽 i'm out   │  ← three input modes
└──────────────────────────────────────────┘
```

Three input modes as sibling chips:
- **photo** (default) — single shutter scan
- **describe** — voice/text input ("6 oz chicken, rice, broccoli") — MacroFactor's killer flow for restaurants
- **i'm out** — opens RestaurantSheet (cuisine chip + hunger-before slider + hunger-after slider → conservative range)

[The three-mode design covers cohort's three actual eating moments: home-cooked photo, ordered/described, restaurant where photo is impossible. Per competitor research white-space gap #1.]

### AI disclosure baked into UX (Apple 5.1.2(i))

After shutter, processing screen reads transparently (FoodNoms pattern, our voice):

```
   ✿
   looking at your plate...
   ✿
   matching ingredients...
   ✿
   estimating portions...
```

3 lines stream in. Total processing ~2s perceived (TTFT). This IS the 5.1.2(i) disclosure for repeat scans. **First scan only** shows a one-time modal:

> *to read what's on your plate, JeniFit shares your photo with vision models from OpenAI and Anthropic. they don't train on your data.*
> *[continue]  [not now]*

Block scans until accept. Store in `food_ai_consent_at` (Supabase profile). [Voice rule note: "vision models" passes both Apple 5.1.2(i) plain-language requirement and our no-"AI"-word rule.]

### Result card — confidence as language, not numbers

```
┌──────────────────────────────────────────┐
│  ✿  creamy carbonara                     │
│     around 480 ─ give or take a slice    │  ← uncertainty IN COPY, no % number
│     P 22g  C 50g  F 18g                  │
│                                          │
│  ─────────────────────────────           │
│                                          │
│  luteal-phase wednesday, the bowl's      │  ← Jeni interpretation line
│  the right call. add the chicken         │
│  if it's there. 🌷                       │
│                                          │
│  [ looks good — log it ]                 │  ← primary CTA
│  fix something →                          │  ← secondary
└──────────────────────────────────────────┘
```

In **pre-eat mode** the card reads:

```
│  this is around 480.                     │
│  your day's at 1,100. you have room.     │
│                                          │
│  [ have it ]    skip this one →          │
```

[Permission frame, not verdict frame. Per audience research #1.]

### Restaurant "i'm out" sheet

```
┌──────────────────────────────────────────┐
│  what kind of place?                     │
│  [korean] [italian] [mexican] [other]    │
│                                          │
│  how hungry were you going in?           │
│  ────●─────────  (3 of 5)                │
│                                          │
│  how stuffed do you feel now?            │
│  ──────────●───  (4 of 5)                │
│                                          │
│  [ that's about it ]                     │
└──────────────────────────────────────────┘
```

LLM gets (cuisine + hunger_before + hunger_after) and returns a 200-kcal range. Result card reads: *"thai food, around 700–900. felt 4/5 full at the end. tracking."*

This is the white-space play that kills the "I'm out with friends" friction every competitor surrenders on.

### Corrections sheet

Tap any item in result card → edit sheet:
- Portion slider anchored to `portion_grams_low` / `portion_grams_high` (haptic stops at S/M/L)
- Tap food name → search canonical pantry + USDA + recent foods
- "this isn't right" → describe in words → re-runs LLM with text context

Critical: **defaults to "looks good — log it."** Correction is opt-in. The corrections-as-moat data still fires when user corrects; non-correctors generate noise-free baseline data.

### Analytics view (Becoming + Home)

Already covered in sections 3 + 4 above. Key principles:
- Home shows **trend**, not today's number
- Becoming shows **week-shape with smoothed line**
- Calendar heatmap is REJECTED (Cal AI does this; reads as anxiety surface for our cohort)
- Today's-plate timeline lives on Home, not Becoming (it's a daily journal, not a historical view)

---

## 6. Zero-impact rollout strategy

### Feature flag architecture

`@AppStorage("food_rail_enabled")` default `false`. Lands shipped behind the flag in v1.0.7 — flag off means zero new code paths execute.

**Flip mechanism (in order of rollout maturity):**
1. **DebugAuthView toggle** — internal QA only, day 0
2. **PostHog remote config** keyed off user ID + paid status — gradual rollout days 1–14
3. **AppStorage default flip to true** in v1.0.8 — full release after telemetry confirms no regressions

### What current users see when flag flips

**For paying users (when included in cohort rollout):**
- Home Slot 4 silently swaps from `StepsPulseTile + BreathworkHomeCard` to `TodayHealthStrip`
- Becoming gains `FoodWeekBentoTile` after BreathworkBentoTile with empty-state copy
- A new chip appears in Settings menu ("food")
- **No popup. No "new feature!" sheet. No forced onboarding.** [Audience research: over-explanation reads patronizing]

**For non-paying users:**
- Same tile + ring appears visually but tapping = paywall (existing PaywallView, food-variant hero)
- Empty FoodWeekBentoTile shows soft-gated copy: *"see your week here. upgrade to track."*

### Existing v1-onboarding users (pre-onboarding-v2)

Don't have cuisine/dietary/exclusions in their profile. Two handling options:

**Option A (recommended):** First food-scan attempt fires a 3-question retro-prompt — same chips as the new v2 questions, same AppStorage targets. Skippable. After answering, the cuisine wedge fires for them on subsequent scans.

**Option B:** Default to "american omnivore, no exclusions." Show a soft Settings nudge: *"tell us how you eat — sharper results."* No interruption.

Recommend **A** — the 3-question prompt is a one-time cost and unlocks the wedge.

### Camera permission

Already shipped (`AVCaptureDevice.requestAccess(for: .video)` for plank-form check). **No new permission prompt for existing users.** Info.plist `NSCameraUsageDescription` already covers food use case if rewritten generically — verify wording covers both plank + food, may need a minor edit.

### HealthKit Dietary Energy

Separate scope from existing workout write. Default OFF, opt-in toggle in new Food Settings sub-screen. Existing users see no HealthKit prompt unless they opt in.

### Data model migration

Zero schema changes for existing tables. New tables only: `food_logs`, `food_corrections`, `canonical_pantry` (per v1 plan). All RLS-scoped to `user_id = auth.uid()`. Existing `weight_logs`, `session_logs`, `day_progress`, `weight_logs`, `session_ratings` untouched.

### Sync layer

Add `AppSync.upsertFoodLog(_:)` following existing `upsertWeightLog` pattern. Existing sync surface unchanged.

---

## 7. Weight-loss positioning — NOT a calorie tracker

Hard locked. Apply across all surfaces:

### Vocabulary swaps

| Don't say | Say |
|---|---|
| "calorie tracker" / "track calories" | "what you eat" / "your plate" / "your food" |
| "track" (as verb on the food rail) | "log" / "see" / "show up" |
| "exceeded your goal" / "over budget" | "you ate more today — that's a normal day" |
| "crush" / "burn" / "shred" / "earn" | "have room" / "fits" / "tomorrow resets" |
| "calorie deficit" | "tracking your pace" / "you're trending" |
| "guilt-free" / "treat yourself" | (just don't moralize at all) |
| "AI" (in any user-facing copy) | "JeniFit reads your plate" / "vision models" (only in legal disclosure) |
| "weigh in" | "log your weight" / "where you are this week" |

### Frame locks

- **Weight loss is the program. Food is one rail of it.** Never market food as standalone "calorie tracker app inside JeniFit." Always position food data as feeding the weight-loss arc (Becoming's coachTile + trendTile + FoodWeekBentoTile connect into one story).
- **Trend is the hero.** Daily calorie is a footnote. Per audience research: the cohort already knows daily numbers are noise; only competitors keep daily-as-hero because it drives engagement at cost of trust.
- **Permission, not restriction.** Pre-eat mode is the brand statement: *"decide before you eat, not suffer after."* Restaurant mode is the same statement: *"social eating is part of life, not a logging failure."*
- **GLP-1 vocabulary is for everyone.** "Food noise" + "satiety" + "protein-priority" are 2026 mainstream RD talk. Use them across the rail, not gated to GLP-1 flag.

### Paywall hero variant for v1.0.7 launch

Current paywall hero is bodyFocus-personalized. Add a food-variant headline when `food_rail_enabled == true` AND user hasn't yet engaged with the food rail. Sample copy:

> *see what your plate's doing. gently.*
>
> *— what you eat, paired with how you train, drawn against your weekly trend. no red bars. no shame.*

A/B variant kept ready to flip via RevenueCat or PostHog feature flag.

---

## 8. Cohort-specific tools + language locks

These are the audience-research findings made operational.

### Canonical pantry priorities (first 200 entries, founder + Jeni voice)

Curate in this order — these are the daily ritual foods of the cohort per audience research:

1. **Beverages (50 entries):** matcha latte (oat/almond/whole/none/iced), oat milk latte, brown sugar boba, fruit tea + boba, iced coffee + creamer, protein shake variants, smoothie (3 common bases), kombucha, sparkling water, wine (red/white/rosé), beer, common cocktails
2. **Girl dinner staples (40 entries):** charcuterie components (cheese cubes, crackers, grapes, salami), "snack plate" common items, hummus + pita, popcorn (homemade vs movie-theater), cottage cheese bowls
3. **Korean home-cooked (30 entries):** banchan plates, kimchi-jjigae, bibimbap (homemade vs restaurant), gimbap, soft tofu stew, korean fried chicken (KFC + restaurant), bulgogi
4. **Mediterranean / "clean girl" (20 entries):** Greek yogurt + honey + nuts, hummus + veg, grilled salmon plates, quinoa bowls, açaí bowls (homemade vs Pressed)
5. **Restaurant chains relevant to cohort (30 entries):** Sweetgreen bowls (top 6), Cava (top 4), Chipotle (top 4), Starbucks drinks (top 8), Shake Shack (top 3), Chick-fil-A (top 3)
6. **Mexican / Latin (20 entries):** tacos, burritos (homemade vs Chipotle), guac, rice + beans
7. **Other (10 entries):** to fill gaps from corrections data

[Cohort-fit beats USDA breadth for the first 200. Expand via correction-rate analysis after launch.]

### Quick-add rail on Home (12 tiles)

From beverages above, top 12 by audience-research demand evidence:
1. matcha latte (oat) — defaults to medium / oat / regular sweet
2. oat milk latte
3. iced coffee
4. brown sugar boba
5. fruit tea + boba
6. protein shake
7. smoothie
8. kombucha
9. wine (5oz glass)
10. cocktail (generic)
11. beer
12. sparkling water (0 cal logged as fluid only)

Each opens a 3-tap sheet (size / milk-or-mixer / sweetness). Logs same `items[]` structure as photo.

### Yuka-style ingredient peek (Phase 1.5)

When a packaged food is logged (barcode or canonical pantry hit), show a tiny "ingredients" pill below the result card with the top 3 ingredients. No score, no traffic-light, no judgment — just transparency. [Yuka audience overlap is high — this gives the reassurance without rebuilding their score.]

### Language samples for various surfaces

**Home greeting (food-aware):** *"you're at 1,100 with room for tonight. easy day."*

**Empty state Home food ring:** *"ready when you are."*

**Over-target day caption (Becoming):** *"you ate more this week than usual. happens. tomorrow resets."*

**Under-target safety net (GLP-1 or restriction-pattern):** *"averaging 1,180 — your body needs more. tomorrow let's aim higher."*

**First-scan completion notification (NEW user):** *"first plate logged. one of many — your week's just starting to show up."*

**Showing-up streak (week milestone):** *"4 days of showing up this week. that's the rhythm."*

---

## 9. Simplified architecture — perf + cost

### Drop from Phase 1 (defer)

These were in v1 plan; v2 defers to reduce surface area:

- **Gemini 2.5 Flash food/not-food pre-filter** — at $500 MRR (~80 paid users, ~1000 scans/mo), the $0.0011/scan saved is negligible AND adds 200–400ms latency. Add when scale > 10k scans/mo.
- **Claude Opus 4.7 always-on fallback** — start GPT-5-only for v1. Wire Opus fallback as **config-flagged** (Supabase Edge Function env var). Turn on if PostHog `food_scan_correction_rate` > 25% in week 1.
- **Two-photo workflow UI** — schema field `needs_second_photo` ships, UI deferred to v1.0.8 per v1 plan. (Reverses my earlier v2 suggestion to pull forward — research showed pre-eat mode + restaurant mode are higher-impact wedges for this cohort than +11pp portion accuracy on solid foods.)
- **HealthKit menstrualFlow read** — Phase 2 per v1 plan, unchanged.

### Keep from v1 plan (essential)

- **GPT-5 base with cuisine-profile-aware system prompt** — the accuracy wedge
- **App-side calorie math from USDA join** — never trust LLM for numbers
- **Supabase Edge Function as the LLM proxy** — keys server-side, caching, budget cap
- **Corrections-as-moat data from day 1** — image hash + LLM output always; raw photo opt-in 30 days
- **Recent-foods cache (pull from v1.0.8 → v1.0.7)** — cohort eats same boba/matcha/oat-latte daily; 0-API-call repeat scans are free accuracy

### Add to Phase 1 (new in v2)

- **Daily budget kill-switch** in `food-vision/index.ts` Edge Function. Hard cap at $50/day starting (~600 scans = 30× current scan volume). Exceeded → respond with graceful "give us a few hours — we're catching our breath" copy. Logged to PostHog as `food_budget_cap_hit`.
- **Per-user daily scan rate limit** at 30 scans/day. Prevents one user from eating the global budget. Config-driven, server-side.
- **Cost telemetry per scan** logged to PostHog: model used + token counts + USDA hit-rate + correction status. Lets us forecast cost at the cohort level before scaling.

### Final pipeline (simplified)

```
1. iOS capture → resize 1024px long edge → JPEG q0.8 → EXIF strip
2. Send to Supabase Edge Function /food-vision
3. Edge function checks: daily budget OK? user daily cap OK?
4. Call GPT-5 with cuisine-profile system prompt, response_format=json_schema strict
5. App-side USDA + Open Food Facts + canonical_pantry join, app-side calorie math
6. Render streaming result card → Jeni interpretation line
7. If user corrects: fire food_corrections insert (always); if consent_to_train, retain photo at 512px for 30 days
```

Drop Gemini pre-filter. Drop Opus fallback for v1. Two-photo deferred. Net cost at $500 MRR scale: **~$20–30/mo**. At 1000 paid users: **~$200/mo**. At 10k paid: ~$443/mo per v1 plan.

---

## Updated founder decisions

Reconciles v1's 12-question table with v2 research findings. Bold = changed in v2.

| # | Question | v2 answer |
|---|---|---|
| 1 | Cycle bump in v1 or defer? | **Defer to Phase 2** (unchanged from v1) |
| 2 | GLP-1 protein floor surfacing? | **Jeni daily note + apply vocabulary to all users** (extended from v1) |
| 3 | HealthKit Dietary Energy write default? | Default off, opt-in (unchanged) |
| 4 | Photo retention policy? | Discard default, 30-day opt-in for correctors (unchanged) |
| 5 | First-scan onboarding screens count? | **2 screens (was 4)** — cuisine + dietary + exclusions moved upstream into onboarding v2 |
| 6 | Voice + text input fallback in v1? | **Yes, and add "i'm out" restaurant mode in v1** (extended from v1) |
| 7 | Nutritionix Pro: when? | Defer to v2 past $50k MRR (unchanged) |
| 8 | Canonical pantry curator? | **Founder + Jeni voice for first 200, prioritized by audience-research category order** (refined from v1) |
| 9 | Streak name? | **"*showing up* streak"** (unchanged — confirmed by audience research) |
| 10 | Snacks: 3 + opt-in vs anytime? | 3 + opt-in (unchanged) |
| 11 | Food in tab bar or Home tile? | **Home tile + Slot 4 ring (no tab)** — code-map confirms only 2 tabs exist |
| 12 | AI disclosure copy? | **"vision models from OpenAI and Anthropic"** (dropped Google since Gemini pre-filter deferred) |
| **13 (NEW)** | Pre-eat mode in v1? | **Yes, ship as hero mode toggle on CameraView. Audience research ranks this as #1 unmet need.** |
| **14 (NEW)** | Restaurant "i'm out" mode in v1? | **Yes, ship as third input mode alongside photo + describe. White-space gap.** |
| **15 (NEW)** | Today's plate visual timeline on Home? | **Yes, ships in Slot 5 below FutureRailRow. Scrapbook aesthetic + anti-WIEIAD.** |
| **16 (NEW)** | Trend-as-hero or daily-calorie-as-hero on Home ring? | **Trend (7-day rolling avg). Every competitor keeps daily-as-hero; the cohort has told us this is wrong.** |
| **17 (NEW)** | Cuisine question: onboarding v2 or first-scan only? | **Onboarding v2.** Add cases 165–167. v1-onboarding users get 3-question retro-prompt at first scan. |
| **18 (NEW)** | Drop Gemini pre-filter + Opus fallback for v1? | **Yes for both — defer until scale + correction-rate justify. ~$20–30/mo at current scale.** |

---

## Updated phase sequence

### Phase 1 — v1.0.7 — MVP behind premium gate (4–6 weeks)

**Hero:** pre-eat mode + restaurant mode + today's plate visual timeline. The wedges no competitor will copy.

**Ships:**
- Onboarding v2 cases 165–167 (cuisine + dietary + exclusions)
- 3 new JeniMethod lessons (`.foodNoise`, `.permissionToFit`, `.trendOverSnap`)
- Home Slot 4 → `TodayHealthStrip` 3-ring (food/steps/breath) with **trend caption, not daily number**
- Home Slot 5 + Today's Plate timeline (visual journal, no numbers)
- Becoming `FoodWeekBentoTile` after BreathworkBentoTile
- CameraView with 3-mode toggle (photo / describe / i'm out) + pre-eat mode toggle
- AI disclosure modal (first scan) + transparent processing copy (all scans)
- Result card with Jeni interpretation + uncertainty-in-language
- Corrections sheet
- Quick-add rail (12 cohort beverages)
- Food Settings sub-screen
- First-scan onboarding (2 screens) for new users + 3-question retro-prompt for v1-onboarding users
- Paywall food-variant hero
- Supabase: `food_logs`, `food_corrections`, `canonical_pantry` tables; `food-vision`, `nutrition-lookup`, `food-photo-cleanup` Edge Functions; daily budget kill-switch + per-user rate limit
- PostHog: 15+ new events incl. cost telemetry
- Canonical pantry seeded with 200 entries (curated per Section 8 order)

**Does NOT ship:**
- Gemini food/not-food pre-filter (defer until volume)
- Claude Opus 4.7 fallback (config-flagged, off by default)
- Two-photo workflow UI (schema only)
- Cycle-aware target adjustment (Phase 2)
- HealthKit menstrualFlow read (Phase 2)
- Yuka-style ingredient peek (Phase 1.5)

### Phase 1.5 — v1.0.8 — depth + accuracy (4 weeks after Phase 1)

- Two-photo workflow UI triggered by LLM `needs_second_photo`
- HealthKit menstrualFlow read → passive luteal-week +60kcal Jeni note (no math, just copy)
- Yuka-style ingredient peek on packaged foods
- Recent-foods cache visible to user as "you've had this before" pill
- Corrections feedback loop visible ("we got smarter from your edits")
- Bloat-vs-weight Jeni interpretation tying weight + food + cycle data — the agent-vision moment

### Phase 2 — v1.1 — fine-tune own model (trigger: 50k corrections, was 100k)

Per v1 plan: stream corrections to monthly export, cohort-specific fine-tune on Gemini Flash variant or CoreML adapter. Cal AI's playbook. Lowered threshold from 100k → 50k per v2 to compress timeline.

### Phase 3 — v1.2+ — scale (unchanged)

Nutritionix Pro when MRR > $50k AND chain-meal correction rate documents as quit signal. GLP-1 injection-day toggle + hydration tracking.

---

## Open items / founder gate before Phase 1 ticketing

1. **Sign off on the 6 new v2 founder decisions** (13–18 above), especially:
   - Pre-eat mode as Phase 1 hero (not Phase 1.5)
   - Trend-as-hero on Home ring (vs every competitor's daily-as-hero — counter-intuitive but research-backed)
   - Cuisine question in onboarding v2 (adds 3 screens to onboarding)
2. **Walk the Camera UX mockups on real device** once first dev pass exists (founder-walk on v2 chrome + 3-mode toggle + pre-eat copy is critical taste call)
3. **Approve the canonical pantry first-200 curation order** (cohort-fit prioritization in Section 8)
4. **Sign off on paywall food-variant headline copy** (sample in Section 7)
5. **Verify `NSCameraUsageDescription` wording** covers both plank-form + food use cases; minor edit may be needed before submission
6. **Held release dependency unchanged:** 1.0.6 build 11 must archive + approve before Phase 1 ticketing starts. No change from v1 plan.

---

## Related research sources (load-bearing)

External:
- Cambridge BJPsych Open — diet apps ED behaviors qualitative study
- PMC PMC12909219 — calorie tracking + body image
- ScienceDirect 2025 — WIEIAD calorie-overlay shame study
- TechCrunch Apr 2026 — Cal AI App Store removal (Guideline 3.1.2c)
- ScreensDesign Cal AI UI breakdown
- Mobbin Cal AI iOS onboarding flow
- MacroFactor docs (Describe + Expenditure + algorithm-accuracy)
- FoodNoms AI Photo Analysis announcement
- Noom green/yellow/orange system
- Lifesum Day Rating
- MyNetDiary GLP-1 Companion launch announcement (May 2026)
- Yuka growth data (Glossy + Marketer Gems)
- Healthline + NPR — SkinnyTok ban
- Abbey Sharp + Sam Previte anti-diet RD content
- ScienceDirect 2025 WIEIAD study

Internal:
- `HomeView.swift` (lines 138–690) — 6-slot cascade architecture
- `AnalyticsView.swift` (lines 665–690) — bento grid order
- `OnboardingView.swift` (lines 95, 177–194, 1419–1465) — v2 flow + 9 already-collected fields
- `JeniMethodContent.swift` (lines 12–117) — 14-day arc + generic-loop
- `CameraManager.swift` — existing video session reuse
- `MainTabView.swift` (lines 11–40) — 2-tab structure confirmed
- `PaywallView.swift` (lines 21–100) — hero personalization hook
- `AppSync.swift` (lines 269–288) — upsert pattern for `FoodLogRecord`
- `AnalyticsManager.swift` — event-firing convention
- `Tokens.swift` (lines 95–99 + motion section) — scrapbook chrome reuse

---

*End delta v2. Founder review gate before Phase 1 ticketing.*

---

# Delta v3 — Stem-first re-architecture 2026-06-03 (afternoon)

Status: DRAFT. Supersedes v2 where they conflict. v2 founder decisions D13 + D14 stand (cheap toggles, fit "easy plug-in" criterion). D15–D18 rescoped — micro-features become plug-in slots, not v1.0.7 ship-list items. Source-of-truth for v1.0.7 ticketing.

This delta replaces v2's micro-feature emphasis with a **stem-first** philosophy: build the core scan + log loop ruthlessly well, architect for plug-ins so future inputs/modes/tiles drop in cleanly, redesign Becoming around an energy-balance Story Card pattern, and reframe JeniFit's identity as a **weight-loss program** (with food as the primary surface) rather than "plank app + food feature."

Three parallel research investigations 2026-06-03 (afternoon) forced this rewrite:
1. Energy-balance UX patterns for weight-loss apps targeting young women
2. Calorie-burn attribution science + how leading apps surface it ethically
3. Extensible plug-in architecture for iOS food-tracking apps

---

## The reframe — JeniFit IS a weight-loss program

Workout-feature usage is low. TikTok comments on workout posts overwhelmingly ask *"how about food?"* The cohort downloads JeniFit to **lose weight** (per `project_target_audience`). Calorie tracking will be the **most-used surface in the app**, full stop.

This isn't "add a food feature." It's a **product re-positioning**:

| Old frame (workout app + food rail) | New frame (weight-loss program) |
|---|---|
| Home = today's plank session | Home = today's eating + today's movement together |
| Becoming = weight + activity history | Becoming = the weight-loss story across food, movement, weight |
| Food rail = "another feature" | Food rail = the primary surface |
| Plank session = the daily ritual | Plank session = one of several movement inputs (steps, plank, breath) |
| Paywall hero = becoming-ritual workout focus | Paywall hero = "see your weight-loss story unfold" with food at center |
| App Store category = Health & Fitness > Workouts | App Store category = Health & Fitness > Nutrition (or stays HF but copy reframes) |
| Marketing on TikTok = workout demos | Marketing on TikTok = food logging + Becoming reveal moments |

Implications across surfaces:
- **Home Slot 4** (the anchor) becomes **food-first**, not steps-first. Steps + breathwork demote to lateral pills below the food card.
- **Becoming** restructures around the weight-loss story (trend + food + movement + identity), with food data weighted as much as weight data.
- **Paywall hero variant** for v1.0.7 launch makes food the headline value-prop, not a feature add.
- **Onboarding v2** value-prop screens (170 plan reveal, 260 identity projection, 145 celebration) get a copy pass to lead with food + weight-loss program identity.
- **Notification voice** adds food-cadence affirmations as a co-equal pillar with workout cadence.

This reframe is **not undoing** the workout/plank brand — it's promoting food to first-class. Plank stays the brand's signature ritual (the only thing JeniFit owns vs MFP/Cal AI/Noom). But the daily-use surface becomes food.

---

## The Honesty Doctrine

Hard rules for any surface that touches energy-balance math. Backed by:

- **Wallen et al. 2024** (PMC11678767): Apple Watch Series 9 EE estimates "inconsistent across all skin pigmentation groups"
- **Pugh et al. 2025** (npj Digital Medicine living meta-analysis): margins of error for EE "often large, both during exercise and at rest"
- **Bunn et al. 2019** (JMPB 2(3):166): Apple Watch over-estimates calorie burn in females
- **Falter et al. 2019** (PMC6444219): Apple Watch systematically over-estimates EE
- **Pontzer 2024** (Current Biology): no metabolic adaptation during exercise compensation = users eat back inflated burn estimates and gain weight
- **2024 Adult Compendium of Physical Activities** (Herrmann et al., PMC10818145): plank not explicitly listed; light calisthenics 3.5 MET; isometric work is anaerobic + EPOC-dominant
- **A 15-min JeniFit session ≈ 40–80 kcal** for a 65kg woman (light calisthenics extrapolation)

### Rules

1. **Never display "calories burned" as a single daily number on a default surface.** It's the least trustworthy primary number in the entire weight-loss UX stack, and Apple Watch is over-represented in published validation literature while our cohort is overwhelmingly iPhone-only (no peer-reviewed validation exists for iPhone-only `HKQuantityTypeIdentifier.activeEnergyBurned`).
2. **Never auto-credit Apple Health active calories back into a food goal.** Default eat-back = 0% (Lose It! pattern, NOT MFP). Optional opt-in 50% credit toggle in settings (Noom pattern), with copy explaining why.
3. **When burn IS shown, show ranges, not single numbers, and label as estimates.** "this week your movement added roughly 200–350 kcal/day on top of baseline" — never "you burned 287 kcal today."
4. **Per-session JeniFit workouts: surface time and effort, never just kcal.** If kcal must appear, show a conservative range ("≈40–70 kcal") with reframe copy ("the strength gains here outlast the calorie number").
5. **TDEE-from-weight is the only honest signal.** Every 2–3 weeks, reconcile predicted vs actual weight trend (we already have `weight_logs` EMA infrastructure). Surface as **the calibration moment**, not as daily burn. This is MacroFactor's pattern in JeniFit voice.
6. **No "calorie deficit" / "you burned X today" / "need to burn more" copy anywhere.** Voice rule, hard. Adds to the avoid-list in `feedback_post_ozempic_vocabulary`.

---

## v1.0.7 STEM — what ships ruthlessly well

Everything below ships in v1.0.7. Nothing else ships in v1.0.7 from the food rail surface area. Period.

### The core loop (camera → log → trend)

```
Home food card tap
  → CameraView (3-mode toggle visible)
  → User picks photo / quick-add / i'm out
  → Capture → Edge Function /food-vision → GPT-5 with cuisine prompt
  → App-side USDA + canonical pantry join → kcal/macros computed
  → ResultCardView (1 of 2 plate layouts) → Jeni interpretation line
  → "looks good — log it" → FoodLog written → Home updates
```

That's the stem. Five inputs, one pipeline, two render layouts, one log. No additional modes, no timeline, no Yuka-peek, no two-photo, no analytics calendar.

### 3 capture modes (locked, all in v1.0.7)

1. **Photo** (primary) — single shutter, scrapbook frame around viewfinder, cocoa CTA. Mode toggle at top: `[just ate | deciding]` (D13 pre-eat mode).
2. **Quick-add** — horizontal rail of 6 cohort beverages (matcha latte, oat milk latte, iced coffee, brown sugar boba, protein shake, smoothie). NOT 12 as v2 specified — 6 covers 90% of cohort beverage volume; the rest go through photo. Each opens a 3-tap sheet (size/milk/sweetness).
3. **I'm out tonight** (D14) — single tap logs "ate out, ~700 kcal" placeholder with time-of-day-appropriate default. Optional inline cuisine chip ("mexican? korean? italian?") refines the estimate. No hunger sliders.

Voice/text "describe" mode: **NOT in v1.0.7.** Research showed Cal AI doesn't have it, MacroFactor's data-nerd users do but our Gen-Z cohort is laziness-averse not effort-averse. Designed-for in enum (slot ready) but not implemented.

### 2 result-card layouts (locked, all in v1.0.7)

Built from **6 atoms**, composed differently per plate type:

| Atom | Purpose |
|---|---|
| `ItemRow` | One food item: name (italic Fraunces on punch word), portion grams, confidence cue |
| `MacroRow` | cal · P · C · F as a single row |
| `JeniLine` | One-sentence interpretation (cycle/GLP-1/cohort-aware) |
| `ConfidencePill` | "around 480, give or take a slice" — copy, not % |
| `PortionStepper` | Tap an item → slider with low/high anchors + haptic stops |
| `RestaurantRangeBar` | "~700–900 kcal" range visualization for "i'm out" mode |

**2 plate layouts** ship in v1.0.7:
- `SingleDishCard` — for `plate_type: single | bowl`
- `MixedPlateCard` — for `plate_type: mixed | charcuterie | shared`

Restaurant range from "i'm out" mode uses `MixedPlateCard` + `RestaurantRangeBar`.

Plate types `shared`, `charcuterie` ship in schema but render via `MixedPlateCard` until correction telemetry shows the data justifies a dedicated layout.

### Onboarding v2 — 1 new question (not 3)

Reduced from v2's 3-question proposal. Research showed only cuisine is **load-bearing for the wedge** (cuisine-aware system prompt closes the "When Tom Eats Kimchi" 58% gap). Dietary pattern + exclusions can come from first-scan onboarding without losing the wedge.

**Case 165 — cuisine multi-select** (NEW `@AppStorage("onboardingCuisinePreference")`):
- Question: *"what does your week of food usually look like?"*
- Chips (multi-select): korean / chinese / japanese / vietnamese / thai / mexican / latin / mediterranean / italian / indian / middle eastern / american home-cooked / girl dinner / mostly takeout / mostly home-cooked
- Skippable. Defaults to "american home-cooked" if skipped.
- ~5 seconds added to onboarding (one screen, multi-select).

**First-scan onboarding sheet** (collapses from v2's 4 → 1 screen):
- **Goal calories** (Mifflin-St Jeor result + ±300 slider + MacroFactor-style honesty: *"we'll adjust as we learn together"*)
- Optional calibration scan: dropped (low-friction-aversion principle).
- Dietary pattern + exclusions: dropped from onboarding. Added to Food Settings as default-omnivore-with-no-exclusions; user edits later if needed.

### Premium gate

Food rail is paid-only at v1.0.7 launch. Flag: `food_rail_enabled` (PostHog) gated behind RevenueCat `pro` entitlement. Non-paying users see `FoodRailComingSoonCard` (already proven: 12/13 tappers convert per `project_food_rail_v2_locked`).

### Cost telemetry + daily kill-switch (locked, all in v1.0.7)

- Supabase Edge Function `/food-vision` daily budget cap at $50/day (~600 scans = 30× current scan volume). Exceeded → "give us a few hours" copy. Logs to PostHog as `food_budget_cap_hit`.
- Per-user daily rate limit at 30 scans/day. Prevents one user eating the global budget.
- Per-scan PostHog telemetry: model used + token counts + USDA hit-rate + correction status. Forecasts cost before scaling.

---

## Plug-in slots — designed for, NOT built

These are explicitly **architected to drop in cleanly** but **NOT shipped in v1.0.7**. Each becomes a single PR worth of work post-launch once user feedback validates demand:

| Slot | Where it plugs | Rough cost when we ship it |
|---|---|---|
| **Barcode capture** | `FoodCapture.barcode(String)` case in enum + `BarcodeCaptureView` (one new file) | ~2 days |
| **Voice/text describe** | `FoodCapture.voice(URL)` / `.text(String)` cases + view | ~2 days |
| **Recognized routine** ("you usually log matcha now — log it?") | New `RoutineSuggestion` model + 1 Home card variant | ~3 days |
| **Today's Plate visual timeline** (D15 deferred) | New tile in Slot 5 below food card; uses existing FoodLog rows | ~2 days |
| **Yuka-style ingredient peek** | Tap on packaged-food result → ingredient sheet; uses Open Food Facts data already in pipeline | ~1 day |
| **Two-photo workflow** | UI for `needs_second_photo` schema field (already in v1 plan) | ~2 days |
| **Restaurant menu OCR** | New `FoodCapture.menu(Data)` case + Edge Function variant | ~3–4 days |
| **Recent-foods cache** ("had this before — log again") | New table + 1-tap log row at top of camera screen | ~2 days |
| **HealthKit Dietary Energy write opt-in** | New Settings toggle + HKHealthStore write call | ~1 day |
| **Shared-plate portion slider** (charcuterie/group) | New atom `PortionShareSlider` + add to `MixedPlateCard` | ~2 days |
| **Cycle-aware target +60kcal luteal week** | HealthKit menstrualFlow read + CalorieTargetCalculator branch | ~2 days |

Each of these is **easy** because the architecture below guarantees a fixed-cost plug-in surface. The discipline is: **we don't write any of them until the v1.0.7 telemetry tells us which one to write first.**

---

## Becoming redesign — energy-balance Story Card

Per UX research (Pattern E recommended): replace the current bento-grid Becoming with a **scrapbook card stack** that tells the weight-loss story. Hero stays EMA weight trend (only honest weight-loss signal). Below it, three story cards layered like Polaroid stacks.

### New Becoming layout

```
┌──────────────────────────────────────────────┐
│  ☁️  your week                                │
│      [trend curve, EMA smoothed]              │
│              -1.2 lb 🌷                       │
│      moving toward your goal                  │
└──────────────────────────────────────────────┘
          ↓
┌──────────────────────────────────────────────┐
│  ☕  what you ate                             │
│                                              │
│      ▆▆▅▆█▅▆   ← 7-day intake bars           │
│      ─ ─ ─      ← 7-day rolling avg          │
│                                              │
│      averaging 1,750                         │
│      tracking your goal pace                 │
└──────────────────────────────────────────────┘
          ↓
┌──────────────────────────────────────────────┐
│  🌸  how you moved                            │
│                                              │
│      ▌  ▌  █  ▌  █  █  ▌                     │
│      ─ ─ ─ ─ ─ ─ ─                           │
│                                              │
│      8,200 steps · 4 sessions · 3 breaths    │
│      your body's been showing up             │
└──────────────────────────────────────────────┘
          ↓
┌──────────────────────────────────────────────┐
│  🦋  what's changing                          │
│      [barrier-resolved card / mastery curve /│
│       identity affirmation — exists today]   │
└──────────────────────────────────────────────┘
```

### Critical design rules (research-backed)

1. **NO kcal-deficit math anywhere visible by default.** No "net negative this week." No center-of-ring "net" number. The cards are **parallel rails**, not arithmetic. User infers relationship from seeing both alongside the trend.
2. **Movement card never shows "calories burned" as a single number.** Shows steps + sessions + breath count instead. If burn is calculated at all, it's tucked behind a tap into a "your week" expanded view, shown as a range with explainer copy.
3. **Weekly framing, not daily.** Smooths the HealthKit noise. Matches MacroFactor's "wait 2–4 weeks" honesty principle.
4. **Italic Fraunces on identity verbs only** (*becoming*, *moving*, *tracking*, *showing up*) — never on numbers.
5. **Cards reorder by signal density.** Empty food data = "what you ate" card collapses to "log your first meal" empty state. Empty movement = collapses similarly. Trend card always renders.

### What gets cut from current Becoming

| Currently in Becoming | v1.0.7 fate |
|---|---|
| coachTile ("this week" + coach avatar) | KEEP — absorbs into the "your week" hero card |
| trendTile (weight chart) | KEEP — hero of "your week" card |
| forecastTile + milestoneTile (HStack) | DEMOTE — moves into tap-through detail from hero card |
| goalTile + cadenceTile (HStack) | DEMOTE — moves into tap-through detail |
| StepsBentoTile | ABSORB into "how you moved" card |
| BreathworkBentoTile | ABSORB into "how you moved" card |
| nsvTile (non-scale victories) | KEEP — becomes 5th card "what's worked" |
| FutureRailRow | REMOVE — food no longer "coming soon" |

This is a **major Becoming restructure**, not just a tile addition. Bento grid → vertical scrapbook stack. Estimated dev: ~5 days (new `BecomingStackView` + 4 new card Views + data plumbing for "how you moved" aggregate).

### Becoming behind food-rail flag too

The redesign **only ships when food_rail_enabled = true** for a given user. Flag-off users see current bento Becoming unchanged. Flag-on users see Story Card stack. This isolates the redesign risk from the food rail rollout cohort.

---

## Home redesign — food-first Slot 4

Per the program-identity reframe, Slot 4 becomes food-first. Current Slot 4 (`StepsPulseTile + BreathworkHomeCard`) restructures.

### New Slot 4 design (NOT a 3-ring concentric)

Research explicitly **rejected** the v2 concentric ring with center "net" number (precision claim we can't honor). New shape:

```
┌──────────────────────────────────────────────┐
│  🍓  today's plate                            │
│                                              │
│   ╭───────╮                                  │
│   │ 1,420 │  ← soft ring fills as she logs   │
│   │  cal  │  ← cocoa, never red, never %    │
│   ╰───────╯                                  │
│                                              │
│   tracking your week (1,680 avg)             │  ← WEEKLY context, not daily over/under
│   tap to log →                                │
└──────────────────────────────────────────────┘
              ↓
┌─────────────┐ ┌─────────────┐
│ 🚶 5,420    │ │ 🌬 3 breaths │  ← steps + breath as lateral pills
│ steps       │ │ this week    │  ← no calorie attribution
└─────────────┘ └─────────────┘
```

- Food ring shows **today's logged calories**, fills as she logs. No "remaining" or "over by X" copy — that's deficit framing. Just the count.
- Caption is the **weekly average context** + a soft directional indicator ("tracking" / "trending up" / "settling lower").
- Steps + breath demoted to lateral pills below. **No "calories burned" attribution shown anywhere on Home.** Pills show units appropriate to the data (steps as count, breath as session count).
- Tap food card → opens CameraView.

### What NOT to ship on Home in v1.0.7

- **Today's Plate visual timeline** (D15) → plug-in slot, not v1.0.7
- **3-ring concentric (calories/protein/fiber)** → rejected entirely (precision-implying when our data isn't)
- **"Calories burned today" number anywhere** → Honesty Doctrine rule #1
- **Energy-balance summary on Home** → lives in Becoming weekly view, not Home daily

---

## Architecture spec — Packages/PlankFood

New SPM package: **`Packages/PlankFood/`**. Mirrors existing `PlankEngine`, `PlankSync`, `PlankVoice` SPM packages. Enforces import boundary (no UIKit from engine code), parallel compile, can `#if FOOD_RAIL_ENABLED` exclude from a TestFlight build.

### Module layout

```
Packages/PlankFood/
├── Package.swift                     ← mirrors PlankEngine
└── Sources/PlankFood/
    ├── Capture/
    │   ├── FoodCapture.swift         ← enum with associated values
    │   ├── PhotoCaptureView.swift
    │   ├── QuickAddView.swift
    │   └── ImOutTonightView.swift
    ├── Pipeline/
    │   ├── FoodVisionService.swift   ← Edge Function call orchestration
    │   ├── NutritionLookupService.swift ← USDA + OFF + canonical pantry
    │   ├── CalorieMathService.swift  ← THE LOAD-BEARING ALGORITHM (pure fn, fixture-tested)
    │   └── FoodCorrectionsLogger.swift
    ├── Model/
    │   ├── FoodLog.swift             ← SwiftData @Model, VersionedSchema v1
    │   ├── FoodLogItem.swift
    │   └── FoodLogSchemaV1.swift     ← VersionedSchema wrapper
    ├── Result/
    │   ├── Atoms/
    │   │   ├── ItemRow.swift
    │   │   ├── MacroRow.swift
    │   │   ├── JeniLine.swift
    │   │   ├── ConfidencePill.swift
    │   │   ├── PortionStepper.swift
    │   │   └── RestaurantRangeBar.swift
    │   └── PlateLayouts/
    │       ├── SingleDishCard.swift
    │       └── MixedPlateCard.swift
    ├── Tiles/
    │   └── HomeFoodTile.swift        ← Slot 4 card
    └── Flags/
        └── FoodFlags.swift           ← 3-layer flag stack
Tests/PlankFoodTests/
└── Fixtures/                          ← golden LLM responses for snapshot tests
```

`BecomingStackView` and its 4 new card Views live in the main app (not PlankFood) because they touch existing AnalyticsView state.

### Input mode plug-in pattern — enum + associated values

```swift
public enum FoodCapture {
    case photo(Data, mode: PhotoMode)     // PhotoMode = .justAte | .deciding (D13)
    case quickAdd(PantryItemID)
    case imOutTonight(cuisine: CuisineChip?)  // D14, cuisine optional
    // Future plug-ins — slots reserved, NOT implemented in v1.0.7:
    // case barcode(String)
    // case voice(URL)
    // case text(String)
    // case menu(Data)
}
```

One coordinator owns the `switch`. New mode = compiler errors at every switch site = built-in TODO list when we plug in barcode/voice later. No `FoodInputProvider` protocol — **per architecture research: no abstraction until input mode #3 ships**.

### Result rendering — atoms + per-plate layout

6 atoms in `Result/Atoms/`. 2 plate layouts in `Result/PlateLayouts/`. Parent uses `switch` on `plate_type`:

```swift
switch result.plateType {
case .single, .bowl:                      SingleDishCard(result: result)
case .mixed, .charcuterie, .shared:       MixedPlateCard(result: result)
case .restaurantRange:                    MixedPlateCard(result: result, range: ...)
}
```

**No generic `ResultCardRenderer<PlateType>` until plate type #4 lands as a distinct layout.**

### Schema — hybrid Postgres + VersionedSchema SwiftData

**Supabase `food_logs` table:**

```sql
CREATE TABLE food_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  logged_at TIMESTAMPTZ NOT NULL,
  meal_slot TEXT CHECK (meal_slot IN ('breakfast','lunch','dinner','snack')),
  kcal_total NUMERIC NOT NULL,
  protein_g NUMERIC NOT NULL,
  carbs_g NUMERIC NOT NULL,
  fat_g NUMERIC NOT NULL,
  fiber_g NUMERIC,
  plate_type TEXT NOT NULL,
  source TEXT CHECK (source IN ('photo','quick_add','im_out')),
  confidence NUMERIC,
  payload JSONB,                   -- cuisine_hint, needs_second_photo, restaurant_metadata, glp1_context — EVOLVING fields
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE food_log_items (     -- separate table for items array
  id UUID PRIMARY KEY,
  food_log_id UUID REFERENCES food_logs(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  portion_g NUMERIC NOT NULL,
  kcal NUMERIC NOT NULL,
  usda_fdc_id INT,
  canonical_pantry_id UUID,
  position INT NOT NULL
);

-- Validate payload shape so a Swift client typo doesn't corrupt silently:
ALTER TABLE food_logs ADD CONSTRAINT payload_schema_check
  CHECK (jsonb_matches_schema(payload, '{"type": "object", "properties": {...}}'));
```

Use `pg_jsonschema` extension. RLS on `food_logs` + `food_log_items` matches existing pattern (user_id = auth.uid()). Migrations in `supabase/migrations/`, one per change, never edit prior ones.

**SwiftData on-device cache:**

```swift
enum FoodSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] = [FoodLog.self, FoodLogItem.self]
}

@Model final class FoodLog {
    @Attribute(.unique) var id: UUID
    var userId: String
    var loggedAt: Date
    var kcalTotal: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var plateType: String
    var source: String
    var confidence: Double?
    var payloadJSON: Data?         // decoded into [String: AnyCodable] when read
    var createdAt: Date
    var updatedAt: Date
    @Relationship(deleteRule: .cascade) var items: [FoodLogItem] = []
}
```

`VersionedSchema` wrapper from day one even though we won't migrate yet — Apple's own forum guidance is "do this first." Future field additions = lightweight migration, no code. Adapt via `@Attribute(originalName:)` for renames.

### Feature flag — 3-layer stack

```swift
@MainActor public enum FoodFlags {
    public static var isEnabled: Bool {
        #if DEBUG
        if UserDefaults.standard.bool(forKey: "food_rail_dev_override") { return true }
        #endif
        guard PaymentService.shared.hasProAccess else { return false }
        return PostHogSDK.shared.isFeatureEnabled("food_rail_v1")
    }
}
```

- **RevenueCat `pro` entitlement** = paid gate (existing pattern, no new infra)
- **PostHog `food_rail_v1` flag** = rollout ramp (0% → 10% → 100% over weeks 1–3 via PostHog dashboard, no app update)
- **`@AppStorage("food_rail_dev_override")`** = DEBUG-only force-on via DebugAuthView

Flag-off paid users see `FoodRailComingSoonCard` (already proving demand). Flag-off non-paid users see no food UI at all.

### Three "no abstraction until 3+ examples" boundaries (locked)

1. **No `FoodInputProvider` protocol** until input mode #3 ships. Photo + quickAdd + imOutTonight are mode 1, 2, 3 — but they're so different (camera vs picker vs single tap) that protocol abstraction would be Wrong from the start. Revisit when barcode + voice land in v1.0.8.
2. **No generic `ResultCardRenderer<PlateType>`** until plate type #4 lands as a distinct layout. SingleDishCard + MixedPlateCard hand-written; copying when needed is cheaper than abstracting wrong.
3. **No `LLMRouter` abstraction** until model #3 lands. GPT-5 + Opus 4.7 fallback are 2; `Pipeline.run()` is a 40-line function with two explicit calls + confidence branch. Hardcode it.

### The load-bearing algorithm: protect it

`CalorieMathService.swift` is the equivalent of Things 3's conflict-resolution math from v1 (the part they protected during their 2025 sync rewrite). Pure functions, zero UIKit, zero network, 100% fixture-tested. Everything else churns around it. Code review gate: any PR touching `CalorieMathService` requires explicit founder review.

---

## Updated phase sequence

### Phase 1 — v1.0.7 — STEM behind premium gate (4–5 weeks after 1.0.6 archive)

Ships exactly the stem above. No more, no less.

- 3 capture modes (photo + quick-add + i'm out)
- 6 atoms + 2 plate layouts
- Pre-eat toggle (D13)
- Cuisine question in onboarding v2 (case 165 only — not 165+166+167)
- 1-screen first-scan onboarding (goal calories + honesty caption)
- Home Slot 4 redesign (food-first card + steps/breath pills)
- Becoming Story Card stack redesign
- Paywall food-variant hero
- Food Settings sub-screen (dietary pattern + exclusions + HealthKit Dietary Energy toggle + photo retention toggle + AI disclosure status)
- Edge Function cost kill-switch + per-user rate limit + cost telemetry
- 15 PostHog events (food rail funnel + cost)
- Canonical pantry seeded with 100 cohort priority entries (reduced from 200 — ship faster, expand via corrections data)
- Apple 5.1.2(i) disclosure modal (one-time, first scan)
- Plug-in slots **architected but not implemented** for all v1.0.8 features

### Phase 2 — v1.0.8 — listen + plug in (4 weeks after v1.0.7 launch)

Driven by PostHog telemetry from v1.0.7. Ship the 2–3 plug-in slots with highest measured demand. Likely candidates based on prior research:
- Barcode capture (packaged foods are ~30% of cohort intake)
- Recent-foods cache ("had this before — log again")
- Today's Plate visual timeline (if Slot 5 engagement signals demand)
- Restaurant menu OCR (if i'm out adoption is high but corrections-rate signals users want more precision)
- Yuka-style ingredient peek
- HealthKit menstrualFlow read for cycle-aware copy

Each plug-in is ~1–3 days because architecture pre-built the slot. **Don't decide which yet — let telemetry decide.**

### Phase 3 — v1.1 — own model fine-tune (trigger: 50k corrections accumulated)

Per v2 plan. Unchanged.

### Phase 4 — v1.2+ — premium-tier scale

Per v1 plan: Nutritionix Pro past $50k MRR. Cycle-aware target adjustment (math, not just copy). GLP-1 injection-day toggle. Body scan absorbed if telemetry justifies.

---

## Updated founder decisions — D13–D18 reconciled with v3

| # | v2 question | v3 answer |
|---|---|---|
| D13 | Pre-eat mode in v1? | ~~LOCKED as camera toggle~~ — **SUPERSEDED by D54 (delta v6).** Pre-eat *intent* preserved via Jeni copy on the unified result card; the explicit `[just ate / deciding]` mode toggle is removed. |
| D14 | Restaurant "i'm out" mode in v1? | ✓ LOCKED — ships as tap-once placeholder with optional cuisine chip (no hunger sliders per laziness principle) |
| D15 | Today's Plate visual timeline on Home in v1? | **RESCOPED → plug-in slot.** Not in v1.0.7. Architected for; ship in v1.0.8 if telemetry shows Home engagement demands it. |
| D16 | Trend-as-hero on Home ring? | **REPLACED.** v3 redesigns Home Slot 4 entirely (food-first card, no concentric ring with center number). Trend context lives in food card caption + Becoming Story Card hero. Research-validated by all 3 streams. |
| D17 | Cuisine in onboarding v2? | ✓ LOCKED — case 165 only (1 new question, not 3). Dietary pattern + exclusions move to Food Settings defaults, no first-scan onboarding sheet. |
| D18 | Drop Gemini + Opus from v1? | ✓ LOCKED — GPT-5 only in v1.0.7. Opus fallback config-flagged (off by default). |
| **D19 (NEW)** | Becoming stack redesign in v1.0.7? | **YES** — restructure from bento grid to scrapbook Story Card stack. Gated behind food_rail flag (flag-off users see current bento). Estimated 5 dev-days. |
| **D20 (NEW)** | Quick-add rail count: 6 or 12? | **6** — research showed laziness-averse cohort needs simple choice surface. Top 6 cover ~90% of beverage volume. Expand via correction data. |
| **D21 (NEW)** | "Describe" voice/text mode in v1? | **NO** — designed-for in enum, not implemented. Cal AI doesn't have it; cohort is laziness-averse not effort-averse. Revisit in v1.0.8 if telemetry shows users want it. |
| **D22 (NEW)** | First-scan onboarding sheet screens? | **1 screen** (goal calories only). Dietary pattern + exclusions move to Food Settings. Lowest friction path. |
| **D23 (NEW)** | Honesty Doctrine — never show "calories burned" as single number on default surface? | **LOCKED** — research-backed across Wallen 2024, Pugh 2025, Pontzer 2024, Stanford 2017, MFP community failure pattern. Default eat-back 0% (not Noom's 50%). Optional opt-in toggle in Settings only. |
| **D24 (NEW)** | TDEE-from-weight reconciliation in v1.0.7? | **DEFER to v1.0.8** — needs 2–4 weeks of food data to even calibrate. Ship v1.0.7 with static Mifflin-St Jeor target; introduce TDEE-from-weight in v1.0.8 once cohort has data history. |
| **D25 (NEW)** | Program-identity reframe (JeniFit as weight-loss program, not workout app + food)? | **LOCKED** — Home/Becoming/paywall/onboarding all reframe. Plank brand stays as the signature ritual but cedes daily-use surface to food. |
| **D26 (NEW)** | New SPM package `Packages/PlankFood`? | **LOCKED** — mirrors existing PlankEngine/PlankSync/PlankVoice pattern. Enforces import boundary + parallel compile + future TestFlight excludability. |
| **D27 (NEW)** | Three "no abstraction until 3+" rules in code review? | **LOCKED** — no `FoodInputProvider` protocol, no generic `ResultCardRenderer<PlateType>`, no `LLMRouter`. PRs adding any of these without 3 concrete examples are rejected. |

---

## Open items / founder gate before v1.0.7 ticketing

1. **Sign off on D19–D27** above. The most counter-intuitive: D19 (Becoming stack redesign — significant scope but research-validated) and D25 (program-identity reframe — affects marketing copy + App Store positioning).
2. **Decide the Home Slot 4 mock layout in detail** — sketch the food ring + steps/breath pills before dev starts. Quick paper-prototype is fine.
3. **Decide Becoming card stack order** — research recommended Trend → What you ate → How you moved → What's changing. Confirm or revise.
4. **Approve canonical pantry first 100 entries** — cohort-curated, founder + Jeni voice. Order: 25 beverages, 15 girl-dinner staples, 15 Korean home-cooked, 10 Mediterranean, 20 restaurant chains (Sweetgreen/Cava/Chipotle/Starbucks), 15 Mexican.
5. **Confirm paywall food-variant copy** — sample: *"see your weight-loss story unfold. what you eat, how you move, how it's working — drawn against your weekly trend."*
6. **Confirm App Store metadata reframe** — keep Health & Fitness category, update subtitle/keywords/screenshots to lead with food + weight-loss program (not plank).
7. **Held release dependency unchanged** — 1.0.6 build 11 must archive + Apple-approve before v1.0.7 ticketing starts.

---

## What v3 explicitly cuts from v2 (and why)

| v2 wanted | v3 cuts | Reason |
|---|---|---|
| 3 onboarding screens (cuisine + dietary + exclusions) | 1 onboarding screen (cuisine only) | Only cuisine is load-bearing for wedge; others move to Settings defaults |
| 4-screen first-scan onboarding sheet | 1-screen (goal calories only) | Laziness principle; less is more for Gen-Z |
| 12 quick-add beverages | 6 | 6 covers 90% of cohort volume; expand via corrections data |
| Today's Plate visual timeline on Home | Plug-in slot for v1.0.8 | Architected for, ship after telemetry validates demand |
| Restaurant mode with cuisine + hunger sliders | Tap-once placeholder with optional cuisine chip | Laziness principle (D14 founder revision) |
| Voice/text "describe" mode in v1 | Plug-in slot for v1.0.8 | Cal AI doesn't have it; cohort effort-averse |
| 3-ring concentric (cal/protein/fiber) on Home | Single food ring + lateral steps/breath pills | UX research rejected concentric with center "net" number (precision claim) |
| Bento-grid Becoming with food tile added | Full Story Card stack redesign | Program-identity reframe demands restructure, not addition |
| "Calories burned" attribution anywhere | NOWHERE on default surface | Honesty Doctrine, science-backed |
| Two-photo workflow UI in v1 (my earlier flip-flop) | Plug-in slot for v1.0.8 | Pre-eat + Becoming redesign are higher-value v1 wedges |

---

## Related research sources — v3 additions

**Energy-balance UX:**
- MacroFactor Energy Balance Widget (Mobbin teardown + help center)
- MFP Today tab redesign (late 2025)
- Lifesum Life Score (weekly 0–150 qualitative score)
- Noom Weight Loss Zone with half-credit burn (documented methodology)
- WHOOP / Garmin / Oura — composite-score pattern from athlete apps

**Calorie burn science:**
- Wallen et al. 2024 (PMC11678767) — Apple Watch Series 9 EE accuracy
- Pugh et al. 2025 (npj Digital Medicine) — living meta-analysis
- Pontzer 2024 (Current Biology) — exercise compensation literature
- 2024 Adult Compendium of Physical Activities (PMC10818145)
- ACSM EPOC characterization (LaForgia, Withers & Gore 2006)
- Apple HealthKit documentation (no peer-reviewed iPhone-only validation)

**Architecture:**
- WWDC22 #10056 — Compose custom layouts with SwiftUI
- WWDC23 #10195 — Model your schema with SwiftData (VersionedSchema)
- Sandi Metz — The Wrong Abstraction (prefer duplication)
- Rule of Three — don't abstract until the third instance
- PostHog Swift SDK + feature flags docs
- RevenueCat entitlements-as-feature-flags pattern
- Things 3 / Cultured Code 2025 sync rewrite (protect load-bearing algorithm)
- Supabase pg_jsonschema extension for evolving JSONB validation

---

*End delta v3. v3 wins over v2 wins over v1 where they conflict. Ticketing starts after founder gate on D19–D27 + 1.0.6 archive lands.*

---

# Delta v4 — Smooth Integration Spec 2026-06-03 (evening)

Status: DRAFT. Operational supplement to v3 — defines how the food rail integrates smoothly into JeniFit across user journeys, JeniMethod expansion, and surface-by-surface polish. v3 architectural decisions all stand. v4 adds **D28–D32** for journey + content + rollout calls.

Scope: **how the food rail lands smoothly as the major feature.** Out of scope: external marketing positioning, anti-75-Hard hashtag play, App Store metadata reframe (held for v1.1+).

Three findings absorbed from 75-day research:
- **No restart-from-Day-1.** Missed JeniMethod days become "catch up" tiles, never a reset (75 Hard's ~97% failure mechanic, do the opposite).
- **Day 7 / 25 / 50 / 75 milestone beats.** Natural attention moments from fitness-app retention research.
- **Day 76 = soft loop into lighter rhythm.** Never forced re-enrollment.

---

## 1. New user journey — install through Day 7

Day-by-day walkthrough of what a fresh install sees post-v1.0.7 launch. Assumes user installs, completes v2 onboarding (now 57 + 1 cuisine question = 58 screens), hits paywall, subscribes.

### Install → Onboarding → Paywall

Unchanged from v1.0.6 except:
- Onboarding case 165 (cuisine multi-select) adds ~5 seconds
- Reveal sequence at end gains 1 line referencing food: *"we'll meet you at your plate too, when you're ready."*
- Plan reveal echoes cuisine selection back: *"korean home-cooked + matcha lattes — we'll learn your patterns from day one."* (Personalization deepens IKEA effect.)
- Paywall food-variant hero fires (per v3): *"see your weight-loss story unfold. what you eat, how you move, how it's working."*

### Day 0 (immediately post-paywall) — the welcoming, NOT the food prompt

Critical UX call: **do NOT push food scanning immediately after paywall.** Audience research showed friction post-purchase is the #1 activation killer (per `20260602-180612-posthog-3-day-audit--action-list.md`: 62% of payers never started a workout — pushing food would compound the activation gap).

Instead:
- Land on Home with the food card visible but **dimmed/empty-state** (*"ready when you are"* copy)
- JeniMethod Day 1 lesson card is the **hero** post-paywall (existing pattern)
- Food card sits at Slot 4 — visible, not pushed
- No popup, no "scan your first meal!" CTA. The visibility teases without pressure.

### Day 1 — JeniMethod Day 1 (existing lesson, unchanged)

User opens app, sees Day 1 lesson card prominently. Existing lesson covers identity/why-now per `JeniMethodContent.swift:12–117`. Food card visible below but not centered.

JeniMethod Day 1's last page gains **one new line**: *"tomorrow we'll talk about your plate."* Foreshadows Day 2 food intro without forcing today's scan.

### Day 2 — JeniMethod Day 2 NEW (food rail intro lesson)

**New lesson inserted as Day 2** (existing Day 2 "muscle math" shifts to Day 3). This is the **only existing-arc revision** v4 makes — needed to align food intro with cohort attention curve.

Day 2 lesson: *"your plate is the other half"*
- 2-page primer matching existing format
- Page 1: weight loss is energy intake + body's energy use. food is half the math. (No "calorie deficit" language.)
- Page 2: how JeniFit reads your plate. tap → camera. *"try one scan today — anything."*
- Tap-through: AI consent modal fires (Apple 5.1.2(i) baked into UX per v3)
- Camera opens with pre-eat toggle visible. User can scan anything or close.

Whether or not user scans on Day 2, lesson is marked complete. **No failure state.**

### Day 3–6 — JeniMethod existing arc (Days 2→3, 3→4, etc., all shift by 1)

Day 3 (was Day 2) = muscle math. Day 4 (was Day 3) = protein basics. Etc. through Day 14.

Food card on Home remains visible. After the first scan ever (whenever it happens), the food card displays **today's logged count** + caption referencing the week.

### Day 7 — FIRST MILESTONE (existing in app via `EngagementDayCalculator`)

Per 75-day retention research: Day 7 is a natural attention beat. Add a soft "your first week" moment:
- JeniMethod Day 7 lesson gains an opening line: *"you showed up for a week. that's the rhythm."*
- Becoming Story Card hero gets a small *"week one ✓"* badge for 7 days
- NO push notification celebrating it — let user discover. (Notification budget reserved for higher-leverage moments.)

If user hasn't scanned food yet by Day 7: a single passive Home banner appears below the food card: *"the camera's still waiting. anytime."* No urgency. Dismisses on first scan or after 7 days.

---

## 2. Existing user journey — what flag-flip day looks like

For a user who installed pre-v1.0.7 (i.e. existing 1.0.6 user), already past onboarding, already engaging with JeniMethod / weight log / workouts. They open the app on the day `food_rail_enabled` flips to true for their cohort.

### Silent changes (no notification, no announcement)

- Home Slot 4 component swap: `StepsPulseTile + BreathworkHomeCard` → `TodayHealthStrip` (food card hero + steps/breath pills below). Visually different but layout grid identical, so it doesn't feel jarring.
- Becoming bento grid → Story Card stack restructure (per v3 §Becoming redesign). This is the biggest visual change.
- Settings menu adds "food" sub-screen at bottom of list.

### One-time tile pattern (no modal, no popup)

Single soft tile on Home above the food card, dismissable, persists 7 days:

```
┌──────────────────────────────────────┐
│  ✿  jenifit now reads your plate     │
│      tap to try → first scan's free   │  ← (it's free because they're paid)
│      dismiss                          │
└──────────────────────────────────────┘
```

Tap → camera opens (AI consent fires first if not yet accepted). Dismiss → tile removed permanently for this user.

**No popup. No modal. No forced flow.** Per `feedback_onboarding_insights_2026` + audience research: over-explanation reads patronizing.

### JeniMethod handoff for existing users

Existing user's `programDay` (derived from session logs per `project_engagement_day`) is wherever they are. Options:

**Option A (recommended): users continue where they are; new food lessons inject naturally.**
- User at Day 23 stays at Day 23. Next time they open JeniMethod, they see whichever lesson Day 23 corresponds to in the new 75-day arc (likely a food-related lesson per the expansion below).
- Existing users essentially "skip ahead" to food content faster than new users.
- No forced replay of food intro lessons they missed (Days 2, 15-20).

**Option B: existing users get a brief "catch up" sheet at flag-flip.**
- One-time interstitial offering: *"new food lessons just dropped. start with the basics, or jump ahead?"*
- Adds friction. Likely off-brand.

**Recommend A.** Existing users are engaged enough that they don't need re-onboarding; the food card on Home + the next JeniMethod lesson are enough discovery.

### Becoming Story Card transition for existing users

The bento → Story Card restructure is significant. Existing users have weight data; the trend card lights up immediately. Existing users may not have food data on flag-flip day → "what you ate" card shows empty state: *"your week's plate shows up here once you log a few meals."*

This empty card is **load-bearing** — research showed seeing the slot before it has data is better than late-inserting it after first log. Sets expectation.

---

## 3. JeniMethod 75-day arc — content expansion

Goal: extend from 14 lessons → 75 lessons. Existing 14 days stay (with one minor reorder: new Day 2 = food intro, original Day 2 → Day 3, all subsequent existing days shift +1 so Day 14 becomes Day 15). Add 60 new lessons (Days 16–75).

Per user descope: **content volume, not structural reframe.** No external marketing arc, no "75 days of becoming" branding, no cohort launch dates. Just more lessons.

### Existing 14 → renumbered 15 days (Days 1–15)

- **Day 1**: identity / why-now *(existing Day 1, unchanged)*
- **Day 2**: *your plate is the other half* **(NEW — food rail intro)**
- **Day 3**: muscle math *(was Day 2)*
- **Day 4**: protein basics *(was Day 3)*
- **Day 5**: protein continued *(was Day 4)*
- **Day 6**: habit formation *(was Day 5)*
- **Day 7**: habit deepening *(was Day 6)*
- **Day 8**: sleep basics *(was Day 7)*
- **Day 9**: sleep + recovery *(was Day 8)*
- **Day 10**: barrier-lowering *(was Day 9)*
- **Day 11**: barrier-resolved follow-up *(was Day 10)*
- **Day 12**: hot girl walk *(was Day 11)*
- **Day 13**: movement variety *(was Day 12)*
- **Day 14**: plank mastery intro *(was Day 13)*
- **Day 15**: first 2-week reflection *(was Day 14 "completion" — repurposed as Act 1 close)*

### Days 16–35 — food rail depth (20 NEW lessons)

Theme: building food literacy and the eating-+-movement-together story. Each lesson includes a "today's prompt" that connects to a food rail action.

- **Day 16**: food noise vs real hunger *(GLP-1-era vocab for all)*. Prompt: try the pre-eat mode once today.
- **Day 17**: the trend, not the day. Prompt: open Becoming, look at your week's pattern.
- **Day 18**: portion truth — why estimates are estimates. Prompt: try the corrections sheet once.
- **Day 19**: protein-priority math. Prompt: scan a high-protein meal, see Jeni's note.
- **Day 20**: the matcha latte question (cohort beverages). Prompt: use the quick-add rail.
- **Day 21**: girl dinner is a meal too. Prompt: log a girl dinner via quick-add.
- **Day 22**: 3-week reflection. (Day 21 = end of week 3, soft check-in.)
- **Day 23**: restaurant strategy intro. Prompt: try "i'm out tonight" mode.
- **Day 24**: comfort food permission. Prompt: log a comfort meal without changing the rating.
- **Day 25**: **MILESTONE — quarter-complete moment.** Identity check-in re-asks Q140 ("who are you becoming"). Lesson reflects on what the user collected so far (plank Mastery curve + weight EMA + food logs count).
- **Day 26**: the cycle question intro *(awareness only, no per-phase math)*.
- **Day 27**: PMS comfort, soft frame. Prompt: log without judgment this week.
- **Day 28**: hot girl walk + plate together. Prompt: log a meal + take a walk after.
- **Day 29**: water + satiety. Prompt: water log on Home (existing).
- **Day 30**: 4-week reflection. (End of month 1.)
- **Day 31**: sleep + cravings. Prompt: notice tomorrow's hunger after tonight's sleep.
- **Day 32**: stress eating, gently. Prompt: log a stress-eating moment if it happens, without renaming it.
- **Day 33**: the bloat truth (cycle + sodium + water vs scale weight). Prompt: weigh, then look at the trend curve.
- **Day 34**: the snack truth. Prompt: log a snack as a snack (not a "treat").
- **Day 35**: the dessert frame. Prompt: log a dessert as a meal component, not a sin.

### Days 36–55 — depth + cycle + plateau (20 NEW lessons)

Theme: the body changes, the math gets nuanced, the program deepens.

- **Day 36**: 5-week reflection. The first plateau possibility.
- **Day 37**: weight trend literacy (EMA explained simply). Prompt: trust the line, not the dot.
- **Day 38**: plateau prep — what to expect around Day 45.
- **Day 39**: the energy curve over the cycle. Awareness only, no math.
- **Day 40**: protein density swaps. Prompt: scan a meal, see if Jeni flags the swap.
- **Day 41**: hunger types — physical vs emotional vs habit.
- **Day 42**: 6-week reflection. Halfway-but-not-halfway moment.
- **Day 43**: fullness types — comfortable vs stuffed.
- **Day 44**: hydration depth. Prompt: water count this week.
- **Day 45**: the "second mountain" — when the easy gains taper.
- **Day 46**: NSV (non-scale victories) literacy. Prompt: log one NSV.
- **Day 47**: the comparison killer (social media + body image).
- **Day 48**: photo evidence (not progress photos — clothing-fit, energy, mood).
- **Day 49**: the rest day. Prompt: take one.
- **Day 50**: **MILESTONE — halftime mirror.** Data-grounded reflection from EMA + Mastery curve + food log count. *"this is what 50 days of showing up looks like."*
- **Day 51**: maintenance mindset preview.
- **Day 52**: the want vs the should — eating from desire vs obligation.
- **Day 53**: reverse-diet intro (gentle).
- **Day 54**: the cheat-day myth. Prompt: log every day this week, no "off."
- **Day 55**: cycle phase awareness deep dive (still no math, just understanding).

### Days 56–75 — identity completion + maintenance (20 NEW lessons)

Theme: the woman you're becoming is becoming permanent.

- **Day 56**: 8-week reflection. The data tells a story.
- **Day 57**: social pressure handling — when others notice.
- **Day 58**: the identity-anchored frame ("I am someone who…").
- **Day 59**: GLP-1 vocabulary recap *(if user flagged glp1Status active, this lesson personalizes)*.
- **Day 60**: protein-priority recap with new depth.
- **Day 61**: the long-term-trend literacy — months, not weeks.
- **Day 62**: 9-week reflection. The taper question.
- **Day 63**: maintenance kcal — what changes when goal is reached.
- **Day 64**: ongoing trend reading — how to weigh without anxiety.
- **Day 65**: plank mastery — your time vs Day 14's time.
- **Day 66**: identity verbs ("I move, I eat, I track").
- **Day 67**: the next-75-days question.
- **Day 68**: friends + accountability (no leaderboards — soft cohort frame).
- **Day 69**: 10-week reflection. The body's new normal.
- **Day 70**: the maintenance ritual — what daily looks like at goal.
- **Day 71**: food noise revisited — has it quieted?
- **Day 72**: the eating window question (if user flagged eatingWindow restricted).
- **Day 73**: the becoming card — a data-grounded reflection (NO before/after photo). *(In-app only. NOT a share asset per descope.)*
- **Day 74**: the celebration day — what you collected.
- **Day 75**: **COMPLETION RITUAL.** Identity statement re-asked. Mastery curve, EMA, food log count, NSVs, barrier-resolved count all shown as evidence. *"you became someone who…"*

### Day 76+ — soft loop into lighter rhythm

Per 75-day research: **never force re-enrollment.** At Day 76:
- JeniMethod card on Home keeps surfacing daily lessons but from a lighter "maintenance" pool (existing `.generic` loop infrastructure, expanded with new maintenance-themed lessons).
- Becoming Story Card hero gets a soft "completed program ✓" badge.
- No popup, no forced "start again" CTA. User can tap the badge for a quiet option to start a new 75 if they want.

Day 76 maintenance pool: a smaller set (~15 lessons) cycling weekly, focused on long-term identity reinforcement, plateau navigation at maintenance, and seasonal eating themes.

### Missed-day handling — "catch up" tiles, NEVER restart

If user opens app and missed a day (programDay advanced without lesson tap):
- JeniMethod card on Home shows the missed lesson as a **catch-up tile** with copy: *"day 12 is here when you're ready"*
- Lesson is tappable; advancing through it marks it complete; programDay continues to advance daily regardless
- Maximum 3 catch-up tiles visible at once (oldest gets dismissed/archived)
- **Day-counter advances every calendar day. Never resets. Never penalizes.**

This is the explicit anti-75-Hard mechanic — research showed restart-from-Day-1 has ~97% failure rate. JeniMethod is the inverse.

### Illustration / content cost estimate

- 61 new lessons × 1 illustration each (216×216@3x, paper-craft style, Grok pipeline per existing pattern) = 61 illustrations
- At ~$2–5 per illustration via Grok = $120–$305 in generation cost
- Curation + Photoshop touch-up: ~3–4 weeks of part-time work for one curator
- Lesson copy writing: ~2 weeks for 61 lessons at 200–300 words each (founder + Jeni voice)
- TOTAL: ~6–8 weeks of content work, parallelizable with dev work on v1.0.7

**Recommendation:** ship v1.0.7 with **Days 1–30 only** (16 new lessons beyond existing 14). Days 31–75 land in v1.0.8 content-only update (no code ship needed; just data + assets via Supabase content table or static bundle update). This gives content team time without blocking dev.

### Content-data delivery shape

Move JeniMethod lessons from hardcoded `JeniMethodContent.swift` enum cases to a **Supabase content table** (`jenimethod_lessons` with day_number, title, pages JSONB, illustration_asset_name). App fetches + caches locally. New lessons land via content update, no app submission needed.

This is a small additional architecture commitment but pays back massively when adding the back-half of the 75-day arc post-launch.

---

## 4. Surface-by-surface integration polish

### Notifications — food cadence within 5/wk research ceiling

Per `feedback_notification_voice` + `project_trial_week_notifications`: the 5/wk ceiling is the research-backed limit before reactance kicks in. v1.0.7 already uses 4 categories (daily_reminder, trial_end, weekly_milestone, post_session_followup). Food adds:

- **`food_first_log_nudge`** — fires ONCE on Day 3 if user hasn't scanned by then. Copy: *"the camera's still waiting. anytime."* Soft, single fire, never repeats.
- **`food_evening_check_in`** — fires opt-in only (Settings toggle, default OFF). For users who opted in, fires at user-configured time (default 8pm) IF they've scanned at least 1 meal today: *"3 meals logged. your week's averaging 1,750 — easy tracking."* Skips if no meals logged (anti-shame).
- **NO "you forgot to log lunch" notifications.** Logging guilt is the cohort-killer per research.
- **NO daily food summary notifications.** Becoming surface holds that data.

Total food notifications: 1 mandatory + 1 opt-in = max 2/week. Adds to the 5/wk ceiling: well within budget.

### Food Settings sub-screen

Settings menu adds "food" entry at bottom. Sub-screen contents:

```
┌──────────────────────────────────────┐
│  ← food                              │
│                                      │
│  CALORIE TARGET                      │
│  1,650 kcal/day                      │
│  [edit] — recalculate from weight    │
│                                      │
│  DIETARY PATTERN                     │
│  omnivore                            │
│  [edit]                              │
│                                      │
│  EXCLUSIONS                          │
│  none                                │
│  [edit]                              │
│                                      │
│  CUISINE PROFILE                     │
│  korean, mediterranean, girl dinner  │
│  [edit] — affects how Jeni reads     │
│  your plate                          │
│                                      │
│  ─────────────────────────────       │
│                                      │
│  HEALTHKIT                           │
│  share with Apple Health   [○ off]  │  ← default off
│                                      │
│  EVENING CHECK-IN                    │
│  remind me at 8pm        [○ off]    │  ← default off, opt-in
│                                      │
│  ─────────────────────────────       │
│                                      │
│  PRIVACY                             │
│  photo retention: discarded after    │
│  scan (default)                      │
│  [keep for 30 days when I correct]   │
│                                      │
│  ai disclosure                       │
│  vision models from OpenAI and       │
│  Anthropic. they don't train on      │
│  your data. [learn more]             │
│                                      │
│  ─────────────────────────────       │
│                                      │
│  EXPORT MY DATA                      │
│  request all my food logs as CSV     │
│  [request]                           │
└──────────────────────────────────────┘
```

Standard scrapbook chrome. Slots into existing `SettingsSheet` enum as `.foodSettings` per code-map.

### Paywall sequencing — when does food gate fire

Three paywall moments in JeniFit currently:
1. **Hard paywall post-onboarding** — gates the entire app (per `project_pricing_locked_v1_0_7`)
2. **Transaction-abandon downsell** — 25% off, fires when user declines initial paywall
3. **In-app upsells** — currently NONE (clean architecture)

Food rail integration:
- **NO new paywall.** Food rail is gated by existing `pro` entitlement. Non-paying users see `FoodRailComingSoonCard` (per v3) → tap routes to existing hard paywall.
- Paywall hero variant for v1.0.7: food-led copy per v3 (*"see your weight-loss story unfold. what you eat, how you move…"*).
- No spin-wheel, no second-chance flow. Already locked clean per `project_trial_downsell_locked`.

### Home integration — sequencing & priority

Slot order on Home after food rail flips (per v3 redesign + journey alignment):

1. JenisNoteCard (greeting) — unchanged
2. **JeniMethod card (HERO)** — daily lesson with food prompt when applicable
3. jenifitWorkoutCard — today's workout
4. WeekProgressStrip — momentum
5. **TodayHealthStrip** — food card hero + steps/breath pills (v3)
6. quickActions + (FutureRailRow shrunk to weeklyCheckIn + bodyScan)

Key principle: **JeniMethod stays the hero** because the daily ritual frame is what the cohort retains around. Food card is the second draw, anchor slot. **Do NOT promote food card above JeniMethod.** The lesson tells the user what to do; the food card lets them do it.

### Becoming integration — Story Card holds it together

Per v3: bento grid → Story Card stack. Food data integrates into 2 of 5 cards:
- **"What you ate"** card (food primary)
- **"How you moved"** card (steps + sessions + breath count, NEVER kcal-burned)
- **"Your week"** hero card (weight trend EMA + soft directional indicator)
- **"What's changing"** card (barrier-resolved + mastery curve + identity affirmation — existing nsvTile content)
- **"What's worked"** card (existing nsvTile expanded)

Cards reorder by signal density (empty food = collapses to empty state). Trend always renders.

---

## 5. v1.0.7 launch-week sequencing

Phased rollout to catch problems before scale-out. PostHog feature flag `food_rail_v1` drives cohort logic.

### Day 0 — submit + flag off

- Archive submits to Apple. Flag OFF for all users.
- 1.0.7 build behind flag = invisible. App ships visually identical to 1.0.6 until flag flips.

### Day 1–3 — internal QA (5–10 users, internal team + founder family)

- Flag ON for specific PostHog user IDs (internal list).
- Test full flow: AI consent → first scan → log → JeniMethod Day 2 → Becoming Story Card → Food Settings.
- Watch for: crash rate, scan latency, USDA hit rate, correction rate, cost per scan, edge function error rate.
- Fix any P0 issues. If none, ramp Day 4.

### Day 4–7 — 10% paid users

- Flag ON for 10% of paid users (PostHog random rollout).
- Monitor: scan rate per user, correction rate, paywall conversion delta (does food rail being visible to non-paid affect download→paid?), JeniMethod Day 2 completion rate.
- Cost telemetry watch: daily budget consumption vs $50/day cap. Per-user scan distribution (any rate-limit hits?).

### Day 8–14 — 50% paid users

- If Day 4–7 metrics are clean (no spike in crash rate, correction rate ≤25%, cost within budget), ramp to 50%.
- Watch for cohort-specific issues: TikTok-acquired users vs IG vs friend acquisition different behaviors?
- Continue measuring: does food rail visible-but-not-engaged change Day 7 retention?

### Day 15+ — 100% paid + open to new users

- Flag ON for all paid users.
- New downloads land on v1.0.7 with food rail enabled by default.
- New user journey from §1 of this delta becomes the default first-week experience.

### Rollback plan

- PostHog dashboard flip to 0% reverts everyone to flag-off in minutes.
- Becoming Story Card redesign also gated by `food_rail_enabled` flag — rollback reverts bento grid too.
- JeniMethod content delivered via Supabase content table → can revert Day 2 reorder server-side without app push.

---

## 6. New founder decisions D28–D32

| # | Question | Recommendation |
|---|---|---|
| D28 | JeniMethod Day 2 reorder — slot new food intro at Day 2 (shifting existing Day 2–14 to Day 3–15)? | **YES.** Aligns food intro with cohort attention curve. One-time minor restructure of existing arc; no other days touched. |
| D29 | JeniMethod 75-day expansion phasing — ship Days 1–30 in v1.0.7, Days 31–75 in v1.0.8 content-only update? | **YES.** Content team needs 6–8 weeks; don't block v1.0.7 dev. v1.0.8 content update via Supabase content table = no app submission. |
| D30 | Move JeniMethod content from hardcoded enum cases to Supabase content table? | **YES.** Unblocks back-half delivery without app submissions. Small architectural commitment, large content ops payback. |
| D31 | Missed-day "catch up" tile pattern (NEVER restart from Day 1)? | **YES, LOCKED.** Anti-75-Hard mechanic, research-backed. Day-counter always advances; missed lessons surface as catch-up tiles, never penalize. |
| D32 | Launch-week ramp 10% → 50% → 100% over 14 days? | **YES.** Standard pattern. Cost kill-switch + correction rate are the gates. If either spikes, freeze ramp. |

All v3 decisions D13–D27 stand unchanged.

---

## 7. What v4 does NOT decide (intentional)

- **External marketing positioning** (75-day hashtag, anti-75-Hard reframe, January cohort drop, Becoming Card share asset) — descoped per founder direction
- **App Store metadata reframe** (category, subtitle, keywords) — held for v1.1+ SKU rename window
- **App name / Bundle ID rename** — v1.1+ per `project_app_name`
- **Cycle-aware target math** (per-phase kcal adjustment) — Phase 2 / v1.0.8 per v1 plan, unchanged
- **GLP-1 injection-day toggle** — v2+ per v1 plan, unchanged
- **Sweat/Centr-style cohort launch dates** — not needed for solo continuous-enrollment model

---

## 8. Open items / founder gate before v1.0.7 ticketing

In priority order:
1. **Sign off on D28–D32** (above). D29 (content phasing) and D30 (Supabase content table) are the load-bearing calls.
2. **Walk the new user journey mock end-to-end** once Camera + Result Card v1 are built. Tap-by-tap on a real device.
3. **Approve Day 2 lesson copy + first 16 new lesson titles** (Days 16–30 needed for v1.0.7 ship).
4. **Confirm Food Settings sub-screen layout** (sketch above) before dev.
5. **Confirm the "one-time soft tile" pattern** for existing users (no popup, dismissable banner above food card).
6. **Held release dependency unchanged** — 1.0.6 build 11 must archive + Apple-approve before v1.0.7 ticketing starts.

---

*End delta v4. v4 layers on v3 (operational supplement, not replacement). All v3 architectural decisions stand. Ticketing starts after founder gate on D28–D32 + 1.0.6 archive lands.*

---

# Delta v5 — Design review locks 2026-06-03 (late evening)

Status: DRAFT. Captures ~40 design decisions locked via two parallel UX designer reviews (conversion-funnel + Gen-Z cohort-fluency specialists) + first-screen pattern research. Supersedes v4 where they conflict. **1.0.6 build 11 has SHIPPED.** Hard gate for v1.0.7 cleared.

## Why v5 exists

After v1.0.6 shipped, a full design review pass on the v1.0.7 surfaces produced (welcome / onboarding question reorder / calorie scan flow / Home / Becoming) was run via two UX designer agents:

- **Designer A** — senior subscription-funnel designer with women's-weight-loss app experience. Critique focused on conversion mechanics, paywall placement, progress bars, skip buttons, peak-end rule, structural choices vs design churn.
- **Designer B** — Gen-Z cohort cultural specialist with app experience in cohort rotation (Yuka, BeReal, Pinterest, Lemon8, Flo, Co-Star, intuitive-eating apps). Critique focused on cultural fluency, voice landing, anti-shame sensitivity, identity authenticity, app-rotation texture, privacy/Big-Tech-distrust signals.

Their critiques mostly didn't conflict — designer B caught cohort-specific traps designer A wasn't briefed to see (Apple Watch ring closure-debt trauma, /75 ↔ 75 Hard adjacency, streak-loss as #1 cohort churn driver, "becoming" overuse, etc.). Founder ratified the bulk of both designers' calls.

Also a parallel research stream on first-screen patterns for weight-loss apps in 2026 confirmed the existing `feedback_first_screen_strategy` memory stance (no body imagery, no creator credit on screen 1) is even MORE defensible post-TikTok-ad-policy + #SkinnyTok ban + Apple body-classification conservatism.

---

## Major locks summary (the load-bearing ones)

1. **Ring → Bar on food card** — Apple Watch closure-debt trauma is a real cohort risk. Cocoa not red wasn't sufficient; the *shape* itself triggers. Bars on Home food card + result card + Becoming food card.
2. **Drop "/75" display in UI** — keep arc length internal but UI never shows the denominator. 75 Hard adjacency too negative.
3. **SKIP STREAKS ENTIRELY** — no streak counter, no streak-loss notification, no broken-streak UI. Largest year-2 retention risk in the category for this cohort. "Showing up" stays as LANGUAGE in copy ("3 days of showing up this week") but never as a metric.
4. **"Becoming" reduce ~60% across surfaces** — brand-issued not cohort-issued. Treat like saffron not salt. Strategic uses: paywall hero + JeniMethod arc framing. Replace elsewhere with "showing up" or "your [X] era" or concrete language.
5. **Pattern C welcome screen** — 4-sec product-act video loop (hand snapping overnight oats, cocoa-pill calorie chip animating in). NO creator photos. NO body imagery. NO before/after.
6. **Force First Action sheet** post-paywall — "want to start with food or movement?" lands between paywall and Home, presents 2 equal options (food photo OR 4-min starter plank). Soft "not right now" skip preserved.
7. **Remove "skip walkthrough" CTA** on welcome screen — conversion suicide per category leaders.
8. **3 onboarding questions ADD + 3 CUT + 1 REORDER** (details in §Onboarding below).
9. **Continuous progress bar** across all onboarding screens (not per-act dots).
10. **Cuisine question moves to Act 3** (after body + goal) — not Act 2 as v3 proposed. Reason per designer A: user needs to feel measured before investing in 8 food questions.
11. **Honesty Doctrine extends to copy** — "around 480, give or take a slice" uncertainty IN copy not %, "(this takes about 3 sec)" disclosure on processing screen, "we delete the photo after" baked into AI consent modal.

---

## Per-screen locked specs

### Screen 1 — Welcome (Pattern C)

Asset: 4-second silent video loop (NOT a person, NOT a body). Real hand photographing a bowl of overnight oats; cocoa-pill calorie chip animates in with flower3D sticker accent.

Copy locked:
- Headline: **weight loss that *holds*** (italic Fraunces on "holds")
- Subhead: *"calories, plank, steps — one calm program for the long version."* (NOT "the long version of you" — designer B cut "of you")
- Primary CTA: **i'm in** (cocoa pill) — replaces "start becoming." TikTok-comment-section register.
- Social proof line: omitted at launch (data provenance rule — only ships when true)
- "Skip walkthrough" CTA: REMOVED

Production cost: ~1-2 days designer + animator. Single asset reused across CPP + App Store screenshot frame 1.

### Onboarding redesigned act structure (~47 screens, down from 57)

| Act | Theme | Screens | Food signal? |
|---|---|---|---|
| **Act 1: hook + competitor-killer** | Welcome, why-you're-here, identity anchor, prior-apps questions | ~8 | YES via welcome copy |
| **Act 2: body data** | Weight, goal, height, body type | ~6 | — |
| **Act 3: food-first reveal** | Cuisine, eating cadence, dining frequency, photo comfort, food relationship | ~5 trimmed | YES (the wedge questions) |
| **Act 4: cohort credibility** | Sleep, stress, hormonal, GLP-1, prior attempts, prior win | ~10 | LTV-strong |
| **Act 5: plan reveal + paywall** | Reveal, projection, paywall (food-variant hero) | ~8 | YES (food-led hero) |
| Plus dividers/affirmations/reveal-sequence | | ~10 | |

#### Questions ADDED (3)

- **Q300** (Act 1 close): *"have you tried other apps for this?"* Multi-select chips: MyFitnessPal · Cal AI · Noom · LoseIt · Lifesum · Cronometer · MacroFactor · WW · none yet · other. New AppStorage: `priorAppsUsed`.

- **Q301** (Act 1 close, conditional on Q300 ≠ "none yet"): *"what didn't work about it?"* Multi-select chips: made me feel guilty · too much typing · inaccurate calories · too many notifications · paywall too aggressive · couldn't keep up · forgot to log · expensive · **the streak guilt** (cohort-issued language) · just lost interest. Show ALL chips, NO "show more" hide. New AppStorage: `priorAppsFailureModes`.

- **Q303** (Act 3): *"how often do you eat out?"* Single-select, **4 options** (designer A refinement from my original 5): often · weekly · occasionally · rarely. New AppStorage: `diningFrequency`.

- **Q302** (Act 3): cuisine multi-select [moved from v3 D17 location; locked at Act 3 not Act 2]. Add cohort-issued chips per designer B: **"vibes-based"** and **"forgot to eat lunch again"** alongside cuisine options.

- **Q304** (Act 3): *"how do you usually capture food memories?"* Single-select: I snap everything · sometimes · rarely · I don't take food photos. New AppStorage: `photoComfort`.

#### Questions CUT (3)

- **Q260** (tier-ladder identity projection) — Noom-style projection theater before user has data. Designer A + B both flagged.
- **Q3 + Q11** (legacy relatability) — replaced by Q153 multi-select but never deleted. Dead code.

#### Question REWRITTEN (1)

- **Q145** (pre-paywall celebration screen) — DON'T DROP per designer A's peak-end rule pushback. Rewrite as data-grounded plan reveal: *"your plan is ready"* with echoed user inputs (cuisine, prior-app failure modes, GLP-1 status if applicable) reflected as plan personalization. Critical: must reflect Q301 failure modes back as positives ("your plan: no guilt, less typing, fewer notifications").

#### Continuous progress bar

Thin top bar fills monotonically across all ~47 screens. Replaces per-act dots. Doesn't show "X of N" number — just fills. Per Noom + Cal AI pattern.

### Force First Action sheet (post-paywall, pre-Home)

```
welcome 🌸
let's *start*.

want to start with food or movement?

[ 📷 log what you're eating ]
[ 💪 do a 4-min starter set ]

not right now →
```

- Two equal-weight CTA pills
- "Pick one" copy KEPT (designer B's softer "want to start with food or movement?" REJECTED by founder — keeps assertiveness)
- "Not right now" soft skip — routes to Home with empty state + first-log nudge active for 7 days

### Calorie scan flow (7 sub-screens, locked)

Specs locked (no changes from previous mock):
1. **Camera screen** — scrapbook frame around viewfinder (NOT black camera UI, +2 days dev). Cocoa pill shutter with "tap to scan" label. Pre-eat mode toggle `[just ate | deciding]` visible at top. 3-mode chip row at bottom (photo / quick-add / i'm out).
2. **Processing screen** — 3 streaming copy lines + "(this takes about 3 sec)" honest disclosure. Bloom sticker pulse, NO spinner/progress-bar.
3. **Result card (just ate)** — italic Fraunces on food name, **"around 480, give or take a slice"** uncertainty IN copy not %, macros default-visible (P22 C50 F18 — designer B's tap-to-reveal REJECTED by founder), Jeni interpretation line, "looks good — log it" primary + "fix something" secondary.
4. **Result card (deciding/pre-eat)** — "you have room. easy yes." permission frame. **"have it / save for later"** (NOT "skip this one" — designer B polish accepted). Macros demoted below Jeni line.
5. **Quick-add picker** — 6 tiles (matcha latte / oat milk latte / iced coffee / brown sugar boba / protein shake / smoothie). 3-tap edit sheet (size/milk/sweetness).
6. **"I'm out tonight" placeholder** — single tap logs ~700 default. Optional cuisine chip refines (mexican ~600, italian ~850, asian ~750). "or just log it →" escape for ultra-lazy path.
7. **Correction sheet** — portion slider 3 stops (S/M/L) with haptic, food search, "describe instead" re-runs LLM.

### Home screen (Slot 4 redesign locked)

- Slot 0: JenisNoteCard with day-count reference ("3 days in — that's a rhythm forming") — KEEPS, designer A + B both ratified
- Slot 1: JeniMethod card hero — UNCHANGED
- Slot 2: today's workout card
- Slot 3: WeekProgressStrip with **"Day N"** badge (NO "/75" — locked)
- Slot 4: TodayHealthStrip — food card hero **with BAR not ring** (locked change), cocoa color, weekly avg caption, "tracking your week" copy. Steps + breath as lateral pills below (smaller).
- Slot 5: shrunken utility row

Existing-user soft tile: dismissable 7-day banner above food card on flag-flip day. No popup, no modal.

Catch-up tiles for missed JeniMethod days: smaller than today's hero, max 3 visible, never resets day counter.

### Becoming screen (Story Card stack — LOCKED 2026-06-04)

4-card vertical stack replaces bento grid:
1. **"your week"** (trend hero) — EMA curve + soft directional copy. **Empty state copy locked:** *"give it a week or two ↓ the curve takes time"* (MacroFactor radical-honesty pattern; D48). Builds trust early; reduces "where's my data?" churn.
2. **"what you ate"** — 7-day bars (cocoa, never red) + rolling avg overlay. Captions: "tracking your goal pace" / "a higher week. tomorrow resets ♥" / "your body needs more — let's aim higher tomorrow" depending on data.
3. **"how you moved"** — steps + sessions + breath count as raw units. **NEVER kcal** (Honesty Doctrine hard rule). **Copy locked: *"your body's been here"*** (D47). Anti-labor framing; doesn't moralize movement; doesn't overuse "showing up."
4. **"what's changing"** — **combined dense card (D46)**. Absorbs all four signals: NSV + barrier-resolved + mastery curve + JeniMethod milestones. **Catch-up tiles for missed lessons live INSIDE this card (D49)** — keeps Becoming stack tidy at 4 cards; missed lessons are part of the "what's changing" story narratively.

**Tab name: "becoming" KEPT (D50)** — founder override of designer B's reduce-tab-name suggestion. Brand continuity from 1.0.6 wins. "Becoming" reduction (D36) still applies to greeting copy, notification copy, paywall body copy — just NOT the tab label.

---

## Vocabulary lock-ins (cohort-fluency layer)

| Pattern | Lock |
|---|---|
| "becoming" frequency | Reduce ~60%. Strategic uses ONLY: paywall hero + JeniMethod 75-day-arc framing. Replace elsewhere. |
| "Day N of 75" | **NEVER displayed.** "Day N" alone. Arc length internal only. |
| Streak counter | **NEVER displayed.** No metric, no notification, no UI element. "Showing up" stays as language in greeting copy ("3 days of showing up"), not as counter. |
| "luteal-phase" | Replaced by **"second-half-of-cycle"** (creator-safe phrasing per @hormone.health.dietitian / @thecycledoctor TikTok register) |
| "the long version of you" | Cut "of you" → **"the long version"** |
| "have it / skip this one" | Cut "skip this one" → **"have it / save for later"** |
| Cycle-specific voice | **Gated behind logged-cycle data.** If user has logged a cycle, Jeni references it. If not, Jeni uses non-cycle copy. Single deepest moat (Flo × food intersection). |
| "bloat truth" lesson title | Renamed to **"why your body looks different at 4pm than 9am"** — moderation safety + cohort fluency. |
| AI disclosure copy | Compressed: *"we send your photo to read the plate. openai + anthropic see it. they don't train on it. photo's gone after."* "Photo's gone after" is the most important sentence; previously buried. |

---

## v4 conflicts resolved by v5

| v4 said | v5 supersedes |
|---|---|
| "No food prompt immediately post-paywall — food card visible but dimmed" | **REVERSED.** Force First Action sheet between paywall and Home presents food option as one of two equal choices. |
| Tab name kept as "becoming" | **OPEN.** Designer B flagged for change; founder not yet confirmed. |
| "Showing up streak" notification on milestone | **REMOVED.** Streak metric gone; milestone notifications still fire but reference JeniMethod day milestones (Day 7/25/50/75), not streak. |
| "Day N of 75" in JeniMethod card | **DISPLAY ONLY "Day N".** Internal 75-day arc unchanged. |
| Food card 3-ring concentric tile | Already rejected in v3. v5 also rejects single-ring food tile in favor of BAR. |

---

## New founder decisions D33–D45

| # | Decision | Lock |
|---|---|---|
| D33 | Ring → Bar on food card across Home + result card + Becoming | ✓ LOCKED |
| D34 | Drop "/75" denominator in all UI displays | ✓ LOCKED |
| D35 | Skip streak metric entirely (no counter, no UI, no notification) | ✓ LOCKED |
| D36 | Reduce "becoming" surface count ~60% (strategic uses only) | ✓ LOCKED principle, copy pass needed across surfaces |
| D37 | Pattern C welcome (video loop, no creator/body imagery) | ✓ LOCKED |
| D38 | Force First Action sheet post-paywall with 2 equal options + soft skip | ✓ LOCKED |
| D39 | Onboarding act reorder (food Act 3 not Act 2) | ✓ LOCKED |
| D40 | Add Q300/Q301/Q303/Q304 to onboarding; cut Q260/Q3/Q11; rewrite Q145 | ✓ LOCKED |
| D41 | Continuous progress bar across all onboarding screens | ✓ LOCKED |
| D42 | Honesty Doctrine extends to copy (uncertainty IN copy, "photo's gone after", "(takes about 3 sec)") | ✓ LOCKED |
| D43 | Macros default-visible on result card (designer B's tap-to-reveal REJECTED) | ✓ LOCKED (override) |
| D44 | Single hand in welcome video (designer B's racially-ambiguous/rotating REJECTED) | ✓ LOCKED (override) |
| D45 | Force First Action copy stays "pick one to do right now" (designer B's softer version REJECTED) | ✓ LOCKED (override) |
| D46 | "What's changing" card combines all four signals (NSV + barrier + mastery + milestones) | ✓ LOCKED |
| D47 | "How you moved" copy: "your body's been here" | ✓ LOCKED |
| D48 | Trend hero empty state copy: "give it a week or two ↓ the curve takes time" | ✓ LOCKED |
| D49 | Catch-up tiles live INSIDE "what's changing" card (not dedicated card) | ✓ LOCKED |
| D50 | Tab name "becoming" KEPT (founder override of designer B) | ✓ LOCKED (override) |
| D51 | Force First Action plank option = existing JeniFit plank session (no custom starter content; wires to existing workout flow) | ✓ LOCKED |
| D52 | Cohort chip language additions approved: "the streak guilt" (Q301), "vibes-based" + "forgot to eat lunch again" (Q302) | ✓ LOCKED |
| D53 | Welcome video generated via AI tools (Runway / Pika / Veo3) — see quality bar below | ✓ LOCKED with safety gate |

---

## Sprint breakdown impacts (`food_rail_sprint_v1_0_7.md`)

These tickets need updating to reflect v5 decisions:

| Sprint ticket | v5 impact |
|---|---|
| W2-T2 PhotoCaptureView | Add scrapbook frame + pre-eat toggle (was implied; now hard-spec'd) |
| W3-T1 6 atomic Views | **Add "WeeklyAvgBar" atom** to replace ring on food card. **Remove streak-counter atom from scope.** |
| W3-T6 FoodLog SwiftData model | Schema unchanged but no streak-count field needed |
| W4-T1 TodayHealthStrip on Home | **Bar not ring** for food card. Day badge no "/75" suffix. |
| W4-T2 Force First Action sheet (NEW TICKET) | Need to add: sheet between paywall and Home with 2-option food/plank + skip. Estimated 1.5 days. |
| W4-T3 Becoming Story Card | Trend card empty state honesty copy. "How you moved" never shows kcal. "What's changing" absorbs NSV + barrier + mastery curve + JeniMethod milestones. |
| W4-T4 Food Settings | No streak settings needed (skipped). Cycle voice gate option added. |
| W5-T1 JeniMethod content | Day 28 lesson renamed "why your body looks different at 4pm than 9am" (was "bloat truth") |
| W5-T3 PostHog instrumentation | **REMOVE `food_streak_milestone`** event. Keep `jenimethod_milestone_d7/25/50/75`. |
| W5-T5 Notification cadence | **Remove streak-loss notification entirely.** Day-3 first-log nudge + opt-in evening check-in only. |
| W5-T6 Onboarding case 165 | **Expand to add Q300/Q301/Q303/Q304** (and Q302 cuisine moves to Act 3). Estimated +1 day. |

Net sprint impact: ~+2-3 days total. v1.0.7 timeline 5-week estimate holds; the new Force First Action sheet ticket compresses other Week-4 slack.

---

## D53 quality bar — AI-generated welcome video

**Tension:** brand voice locks ban "AI" in user-facing copy. We're choosing AI tools for the welcome video asset. The cohort has been told repeatedly that the app uses "vision models" not "AI" — if the video reads as AI-generated slop, that's a brand-trust failure.

**Hard quality gate before shipping:**
- Asset must be indistinguishable from professional motion design to a non-technical cohort viewer
- Test against 3–5 cohort users (informal — friends, sister, TikTok DMs) before locking. If any single viewer says "this looks AI-generated," fall back to Pattern B for v1.0.7.
- Production approach: Runway Gen-3 or Veo3 with curated input frames (real bowl, real hand, real iPhone). Avoid pure text-to-video; use image-to-video with controlled inputs.
- Audio: NONE (silent loop). Removes one major AI-tell vector.
- Length: 4 seconds. Shorter = less surface for AI artifacts.
- Cocoa-pill calorie chip overlay = SwiftUI/Lottie native animation, NOT AI-generated. The animated chip is the "humanized" moment that disambiguates.

**Fallback if quality gate fails:** Pattern B (type-only with brand mark + headline + CTA) ships in v1.0.7. Pattern C revisits in v1.0.8 with budget for a freelance motion designer.

**Budget:** ~$50-200 in API credits + ~4-6 hours of curation. Cheap enough to fail-and-fall-back without project impact.

---

## Open items (founder gate before v1.0.7 ticketing starts)

**ALL CLOSED 2026-06-04.** Remaining open items:

1. **Confirm copy pass owner** for "becoming" reduction across non-tab surfaces (greeting / notification / paywall body / streak language). Founder or curator. (Light operational confirmation.)
2. **Held release dependency** unchanged in v5 — 1.0.6 build 11 must be Apple-approved + released ✓ DONE 2026-06-03.

Sprint Week 1 can start.

---

## Related research sources added in v5

- UX designer A (subscription funnel): conversion mechanics, paywall placement, peak-end rule
- UX designer B (Gen-Z cohort cultural specialist): cultural fluency, voice landing, anti-shame sensitivity, identity authenticity, app-rotation texture
- First-screen pattern research 2026: TikTok ad policy + #SkinnyTok ban + Apple body-classification + category-leader convergence on no-body-imagery screen 1
- r/loseit, r/xxfitness, r/EatingDisorders thread analysis on streak-guilt churn pattern
- TikTok creator handles referenced: @hormone.health.dietitian, @thecycledoctor, @abbeyskitchen, @sampreviteRD, @colleenchristensennutrition, @karaglucksman, @thebirdspapaya

---

*End delta v5. v5 wins over v4 wins over v3 wins over v2 wins over v1 where they conflict. **All design decisions locked 2026-06-04** (D33–D53). Sprint Week 1 can begin.*

---

# Delta v6 — Camera mode collapse 2026-06-05 (in-build founder feedback)

## What changed

Founder hit the live build, tried the camera, and surfaced a clean
mental-model break:

> "just ate / deciding tag is quite confusing when i actually try it.
> because after you eat food, there is no food left to take a photo."

The pre-eat / post-eat distinction *as expressed via an explicit mode
toggle* makes no sense in the camera moment. By the time the user has
a phone aimed at food, the food is in front of them — that's the only
state the camera can serve. "just ate" implies food is gone, which
breaks the prerequisite for taking a photo at all.

## D54 — collapse PhotoMode to a single unified scan

**LOCKED.** Remove the `[just ate | deciding]` mode pill from
`PhotoCaptureView`. Delete the `PhotoMode` enum. `FoodCapture.photo`
no longer carries a mode parameter. Result card has ONE consistent
layout for all scans.

The pre-eat *intent* (D13's original wedge) is preserved — but moved
from a structural mode toggle to **Jeni copy** on the unified card
and a clearer **secondary CTA**:

- **Primary CTA:** `log it` (always — adds to today's plate)
- **Secondary CTA:** `actually skip →` (back out, never logged)
- **Jeni copy line:** carries the warmth/permission regardless of
  pre-eat or mid-eat context. E.g. "this fits — easy yes if you
  want it. ♥" works in both moments without the user declaring
  intent upfront.

The user makes the "am I going to eat this?" decision **after** seeing
the result, not before taking the photo. The choice surfaces as a CTA
choice, not as a pre-photo mode declaration.

## Why this doesn't kill the pre-eat wedge

The pre-eat / permission framing remains JeniFit's anti-Cal-AI brand
moat per `feedback_food_ux_antishame` + `project_food_rail_v2_locked`.
What changes is *how that wedge is expressed*:

| Layer | Old expression | New expression |
|---|---|---|
| Mode toggle | Explicit `[just ate / deciding]` pill | **Removed.** |
| CTA copy | Mode-branched (`have it` vs `log it`) | Single unified `log it` + `actually skip →` |
| Jeni copy | Mode-branched permission vs verdict | Single copy that lands as permission OR verdict depending on context the user brings |
| Today's Plate timeline | Future surface for retro logging | Same — unchanged |
| "I'm out tonight" restaurant mode (D14) | Separate entry point | Unchanged — still ships as its own tap-once flow |

The differentiating frame moves from UI chrome to copy. Less friction,
same brand position.

## Cascading deletions

Approximate file delta in `Packages/PlankFood`:

- `Capture/FoodCapture.swift` — delete `PhotoMode` enum + simplify
  `.photo(Data, mode:)` to `.photo(Data)`
- `Capture/PhotoCaptureView.swift` — delete `photoMode` state, the
  `preEatPill()` helper, the mode-pill VStack (~25 lines)
- `Capture/CaptureFlowView.swift` — delete `photoMode` state pass-through
- `Capture/FoodCaptureDispatcher.swift` — drop the `mode` param from
  `.photo` case + from `NotImplementedContext.photo`
- `Pipeline/FoodVisionService.swift` — drop `mode` param from `scan()`
  (no behavioral effect — mode never actually changed the LLM prompt)
- `Pipeline/FoodLogPersister.swift` — drop the optional `photoMode`
  param from the persistence call
- `Result/ResultCard.swift` — delete `mode` param; result card has
  one path
- `Result/PlateLayouts/SingleDishCard.swift` + `MixedPlateCard.swift`:
  - Delete `mode` param
  - Delete the `if mode == .deciding` branches
  - Replace mode-branched CTA copy with unified `log it` + `actually skip →`
  - Replace mode-branched `decidingCopy` / `synthesizeJeniLine` with a
    single Jeni line that lands in both contexts
- All preview helpers (`.previewMixed()`, `.preview()`, etc.) — drop
  `mode:` argument

## Analytics impact

The `photo_mode` event property gets dropped from `food_capture_scan`
and `food_log_created`. PostHog dashboards filtering on `photo_mode`
will return all-events (degrades gracefully). The retrospective
question "what % of scans were pre-eat vs post-eat?" is no longer
answerable — and per this decision, no longer relevant.

## Sprint impact

Net: ~30 minutes of refactor work + builds. Affects 8 files in
`PlankFood`, no app-side surface changes beyond removing the pill from
the camera screen. No schema impact. Done in the W3-T4 result-card
ticket scope.

---

*End delta v6. v6 supersedes v2's D13 mode-toggle expression where
they conflict. The pre-eat WEDGE survives; the pre-eat TOGGLE doesn't.
All other design decisions stand.*

---

# Delta v7 — Diet-first strategic pivot 2026-06-05 (evening)

## What changed

Founder questioned whether JeniFit is "a workout app with food added"
or "a weight-loss program with workout as additional." Seven expert
research briefs commissioned across orthogonal lenses: WL domain (#1),
UX/UI for Gen-Z women (#2), conversion engineering (#3), brand +
cultural fluency (#4), behavioral science + retention (#5),
monetization + LTV (#6), tactical viral iOS engineering (#7).

**All 7 briefs saved at `docs/pivot_research_*.md`. Load-bearing
reading — single source of truth for the pivot direction.**

## The consensus

**JeniFit pivots from "workout app + food rail" to "weight-loss
program with food as the daily-decision hero."** Scope = Option B
(medium pivot, ~18-25 dev-days on top of remaining food rail sprint).

### Why (all 7 briefs converged)
- **Behavioral science:** diet > exercise for WL is settled
  (Pontzer constrained energy, CALERIE, Wing & Phelan)
- **Cohort signal:** Cal AI 8.3M downloads + $34-50M ARR in 18mo;
  GLP-1 normalization (30% of Gen-Z women intend); SWEAT down YoY
- **Category retention math:** diet 45% Day-30 vs fitness 10-12%
- **Your own launch data:** lesson 75% vs workout 23% completion;
  food rail signal 92% conversion-correlation in pre-rail tappers
- **Competitive moat:** workout-first puts JeniFit against SWEAT/
  Future/Apple Fitness+ ($B incumbents). Diet-first has three
  white-space wedges (pre-eat, restaurant social, trend-as-hero)
  no competitor will take.

### What stays unchanged
- Brand chrome (italic-Fraunces, scrapbook, cocoa, lowercase,
  coquette stickers, hearts as terminal punctuation, "becoming"
  motif)
- Pricing structure (Annual $47.99 / Quarterly $24.99 / Weekly $5.99)
- Grandfather ladder (with one revision — D60 below)
- Workout / plank / breath as **Tier 2** features (demoted, not killed)
- "JeniFit" app name through v1.x

---

## New founder decisions D54–D72

D54 already locked in delta v6 (PhotoMode toggle collapse). D55+ new.

| # | Question | Lock |
|---|---|---|
| **D55** | Pivot scope — soft / medium / hard? | **MEDIUM (Option B).** ~18-25 dev-days. Keep brand chrome + name; restructure home + onboarding + becoming + JeniMethod curriculum + paywall + App Store. |
| **D56** | Home hero — JeniMethod stays or food becomes hero? | **FOOD HERO, JeniMethod paired at slot 3 with FULL scrapbook chrome (not flat-demoted).** Ship with instrumented rollback — if lesson engagement drops >15% within 14 days, revert. 6 of 7 expert briefs converged on this. |
| **D57** | Tab bar structure? | **2 tabs (Present + Becoming) + central cocoa camera FAB.** Persistent floating FAB above tab bar, Cal AI pattern adapted to JeniFit chrome. Recommended by Briefs #2 + #4. |
| **D58** | App name — keep JeniFit through v1.x or rename to "Jeni" at v1.1? | **KEEP "JeniFit" through v1.x. Rename to "Jeni" at v2.0** when food + scan + agent earn it. Subtitle for ASO: "JeniFit: Food + Body" or similar. |
| **D59** | Workout/plank/breath demotion shape? | **Tier 2 — present but demoted.** Per Brief #2 D recommendation: smaller cards, no scrapbook chrome on workout card (demoted visual weight). Plank ritual stays in JeniMethod curriculum. |
| **D60** | Grandfather ladder v3.0 price? | **REVISED: v3.0 → $119.99/yr** (was $99.99). Feature stack by v3 (food rail + corrections-as-moat + Jeni AI agent + body scan + GLP-1 module + Apple Watch glance) justifies premium tier per Brief #6. |
| **D61** | GLP-1 monetization shape? | **GLP-1 module inside Annual** at v1.5 ($54.99 ladder step). NO separate GLP-1 SKU. Module = GLP-1 onboarding fork + GLP-1-aware Jeni voice notes + digestive-symptom log + injection reminder. Per Brief #6 — $15-25/yr ARPU lift opportunity. |
| **D62** | Day-0 first action? | **Forced first-snap with manual entry fallback.** Post-paywall → "welcome ritual" sheet (<30s) → "snap your first meal" CTA → result card → home. Never zero-artifact Day-0. Manual fallback if camera fails. Per Briefs #3 + #5 + #7. 71% Day-1 retention pattern (Cal AI). |
| **D63** | Day-3 conversion moment design? | **Day-2 evening hook + Day-3 morning visual proof.** Day-3 morning: 2-day EMA arrow + plate timeline strip + Jeni's interpretation pulled from real data. CTA opens paywall (not settings); button: `continue your becoming`. Per Briefs #3 + #5 + #7. |
| **D64** | Evening Plate Review at 8:30pm? | **YES, SHIP IN v1.0.7.** Single highest-leverage retention move (1.6-1.9× Day-30 multiplier). 8:30pm local push *"today's plate ♥"* → in-app card with plate thumbnails + Jeni's interpretive line + soft "tomorrow looks like…" preview. Per Brief #5. |
| **D65** | Week-1 push cadence? | **6/wk Week 1, 4/wk Week 2-3, 3/wk Week 4+** (revising existing `project_trial_week_notifications.md` cap upward for Week 1 only). Diet apps tolerate higher cadence due to task-relevance per meal (RevenueCat 2026: 41% lower unsubscribe at 6/wk for diet). Per Brief #3. |
| **D66** | Onboarding screen 1 — change to food-led? | **NO. Screen 1 stays brand-aligned per `feedback_first_screen_strategy`** (no body imagery, no creator). **Screen 2 becomes the food-relationship question** ("what's the hardest part of eating right now?"). |
| **D67** | Onboarding commitment screen at ~screen 38? | **YES, ADD.** "Soft-commitment" beat at screen 38: *"we're building your plan — agree to give it 3 days?"* with single Continue CTA before heavy investment battery. 1.7× trial-to-paid lift per Cal AI pattern (Brief #3). |
| **D68** | Plan reveal hero order? | **Calorie target first (hero card), weight curve second, workout third.** Animated reveal sequence: calorie ring (1.5s) → protein floor pill (0.5s) → weight curve overlay (2s) → milestone hearts (1s). 5s total. Per Briefs #2 + #3. |
| **D69** | Becoming tab restructure? | **Reorder modules around food-first.** Module priority: (1) Today's Plate Timeline expanded, (2) Weight trend × intake dual-axis chart, (3) Jeni's this-week note, (4) Movement summary rolled into one tile, (5) NSV wins expanded with food NSVs, (6) Forecast + milestones. Per Brief #1. |
| **D70** | JeniMethod curriculum reframe? | **YES.** Re-spine around food relationship + body literacy + permission. Week 1 = food noise + permission (Days 1-7). Week 2 = body cues + cycles (Days 8-14). Week 3 = restaurant social + GLP-1 (Days 15-21). Week 4 = movement re-enters as maintenance (Days 22-30). Day 30-60 = habit maintenance. Day 60-90 = identity transition. Per Briefs #1 + #5. |
| **D71** | App Store screenshot order? | **(1) Pre-eat permission card "matcha latte + you have *room* ♥", (2) plate timeline, (3) Jeni voice interpretation, (4) Becoming dual-axis chart, (5) restaurant social card, (6) JeniMethod lesson, (7) workout demoted.** Screenshots 1, 3, 5 = brand-cultural moat; 2, 4 = category claim. Per Briefs #2 + #4 + #7. |
| **D72** | US-specific paywall variant via remote config? | **YES, TEST IN v1.0.7.** Headline variant: "snap your plate. see if it fits. before you eat." US-only via PostHog flag. Expected lift: +30-50% US trial conversion (Adapty 2026 camera-promise headlines outperform brand-promise 1.3-1.5× in 18-29F). Per Briefs #3 + #6. |

---

## Sprint scope changes (`food_rail_sprint_v1_0_7.md`)

The v1.0.7 sprint was scoped pre-pivot. Adjustments:

### W3-T2 plate layout views — EXTENDED
Result card must be **letter-form prose, not tabular columns** (Brief #4 brand-cultural moat). Add: running-prose layout for SingleDishCard + MixedPlateCard. Brief #4 spatial mockup applies.

### W3-T3 QuickAddView — UNCHANGED
Beverage rail per existing scope.

### W3-T5 FoodCorrectionSheet — UNCHANGED

### W4-T1 Home Slot 4 — REPLACED with full Home restructure
Was: Slot 4 swap for `todayHealthStrip` when food rail enabled. Now: full Home restructure per D56 (food hero at slot 2, JeniMethod at slot 3 with chrome retained, workout demoted at slot 4, breath/steps strip at slot 5). Estimated +3 dev-days.

### NEW W4-T6 — Camera FAB + tab bar
Per D57. Floating cocoa camera FAB above 2-tab tab bar. Persistent across Present + Becoming tabs. Tap → CaptureFlowView. Estimated 1.5 dev-days.

### NEW W4-T7 — Evening Plate Review
Per D64. 8:30pm local push + in-app card surface on Home. Estimated 1 dev-day.

### NEW W4-T8 — Day-0 first-snap flow
Per D62. Post-paywall welcome ritual sheet + auto-route to camera + manual entry fallback. Estimated 1.5 dev-days.

### NEW W4-T9 — Day-3 conversion moment
Per D63. Day-2 evening hook + Day-3 morning visual proof modal. Estimated 1.5 dev-days.

### W4-T3 Becoming restructure — UNCHANGED but scope reaffirmed per D69
The biggest single ticket. Module reorder per D69.

### W4-T5 Paywall food-variant hero — EXTENDED
Add US-specific headline variant per D72. Remote config gated via PostHog flag.

### NEW W5-T8 — Push cadence config
Per D65. 6/wk Week 1, 4/wk Week 2-3, 3/wk Week 4+. Update `TrialWeekNotificationService`.

### NEW W5-T9 — Onboarding screen 38 commitment
Per D67. Insert "agree to give it 3 days?" screen with confidence slider. Update `OnboardingState`.

### NEW W5-T10 — JeniMethod curriculum re-spine
Per D70. Day 1-30 content rewrite around food-first spine. Estimated 5-7 dev-days (content + code).

**Net sprint impact:** +12-15 dev-days on top of existing v1.0.7 scope. Original 5-week estimate becomes 7-8 weeks.

---

## Implementation order (recommended)

Phase A (in-flight, this week): finish food rail (vision + USDA join + result card + Home food card)

Phase B (Week 1 of pivot): Home restructure per D56 + Camera FAB per D57 + plate timeline + Evening Plate Review per D64

Phase C (Week 2-3): Onboarding screen-2 food-relationship + plan-reveal reorder + screen-38 commitment + Day-0 first-snap flow + Day-3 conversion moment

Phase D (Week 3-4): Becoming restructure per D69 + paywall food-variant headline US-only

Phase E (Week 4-6): JeniMethod curriculum re-spine + push cadence + App Store screenshot reshoot

Phase F (Week 7-8): instrumentation + QA + soft launch

---

## Open items (founder-handled, not Claude-actionable)

1. **App Store screenshot reshoot.** Brief #2 + #4 + #7 all recommend full reshoot. Concept and brief approved per D71; execution = founder + designer.
2. **App Preview video.** 15s silent loop per Brief #7 §6. Concept = camera tap → matcha latte snap → calorie result with cocoa pill → Jeni voice note. Execution = founder.
3. **TikTok creator outreach pivot.** Per Brief #6 §7. Acquire GLP-1 honest-experience creators (~50-200k followers). Founder responsibility.
4. **Apple Search Ads keyword test.** Per Brief #6 §7. New keyword set: "food tracker for women" / "calorie counter for women" priority. Founder responsibility.

---

*End delta v7. v7 supersedes the workout-first positioning baked into
v1-v6 where they conflict. The diet-first POSITIONING is locked.
v1.0.7 food rail ships as the Tier-1 hero, not Tier-3 plug-in slot.
Sprint extended 7-8 weeks. App Store launch with new positioning
matches v1.0.7 ship.*

---

# Delta v8 — Cal AI onboarding study + restructure 2026-06-06

## What changed

Founder commissioned 4 additional expert briefs studying Cal AI's full
43-screen onboarding flow (saved at `/Users/bko/plankAI/screenshots/calai*.PNG`):

- `docs/calai_research_ux_designer.md` — visual + interaction design
- `docs/calai_research_wl_expert.md` — question content + program psychology
- `docs/calai_research_monetization.md` — paywall + conversion mechanics
- `docs/calai_research_culture.md` — copy register + trust signals

Cal AI is doing $34-50M ARR with a 30-screen flow; JeniFit's v2FlowOrder
is 58 screens. The compounding gap is COMMITMENT mechanics + reveal
architecture + paywall sequencing. JeniFit can keep its richer data
layer (sleep / stress / GLP-1 / hormonal) while adopting Cal AI's
commitment-first architecture.

## 15 new locked decisions D73-D87

All cross-validated by 3+ of the 4 Cal AI expert briefs. JeniFit's
voice locks (italic-Fraunces, lowercase, hearts, coquette stickers,
"becoming" motif, Honesty Doctrine, anti-shame UX, no-DB-changes) are
preserved across all.

| # | Decision | Cal AI ref | Endorsers |
|---|---|---|---|
| **D73** | **Pace selector** Q with weeks-to-goal feedback. Coquette sticker variants (snail/bunny/cheetah, NOT animal cartoons). Italic-Fraunces caption per pace position. New case 167. | calai8/20/17/19 | UX, WL, Mon, Culture |
| **D74** | **Multi-proof plan reveal** — replace single weight curve with 5-tile grid: calorie target + protein floor + plank ritual + becoming arc + date target. Keep "becoming, plotted" headline (NOT "Congratulations!"). | calai25/24 | UX, WL, Mon |
| **D75** | **3-stage loader** at 67%/91%/97% with milestone checks ("eating story ♥ / cuisine match / calorie window / movement floor / *becoming* arc"). Buell & Norton labor illusion. Replace single-loader at case 180. | calai34/31/38 | UX, Mon |
| **D76** | **Notification pre-prime** screen before iOS dialog. Voice: "want a nudge from jeni? one quiet one a day. nothing nagging." Expected +34% allow rate. New case 169. | calai23 | UX, Mon, Culture |
| **D77** | **Apple Health permission BEFORE paywall**, not after. Voice: "let's pull your steps + sleep ♥". Move PairedPermissionsAsk's HealthKit ask up to OnboardingRevealView. | calai22 | UX, Mon |
| **D78** | **Two-step paywall split** — Step 1: single "continue ♥" CTA + trial-end reminder commitment ("we'll send you one note before anything renews"). Step 2: tier selection (Annual / Quarterly / Weekly) + 3-day timeline. | calai43 → calai27 | Mon |
| **D79** | **Specific date** in plan reveal — "by August 14 ♥" (computed from goal weight / pace). Commitment anchor. | calai36 | UX, Culture |
| **D80** | **"No payment due now"** copy verbatim on paywall + trial-confirm. Lowest-effort highest-trust signal. | calai43 | Mon, Culture |
| **D81** | **"You, on JeniFit vs starting over"** comparison chart. NOT "JeniFit vs Cal AI" (legal risk). Soft-positions anti-diet-diet. | calai4 | WL, Culture |
| **D82** | **Sign-in BEFORE paywall** (post-plan-reveal, pre-trial-paywall). Sunk-cost lock. Uses existing anonymous-first Supabase auth — UPGRADES the anonymous account, doesn't create new. | calai37 | Mon |
| **D83** | **Cut 12 redundant cases** from v2FlowOrder: section dividers 201/202/204 (keep 200/203/205), educational 232 (consolidate via Jeni confirmation lines on adjacent Qs), 111 (overlaps 140), 135 (one body-shape Q is enough), 235 (merge to 163), 237 (overlaps 159), 240 (brand-promises reads 2018 startup), 215 (rating prompt moved to post-Day-1), 26 (camera-setup unnecessary), 22 (personal stat too late). | n/a | WL |
| **D84** | **Kill "$0.92/wk" line** on annual paywall card. Apple pulled Cal AI for this April 2026; JeniFit currently ships it. Replace with "save vs quarterly" framing. | calai43 | Mon |
| **D85** | **70pt option pill grammar** standardized across all Q&A screens (cocoa selected + accentSubtle unselected + leading 32pt circular glyph). Route all "Continue" through ctaBtn at line 7923. | universal | UX |
| **D86** | **Post-vulnerability reciprocity beat** — "thank you for being honest ♥" after GLP-1/hormonal/prior-attempts Qs. Cap at 3 softness beats per onboarding total. | calai22 | Culture |
| **D87** | **Sunk-cost activation Q** early — "tried *everything* already?" 3 options (first try / a few times / many times) — drives downstream tone calibration. New case 168 between 100 and 162 (food wedge). | calai10 | WL, Culture |

## Anti-patterns LOCKED OUT (unanimous reject across 4 briefs)

Cannot adopt regardless of conversion lift potential:

- ❌ "Crush your goal" labor verb (memory `feedback_post_ozempic_vocabulary` violation)
- ❌ "AI" anywhere in user-facing copy
- ❌ Health Score 7/10 numeric scoring
- ❌ Explicit decimal weight numbers ("5.3 kg" specific)
- ❌ Trophy-pop "Congratulations!" register
- ❌ Finger-pointing emoji on Allow CTAs
- ❌ Ozempic-substitute testimonials (use GLP-1 positive-frame instead)
- ❌ Clinical white background (keep JeniFit cream)
- ❌ Pre-experience 5-star rating prompt during onboarding loader

## Register-pair discipline (Culture brief #4)

Cal AI runs clinical-trust as default with ONE softness beat for
contrast. JeniFit MUST mirror this discipline in the opposite
direction — soft-girl warmth as default + **clinical-trust register
reserved for biometric questions only** (height/weight/age — where
clinical register actually REDUCES vulnerability friction).

Anti-patterns to avoid:
- Going saccharine on biometric asks (femvertising failure mode)
- Going clinical on identity/food/permission asks (Cal AI clone failure)

## Sprint impact

Net: 5-7 dev-days on top of existing v1.0.7 sprint. Phases:

- **Phase v8-A (~30 min):** quick wins — D80 (no payment due now), D84 (kill $0.92/wk), D79 (specific date in reveal)
- **Phase v8-B (~2 hrs):** D73 pace selector + D87 sunk-cost Q (new cases 167 + 168)
- **Phase v8-C (~2 hrs):** D75 3-stage loader expansion + D76 notification pre-prime + D77 Apple Health pre-paywall move
- **Phase v8-D (~3 hrs):** D74 multi-proof plan reveal + D81 comparison chart + D86 reciprocity beat
- **Phase v8-E (~2 hrs):** D78 two-step paywall split + D82 sign-in pre-paywall
- **Phase v8-F (~1 hr):** D83 cut 12 redundant cases + D85 ctaBtn standardization

Total: ~10-12 hours. Aggressive but matches founder's 5-7 dev-day estimate.

---

*End delta v8. v8 absorbs Cal AI's commitment-first architecture +
multi-proof reveal + pace selector + two-step paywall + register-pair
discipline. JeniFit's voice locks + Honesty Doctrine + anti-shame UX +
no-DB-changes are preserved at every adoption. Cal AI's $34-50M ARR
onboarding wisdom comes in; Cal AI's clinical-clone failure modes stay
out.*
