# JeniFit Food Rail — Implementation Plan v1

Status: DRAFT for founder review. Decisions flagged `[FOUNDER Q#]` need explicit sign-off before Phase 1 starts.
Date: 2026-06-01
Target ship: v1.0.8 (after 1.0.6 build 11 archive lands and is approved)

---

## TL;DR

- **Build the photo→calorie feature that beats Cal AI on cohort fit** (Gen-Z women 22–35, TikTok-acquired, weight-loss-motivated, anti-shame). Validated demand: PostHog shows 12 of 13 food-rail-tappers converted to paid (~92% correlation), 5× more taps than other "coming soon" rails.
- **Model stack locked:** GPT-5 base primary + Claude Opus 4.7 confidence-gated fallback + Gemini 2.5 Flash food-or-not pre-filter. Cuisine profile from onboarding fed into system prompt as anti-cultural-bias lift Cal AI lacks. Blended cost ≈$443/mo at 10k paid users = 0.09% of $480k ARR — non-binding.
- **Nutrition DB:** USDA FoodData Central + Open Food Facts + JeniFit canonical pantry (~2k hand-curated entries covering boba, açaí, protein shakes, oat-milk lattes — the cohort-specific gaps). LLM returns identity + grams only; calorie math happens app-side from the DB join. Never trust the LLM for nutrition numbers.
- **Cohort wedge:** GLP-1-aware protein floor + Jeni interpretation layer + 3 meal slots default + "showing up" streak (not "under-target" streak) + camera→result in one tap. No "AI" word, no red bars, no good/bad food labels. Cycle-aware target adjustment **deferred** — evidence is small and noisy, and we'd need cycle-date infra we don't have.
- **Phase 1 ships in 4–6 weeks** behind premium gate. Phase 2 adds two-photo workflow + cycle integration via HealthKit. Phase 3 fine-tunes own model on corrections dataset at ~100k labeled scans — Cal AI's exact playbook.

---

## The wedge

Cal AI's accuracy is commodity (vision is a saturated arms race). Their *moat* is the conversion machine — 123 paywall experiments, 46 trigger points, ~$50M ARR. JeniFit's moat is **the layer above the calorie number**: cuisine profile from onboarding feeds the prompt (anti-bias accuracy lift), Coach Jeni voice interprets ("luteal-phase wednesday, eat the snack" / "GLP-1 days the protein matters more than the deficit"), anti-shame visualizations replace MFP's red bars. **Two wedges stack: better accuracy on cohort food + better interpretation of the number.** Cal AI was just acquired by MyFitnessPal (Mar 2026); their pull from the App Store in April 2026 for deceptive billing signals Apple is actively policing the category. Our existing v1.0.7 pricing compliance work already inoculates us.

---

## Phase sequence

### Phase 1 — v1.0.8 — MVP behind premium gate
**Goal:** prove the loop works. Photo→identification→portion→USDA join→Jeni interpretation→logged. 3 meal slots. Manual correction. Daily ring on Home. Weekly bento on Becoming.
**Time:** 4–6 weeks after 1.0.6 archive approval.
**Decision gate to Phase 2:** ≥40% of paid users scan ≥3×/week in month 1, AND month-2 retention of scanners > non-scanners by ≥5pp.

### Phase 2 — v1.0.9 — accuracy + cohort depth
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

### App Privacy Label additions (v1.0.8 submission)

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

Lessons ship in the same release as the food rail (v1.0.8). Earlier-ship would teach a feature that doesn't exist. Triggered from the `.generic` Day-15+ pool, weighted to surface these three lessons preferentially in the first 14 days after food-rail flag flips for a user.

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

### After v1.0.8 food rail (component swap at Slot 4 + Slot 5)

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

### After v1.0.8 (insertion + reordering)

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

`@AppStorage("food_rail_enabled")` default `false`. Lands shipped behind the flag in v1.0.8 — flag off means zero new code paths execute.

**Flip mechanism (in order of rollout maturity):**
1. **DebugAuthView toggle** — internal QA only, day 0
2. **PostHog remote config** keyed off user ID + paid status — gradual rollout days 1–14
3. **AppStorage default flip to true** in v1.0.9 — full release after telemetry confirms no regressions

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

### Paywall hero variant for v1.0.8 launch

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
- **Two-photo workflow UI** — schema field `needs_second_photo` ships, UI deferred to v1.0.9 per v1 plan. (Reverses my earlier v2 suggestion to pull forward — research showed pre-eat mode + restaurant mode are higher-impact wedges for this cohort than +11pp portion accuracy on solid foods.)
- **HealthKit menstrualFlow read** — Phase 2 per v1 plan, unchanged.

### Keep from v1 plan (essential)

- **GPT-5 base with cuisine-profile-aware system prompt** — the accuracy wedge
- **App-side calorie math from USDA join** — never trust LLM for numbers
- **Supabase Edge Function as the LLM proxy** — keys server-side, caching, budget cap
- **Corrections-as-moat data from day 1** — image hash + LLM output always; raw photo opt-in 30 days
- **Recent-foods cache (pull from v1.0.9 → v1.0.8)** — cohort eats same boba/matcha/oat-latte daily; 0-API-call repeat scans are free accuracy

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

### Phase 1 — v1.0.8 — MVP behind premium gate (4–6 weeks)

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

### Phase 1.5 — v1.0.9 — depth + accuracy (4 weeks after Phase 1)

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
