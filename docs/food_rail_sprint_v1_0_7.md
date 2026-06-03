# Food Rail v1.0.7 — Sprint Breakdown

Status: DRAFT. Operationalizes `docs/food_rail_plan.md` (v1 + v2 + v3 + v4 deltas, v4 wins where they conflict) into a 5-week ticketed sprint.

**Date:** 2026-06-03
**Target ship:** v1.0.7 (after 1.0.6 build 11 archives + Apple-approves)
**Estimated duration:** 5 weeks (~25 working days)
**Parallelizable streams:** dev work (this doc) + content work (JeniMethod 75-day lessons, see §6 below) + canonical pantry curation (see §7)

---

## 0. Pre-work (must land BEFORE Week 1 starts)

These are hard gates. Sprint cannot start until all six clear.

| # | Item | Owner | Status |
|---|---|---|---|
| 0.1 | 1.0.6 build 11 archives + Apple-approves | Founder (device walk + Xcode archive + ASC submit) | Pending (task #2) |
| 0.2 | After 1.0.6 approval: flip RC `v1_0_7` offering to "Current" | Founder (RC dashboard) | Pending |
| 0.3 | Founder sign-off on D19–D32 (v3 + v4 decisions) | Founder review of plan deltas | Pending (or implicit via sprint review) |
| 0.4 | Supabase Edge Function secrets configured (OPENAI_API_KEY, ANTHROPIC_API_KEY for v1.0.8 fallback) | Founder (Supabase dashboard) | Pending |
| 0.5 | USDA FoodData Central API key obtained (free tier, 1k req/hr per IP) | Founder | Pending |
| 0.6 | Canonical pantry first 100 entries drafted (or v1 pantry curator engaged) | Founder + Jeni voice | Pending (see §7) |

If 0.1 slips, sprint slides accordingly. Don't compress at the expense of v3 voice/safety locks.

---

## 1. Week 1 — Scaffolding

Goal: SPM package exists, Supabase schema ships, content delivery pipeline ready, feature flags wired. No user-visible UI yet.

### W1-T1 — Create `Packages/PlankFood` SPM package (1 day)

**Files created:**
- `Packages/PlankFood/Package.swift` (mirror `Packages/PlankEngine/Package.swift` exactly, swap name)
- `Packages/PlankFood/Sources/PlankFood/` (empty directory tree per v3 layout)
- `Packages/PlankFood/Tests/PlankFoodTests/Fixtures/` (golden LLM response JSON files for snapshot tests)

**Files modified:**
- `PlankAI.xcodeproj/project.pbxproj` — add PlankFood as a dependency of the main PlankAI app target

**Acceptance:** `swift build` from `Packages/PlankFood/` succeeds. PlankFood is `import`-able from main app target.

**Dependencies:** none

---

### W1-T2 — Supabase schema migration (1 day)

**Files modified:**
- `scripts/schema.sql` — add `food_logs`, `food_log_items`, `food_corrections`, `canonical_pantry`, `jenimethod_lessons` tables per v3 + v4 spec

Schema highlights:
```sql
-- v3 spec: hybrid real columns + JSONB payload
CREATE TABLE food_logs (
  id UUID PRIMARY KEY,
  user_id UUID REFERENCES auth.users,
  logged_at TIMESTAMPTZ NOT NULL,
  meal_slot TEXT CHECK (meal_slot IN ('breakfast','lunch','dinner','snack')),
  kcal_total NUMERIC NOT NULL,
  protein_g NUMERIC, carbs_g NUMERIC, fat_g NUMERIC, fiber_g NUMERIC,
  plate_type TEXT NOT NULL,
  source TEXT CHECK (source IN ('photo','quick_add','im_out')),
  confidence NUMERIC,
  payload JSONB,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- v4 spec: JeniMethod content delivery via Supabase (D30)
CREATE TABLE jenimethod_lessons (
  day_number INT PRIMARY KEY,
  title TEXT NOT NULL,
  pages JSONB NOT NULL,                -- array of page objects: { headline, body, illustration_asset }
  illustration_asset TEXT,
  today_prompt JSONB,                  -- optional: { kind: 'food_scan'|'quick_add'|'movement', copy }
  published_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ DEFAULT now()
);
```

RLS policies match existing pattern (`user_id = auth.uid()` on user-owned tables). `canonical_pantry` + `jenimethod_lessons` are public-read (no RLS — they're shared content).

**Acceptance:**
- Schema applies cleanly to a fresh Supabase project
- Existing tables (weight_logs, session_logs, etc.) unaffected
- RLS verified via SQL editor with test users

**Dependencies:** 0.1 (don't ship breaking schema before 1.0.6 ships)

---

### W1-T3 — Supabase Edge Functions skeleton (2 days)

**Files created:**
- `supabase/functions/food-vision/index.ts` — orchestrates GPT-5 call with cuisine prompt
- `supabase/functions/nutrition-lookup/index.ts` — USDA FDC + Open Food Facts + canonical_pantry join with response cache
- `supabase/functions/food-photo-cleanup/index.ts` — scheduled 30-day auto-delete for opt-in photo retention

For v1.0.7: implement `food-vision` only with GPT-5; stub out Opus fallback path (config-flagged, off by default per v3 D18).

Includes:
- Daily budget kill-switch ($50/day cap; logs `food_budget_cap_hit` to PostHog)
- Per-user rate limit (30 scans/day)
- Cost telemetry per scan to PostHog
- Apple 5.1.2(i)-compliant data handling (no training, contractual)

**Acceptance:**
- `food-vision` accepts a base64 image + user profile, returns LLM response in JSON schema
- Budget cap returns 429 with graceful copy when exceeded
- Rate limit returns 429 with copy when per-user cap hit
- Cost telemetry visible in PostHog

**Dependencies:** W1-T2 (schema must exist for telemetry table writes)

---

### W1-T4 — Feature flag plumbing (0.5 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Flags/FoodFlags.swift` — 3-layer flag stack per v3

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

**Files modified:**
- `PlankApp/Views/Debug/DebugAuthView.swift` — add toggle for `food_rail_dev_override`
- PostHog project — register `food_rail_v1` flag, set to 0% initially

**Acceptance:** Flag-off users see no food UI anywhere. Flag-on users see food entry points.

**Dependencies:** W1-T1 (PlankFood package must exist)

---

### W1-T5 — JeniMethod content table migration script (1 day)

**Files created:**
- `scripts/migrate_jenimethod_to_supabase.py` — reads existing `JeniMethodContent.swift` enum cases, transforms into `jenimethod_lessons` rows, uploads to Supabase

**Files modified:**
- `PlankApp/Views/DietEducation/JeniMethodContent.swift` — replace hardcoded enum with Supabase fetch + local cache (CoreData or SwiftData persistent cache)
- `PlankApp/Views/DietEducation/JeniMethodState.swift` — adapt to async lesson loading

This is the D30 architecture change. Lessons fetch on app launch (cached for offline). New lessons land via Supabase content update without app submission.

**Acceptance:**
- All 14 existing lessons render identically from Supabase source
- Offline mode still renders cached lessons
- New lesson added via Supabase appears in app within 1 minute of fetch

**Dependencies:** W1-T2 (schema must exist), W1-T1 (package), 0.1 (don't break existing JeniMethod for 1.0.6 users)

**Risk:** This is a refactor of existing shipped feature. Test heavily before merging. Suggest a feature flag (`jenimethod_supabase_enabled`, default false) to allow rollback.

---

## 2. Week 2 — Capture pipeline + LLM integration

Goal: photo capture works end-to-end with GPT-5, returns structured food data, app-side calorie math computes correctly. No result-card UI yet (raw debug output OK).

### W2-T1 — `FoodCapture` enum + dispatcher (0.5 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Capture/FoodCapture.swift`

```swift
public enum FoodCapture {
    case photo(Data, mode: PhotoMode)     // PhotoMode = .justAte | .deciding (D13)
    case quickAdd(PantryItemID)
    case imOutTonight(cuisine: CuisineChip?)  // D14, cuisine optional
}

public enum PhotoMode { case justAte, deciding }
```

**Acceptance:** Enum compiles. Exhaustive switch in coordinator catches all cases.

**Dependencies:** W1-T1

---

### W2-T2 — `PhotoCaptureView` reusing existing CameraManager (2 days)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Capture/PhotoCaptureView.swift`

**Files modified:**
- `PlankApp/Camera/CameraManager.swift` — add `captureStillFrame()` method that returns one frame buffer as JPEG Data (existing session reuse per v3 + code-map)

Per v3: reuses existing camera permission (already shipped for plank-form check). No new entitlement.

UI: scrapbook-framed viewfinder (cocoa border, soft shadow), large cocoa shutter pill, 3-mode toggle visible (`photo / quick-add / i'm out`), pre-eat toggle at top (`[just ate | deciding]` per D13).

**Acceptance:**
- Camera opens with no permission re-prompt for existing users (already authorized for plank)
- Shutter captures still frame, returns ≤1024px JPEG, EXIF-stripped, q0.8
- Pre-eat toggle visible and persists state across captures within a session

**Dependencies:** W2-T1, W1-T4

---

### W2-T3 — `FoodVisionService` calling Edge Function (1 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Pipeline/FoodVisionService.swift`

Sends `FoodCapture.photo` artifact to `/food-vision` Edge Function with user's `onboardingCuisinePreference` injected into system prompt. Receives structured items[] + plate_type + confidence.

**Acceptance:**
- Sends scan to Edge Function
- Receives valid JSON per response schema
- Streaming response renders first item at ~1.5s perceived
- Errors (network, cost cap, rate limit) handled with user-facing copy

**Dependencies:** W1-T3, W2-T1

---

### W2-T4 — `NutritionLookupService` USDA + Open Food Facts join (2 days)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Pipeline/NutritionLookupService.swift`

App-side calorie math from grams × per-source nutrition density. **LLM never returns calories directly** per v3 Honesty Doctrine.

Lookup priority: USDA FDC → Open Food Facts → canonical_pantry. First match wins.

Includes USDA FDC response cache in Supabase Edge Function (`nutrition-lookup` from W1-T3) to avoid hitting 1k req/hr rate limit.

**Acceptance:**
- Given an item with `usda_search_terms`, returns kcal/protein/carbs/fat per gram from highest-match-score source
- Falls through cleanly when USDA misses
- Cache reduces duplicate USDA calls (logged)

**Dependencies:** W2-T3

---

### W2-T5 — `CalorieMathService` (THE load-bearing algorithm, 1 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Pipeline/CalorieMathService.swift`
- `Packages/PlankFood/Tests/PlankFoodTests/CalorieMathServiceTests.swift`

Per v3: this is the equivalent of Things 3's conflict-resolution math. **Pure functions, zero UIKit, zero network, 100% fixture-tested.** Code review gate: any PR touching this file requires explicit founder review.

Computes `total_kcal`, `total_protein_g`, etc. from items[] + nutrition lookup results. Handles uncertainty bands (`portion_grams_low/high`).

**Acceptance:**
- Snapshot tests against 20+ golden fixtures (varied plate types, edge cases, uncertainty ranges)
- 100% test coverage on calorie aggregation logic
- No UIKit, no Foundation networking imports

**Dependencies:** W2-T4

---

## 3. Week 3 — Result rendering + corrections

Goal: result card UX ships end-to-end. User can scan → see result → log → correct.

### W3-T1 — 6 atomic Views (2 days)

**Files created in `Packages/PlankFood/Sources/PlankFood/Result/Atoms/`:**
- `ItemRow.swift` — food name (italic Fraunces on punch word), portion grams, confidence cue
- `MacroRow.swift` — cal · P · C · F single row
- `JeniLine.swift` — one-sentence interpretation (cuisine/cycle/GLP-1-aware)
- `ConfidencePill.swift` — copy-based uncertainty ("around 480, give or take a slice")
- `PortionStepper.swift` — tap-to-edit with low/high anchors + haptic stops
- `RestaurantRangeBar.swift` — "~700–900 kcal" range for "i'm out" mode

Each atom: ~30–80 lines SwiftUI, scrapbook chrome, voice-locked copy.

**Acceptance:**
- Each atom has SwiftUI Preview with 3+ states
- Snapshot tests for each atom
- Dynamic Type clamps at accessibility1

**Dependencies:** W1-T1

---

### W3-T2 — 2 plate layout Views (1 day)

**Files created in `Packages/PlankFood/Sources/PlankFood/Result/PlateLayouts/`:**
- `SingleDishCard.swift` — for `plate_type: single | bowl`
- `MixedPlateCard.swift` — for `plate_type: mixed | charcuterie | shared | restaurantRange`

Each layout composes atoms differently. Hand-written (no generic renderer per v3 "no abstraction until 3+" rule).

**Acceptance:**
- Each plate layout renders against fixture data
- Pre-eat mode variant uses copy template ("you have room") instead of "log it"
- Result card streams items in (first at ~1.5s)

**Dependencies:** W3-T1, W2-T3

---

### W3-T3 — `QuickAddView` rail (1 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Capture/QuickAddView.swift`

6 beverages per v3 D20: matcha latte (oat), oat milk latte, iced coffee, brown sugar boba, protein shake, smoothie. Each opens 3-tap sheet (size / milk / sweetness) → outputs `FoodCapture.quickAdd(PantryItemID)`.

**Acceptance:**
- 6 tiles render with stickers + names
- 3-tap edit sheet logs in <5s
- Outputs identical `FoodLog` shape as photo flow

**Dependencies:** W1-T1, 0.6 (canonical pantry curated)

---

### W3-T4 — `ImOutTonightView` placeholder (0.5 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Capture/ImOutTonightView.swift`

Per v4 D14: tap-once logs "ate out, ~700 kcal" placeholder with time-of-day-appropriate default. Optional inline cuisine chip refines estimate. No hunger sliders.

**Acceptance:**
- Single tap logs placeholder
- Optional cuisine chip refines estimate (mexican ~600, korean ~750, italian ~850 — rough defaults)
- "Edit later if you want" copy visible

**Dependencies:** W3-T1, W3-T2 (uses `RestaurantRangeBar` atom)

---

### W3-T5 — `FoodCorrectionSheet` (1 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Result/FoodCorrectionSheet.swift`

Per v3: tap any item in result card → edit sheet. Portion slider anchored to low/high. Tap food name → search canonical pantry + USDA + recent foods. "This isn't right" → describe in words → re-runs LLM with text context.

Defaults to "looks good — log it." Correction is opt-in.

**Acceptance:**
- Tap item opens correction sheet
- Slider haptic stops at S/M/L
- Save updates `food_logs` AND fires `food_corrections` insert with diff
- Re-run LLM path works (uses text context + image hash)

**Dependencies:** W3-T2, W2-T3

---

### W3-T6 — `FoodCorrectionsLogger` + `FoodLog` SwiftData model (1 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Model/FoodLog.swift` — SwiftData @Model, wrapped in `FoodSchemaV1: VersionedSchema` per v3
- `Packages/PlankFood/Sources/PlankFood/Model/FoodLogItem.swift`
- `Packages/PlankFood/Sources/PlankFood/Model/FoodLogSchemaV1.swift` — VersionedSchema wrapper
- `Packages/PlankFood/Sources/PlankFood/Pipeline/FoodCorrectionsLogger.swift`

**Files modified:**
- `PlankApp/Sync/AppSync.swift` — add `upsertFoodLog(_:)` following existing pattern

**Acceptance:**
- FoodLog persists locally to SwiftData
- Syncs to Supabase via existing upsert pattern
- Corrections fire as separate `food_corrections` insert (not user-visible)
- Cross-account isolation enforced (userId filter)
- VersionedSchema wrapper allows future migration

**Dependencies:** W1-T2, W3-T5

---

## 4. Week 4 — Home + Becoming integration + Settings

Goal: food rail visible on Home + Becoming. Settings sub-screen ships. End-to-end user flow complete.

### W4-T1 — Home Slot 4 restructure: `TodayHealthStrip` (2 days)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Tiles/HomeFoodTile.swift` — soft ring + weekly caption per v3 redesign
- `PlankApp/Views/Home/TodayHealthStrip.swift` — composes HomeFoodTile + steps pill + breath pill

**Files modified:**
- `PlankApp/Views/Home/HomeView.swift` — Slot 4 component swap behind FoodFlags.isEnabled

Per v3: food card with single soft ring (no over-target language, neutral cocoa palette) + weekly avg caption + steps/breath as lateral pills below. NO 3-ring concentric, NO "calories burned" anywhere.

Tap food ring → CameraView (fullScreenCover).

**Acceptance:**
- Flag-on users see TodayHealthStrip
- Flag-off users see existing StepsPulseTile + BreathworkHomeCard (unchanged)
- Tap food ring opens camera
- Caption shows weekly average correctly when food logs exist
- Empty state copy: "ready when you are"

**Dependencies:** W3-T1, W3-T2, W3-T3, W3-T4, W3-T6, W1-T4

---

### W4-T2 — One-time soft tile for existing users (0.5 day)

**Files created:**
- `PlankApp/Views/Home/FoodRailIntroTile.swift` — dismissable banner

**Files modified:**
- `HomeView.swift` — render above food card when `existingUser AND foodRailEnabled AND NOT dismissed AND NOT scanned`

Per v4 §2: no popup, no modal. Banner copy: *"jenifit now reads your plate — tap to try"*. Dismissable. Persists 7 days max.

**Acceptance:**
- Banner appears for existing users on flag-flip day
- Tap → opens camera
- Dismiss → never shows again for this user
- Auto-dismisses after 7 days or first scan

**Dependencies:** W4-T1

---

### W4-T3 — Becoming Story Card stack restructure (5 days, biggest single ticket)

**Files created:**
- `PlankApp/Views/Analytics/BecomingStackView.swift` — vertical scrapbook stack per v3
- `PlankApp/Views/Analytics/Cards/YourWeekCard.swift` — hero with EMA weight trend + soft directional copy
- `PlankApp/Views/Analytics/Cards/WhatYouAteCard.swift` — 7-day intake bars + rolling avg + caption
- `PlankApp/Views/Analytics/Cards/HowYouMovedCard.swift` — steps + sessions + breath count (NO kcal-burned)
- `PlankApp/Views/Analytics/Cards/WhatsChangingCard.swift` — barrier-resolved + mastery curve + identity affirmation
- `PlankApp/Views/Analytics/Cards/WhatsWorkedCard.swift` — expanded nsvTile content

**Files modified:**
- `PlankApp/Views/Analytics/AnalyticsView.swift` — gate the bento-vs-stack rendering on `FoodFlags.isEnabled`

Per v3: cards reorder by signal density (empty food card collapses to empty state). Trend card always renders.

Per v3 Honesty Doctrine: How You Moved card NEVER shows "calories burned." Shows steps + sessions + breath count.

Voice locks: italic Fraunces on identity verbs only (*becoming*, *moving*, *tracking*, *showing up*).

**Acceptance:**
- Flag-on users see new stack
- Flag-off users see existing bento grid (unchanged)
- Cards correctly hide/empty-state based on data availability
- Trend hero card renders correctly with existing weight EMA
- Movement card aggregates HealthKit steps + JeniFit sessions + breath count

**Dependencies:** W3-T6, W4-T1

**Risk:** Largest single ticket. Suggest sub-tickets for each card. Consider splitting across 2 weeks if Week 4 falls behind.

---

### W4-T4 — Food Settings sub-screen (1 day)

**Files created:**
- `PlankApp/Views/Settings/FoodSettingsView.swift`

**Files modified:**
- `PlankApp/Views/Settings/SettingsView.swift` — add `.foodSettings` case to enum
- `PlankApp/Views/Settings/SettingsMenuView.swift` (or equivalent) — add menu entry

Per v4 spec: calorie target edit, dietary pattern, exclusions, cuisine profile, HealthKit toggle (default off), evening check-in toggle (default off), photo retention pref, AI disclosure status, export data.

**Acceptance:**
- All settings persist via AppStorage
- HealthKit toggle requests Dietary Energy write permission when flipped on
- Evening check-in toggle wires to NotificationPermission
- Export data sends user to support@jenifit.app with their data CSV (or similar)

**Dependencies:** W1-T4

---

### W4-T5 — Paywall food-variant hero (0.5 day)

**Files modified:**
- `PlankApp/Views/Paywall/PaywallView.swift` — add food-variant hero when `food_rail_enabled = true` AND user hasn't yet engaged with food rail

Per v3 sample copy: *"see your weight-loss story unfold. what you eat, how you move, how it's working — drawn against your weekly trend."*

**Acceptance:**
- Flag-on non-engaged users see food-variant hero
- Existing bodyFocus-personalized hero unchanged for flag-off or engaged users
- A/B-able via RevenueCat or PostHog flag

**Dependencies:** W1-T4

---

## 5. Week 5 — JeniMethod expansion + instrumentation + content + QA

Goal: ship Days 1–30 of new JeniMethod arc + Day 2 reorder + 15 new lessons + PostHog instrumentation + cost telemetry verified + launch-week ramp prep.

### W5-T1 — JeniMethod Day 2 reorder + 15 new lessons in content table (1 day code + parallel content work)

Per v4 D28: Day 2 = food intro (new). Existing Day 2–14 shift to Day 3–15. Days 16–30 are new.

**Files modified:**
- `PlankApp/Views/DietEducation/JeniMethodContent.swift` — updated to fetch from Supabase content table (already refactored in W1-T5)

**Data:** 16 new lesson rows in `jenimethod_lessons` table (Day 2 + Days 16–30). Each row has title, pages JSONB, illustration_asset, today_prompt.

Content writing happens IN PARALLEL with dev work (see §6 below). By Week 5, content team should have Days 2 + 16–30 written + illustrations generated via Grok pipeline.

**Acceptance:**
- All 30 lessons (1–30) load from Supabase
- Day 2 renders new food intro lesson
- Days 3–15 render shifted existing lessons
- Days 16–30 render new content
- Catch-up tile pattern works (missed days surface as tiles, never restart)

**Dependencies:** W1-T5 (Supabase content table migration), content team (see §6)

---

### W5-T2 — Catch-up tile pattern (1 day)

Per v4 D31: missed-day lessons surface as "catch up" tiles on Home. Day-counter advances every calendar day; never resets.

**Files modified:**
- `PlankApp/Views/Home/HomeView.swift` — JeniMethod card area renders catch-up tiles above today's lesson card when missed days exist
- `PlankApp/Views/DietEducation/JeniMethodState.swift` — track which days have been completed; surface missed ones

**Acceptance:**
- Missing 2 days = 2 catch-up tiles + today's tile visible
- Max 3 catch-up tiles at once (oldest archives)
- Completing a catch-up tile marks it done; programDay continues to advance daily
- No "restart from Day 1" path anywhere in code

**Dependencies:** W5-T1

---

### W5-T3 — PostHog instrumentation (1 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Analytics/FoodAnalytics.swift`

**Files modified:**
- `PlankApp/Analytics/AnalyticsManager.swift` — register new event cases

Events per v3 spec (15+):
- Funnel: `food_ai_consent_shown`, `food_ai_consent_accepted`, `food_ai_consent_declined`, `food_first_scan_started`, `food_first_scan_completed`, `food_first_log_saved`
- Per-scan: `food_scan_started`, `food_scan_completed`, `food_scan_correction_opened`, `food_scan_correction_saved`, `food_scan_fallback_fired`
- Mode-specific: `food_pre_eat_used`, `food_quick_add_tapped`, `food_im_out_used`, `food_voice_input_used` (future)
- Funnel + retention: `food_target_overshown`, `food_glp1_protein_floor_hit`, `food_streak_milestone`, `food_retention_consent_opted_in`, `food_retention_consent_opted_out`
- Cost telemetry: `food_budget_cap_hit`, `food_rate_limit_hit`, `food_scan_cost` (per scan with model + tokens)

Properties on every event: `cuisine_profile`, `meal_slot`, `confidence_min`, `glp1_status`, `paid_status`.

**Acceptance:**
- All events fire correctly during end-to-end test
- PostHog dashboard shows funnel data within minutes of test scans
- Cost telemetry rolls up to daily total

**Dependencies:** W2-T3, W3-T6, W4-T1

---

### W5-T4 — AI consent modal + transparent processing copy (0.5 day)

**Files created:**
- `Packages/PlankFood/Sources/PlankFood/Capture/FoodAIConsentSheet.swift` — one-time modal per Apple 5.1.2(i)
- `Packages/PlankFood/Sources/PlankFood/Capture/FoodProcessingView.swift` — streaming "looking at your plate → matching ingredients → estimating portions"

Per v3 copy: *"to read what's on your plate, JeniFit shares your photo with vision models from OpenAI and Anthropic. they don't train on your data."*

**Acceptance:**
- Modal fires once before first scan
- Acceptance stored in `food_ai_consent_at` Supabase profile field
- Processing view shows transparent 3-line copy during 1.5–3s scan
- Re-prompt if any provider changes (future-proof)

**Dependencies:** W2-T3

---

### W5-T5 — Notification cadence (food) (0.5 day)

**Files modified:**
- `PlankApp/Notifications/NotificationPermission.swift` — add food-specific scheduling per v4 §4

Per v4: `food_first_log_nudge` (mandatory, fires once Day 3 if no scan) + `food_evening_check_in` (opt-in via Settings, default off).

**Acceptance:**
- First-log nudge fires correctly on Day 3 if conditions met
- Evening check-in skips when no meals logged today (anti-shame)
- Both fit within 5/wk research ceiling

**Dependencies:** W4-T4

---

### W5-T6 — Onboarding v2 cuisine question (case 165) (0.5 day)

**Files modified:**
- `PlankApp/Views/Onboarding/OnboardingView.swift` — add case 165 to v2FlowOrder, after case 164 (glp1Status)

Per v3 D17: cuisine multi-select chips. Saves to new `@AppStorage("onboardingCuisinePreference")` as comma-separated string.

For existing v1-onboarding users: 3-question retro-prompt fires at first scan attempt (cuisine + dietary + exclusions).

**Acceptance:**
- New v2 users see case 165 in flow
- Existing users get retro-prompt at first scan
- Cuisine value flows into FoodVisionService system prompt

**Dependencies:** W2-T3

---

### W5-T7 — End-to-end QA + cost burn test (2 days)

**Manual + automated:**
- 50+ test scans across cuisines (Korean, Mexican, American, Mediterranean, girl dinner, restaurant)
- Cost burn test: simulate 100 users × 5 scans/day, verify daily budget cap + per-user rate limit fire correctly
- Correction rate target: <30% (above this = trust collapse, flag to founder)
- Crash rate: 0 on test set
- Latency: <4s scan-to-log (1.5s TTFT + 2s reading + 1 tap)
- AI consent acceptance: >80% on internal test cohort
- Becoming Story Card renders correctly across data density variations
- Home Slot 4 swap renders cleanly for flag-on and flag-off users

**Dependencies:** all prior tickets

---

## 6. Parallel content stream — JeniMethod 75-day lessons

**Owner:** Founder + Jeni voice (or curator). Parallelizable with dev work.

**Scope for v1.0.7 ship:** Day 2 + Days 16–30 = 16 new lessons. (Days 31–75 land in v1.0.8 content-only update via Supabase.)

**Per lesson deliverable:**
- 2-page primer copy (200–300 words each page, Jeni voice, lowercase casual, italic Fraunces on punch words, no banned vocab per `feedback_post_ozempic_vocabulary`)
- 1 illustration (216×216@3x, paper-craft style, Grok pipeline per `feedback_jenimethod_design`)
- 1 today_prompt (optional, JSONB shape: `{ kind: 'food_scan'|'quick_add'|'movement', copy }`)

**Estimated effort:**
- Writing: ~1.5 hours per lesson × 16 lessons = ~24 hours
- Illustration generation + curation: ~30 min per illustration × 16 = ~8 hours
- Total: ~32 hours over 3–4 weeks part-time

**Recommended sequence:**
- Week 1: Draft Day 2 (food rail intro) + Days 16–20 (food rail depth core)
- Week 2: Days 21–25 (girl dinner / quarter milestone)
- Week 3: Days 26–30 (cycle awareness / 4-week reflection)
- Week 4: Final review + illustrations finalized
- Week 5: Upload to Supabase + verify in app

---

## 7. Canonical pantry curation

**Owner:** Founder + Jeni voice.

**Scope for v1.0.7 ship:** 100 entries (reduced from v1 plan's 200 — ship faster, expand via correction data).

**Per entry:**
- name (string)
- search_terms (array — for fuzzy matching)
- cuisine_hint
- default_serving_g
- kcal_per_100g
- protein/carbs/fat/fiber per 100g
- source attribution

**Cohort-priority order per v3 §Audience-specific tools:**
1. 25 beverages (matcha latte variants, oat milk lattes, boba, protein shakes, smoothies, kombucha, wine, cocktails, beer, sparkling water)
2. 15 girl dinner staples (cheese cubes, crackers, grapes, salami, hummus + pita, popcorn, cottage cheese bowls)
3. 15 Korean home-cooked (banchan, kimchi-jjigae, bibimbap, gimbap, soft tofu stew, KFC, bulgogi)
4. 20 restaurant chains (Sweetgreen × 6, Cava × 4, Chipotle × 4, Starbucks × 6)
5. 10 Mediterranean / clean girl (Greek yogurt + honey + nuts, hummus + veg, grilled salmon, quinoa bowls, açaí bowls)
6. 15 Mexican / Latin (tacos, burritos, guac, rice + beans)

**Estimated effort:** ~30 min per entry × 100 = ~50 hours over 4–5 weeks part-time. Parallelizable with dev work.

**Quality bar:** every entry has nutrition sourced from official restaurant menu data, USDA, or labeled manufacturer data (no guesses).

---

## 8. Launch-week ramp (post-Week-5)

Per v4 §5 + D32:

| Day | Cohort | What to monitor |
|---|---|---|
| 0 | Submit + flag off | Apple review |
| 1–3 | 5–10 internal users | Crash rate, scan latency, USDA hit rate, correction rate, cost per scan, edge function errors |
| 4–7 | 10% paid users (PostHog random) | Scan rate per user, correction rate, paywall conversion delta, JeniMethod Day 2 completion |
| 8–14 | 50% paid users | Cohort-specific behaviors, Day 7 retention delta vs flag-off |
| 15+ | 100% paid + open to new users | Full launch metrics, success vs Phase 1 → Phase 2 decision gate |

**Gates (any failure freezes ramp):**
- Crash rate spike (>0.5% sessions)
- Correction rate >25% (week 1)
- Daily cost budget cap hit
- Apple disclosure compliance issue
- Negative App Store review pattern around food rail

---

## 9. Risk log + open questions

| Risk | Mitigation | Owner |
|---|---|---|
| W1-T5 (JeniMethod refactor to Supabase) breaks existing shipped feature | Ship behind `jenimethod_supabase_enabled` flag, default false; flip after testing | Dev |
| W4-T3 (Becoming Story Card) is 5 days — largest ticket, may overrun | Split into sub-tickets per card; consider deferring "What's Worked" card to v1.0.7.1 patch if Week 4 slips | Dev |
| Content team can't deliver 16 lessons + illustrations in 5 weeks | Reduce v1.0.7 scope to Days 1–22 (Day 2 + Days 16–22 = 8 new lessons); push Days 23–30 to v1.0.7.1 patch | Founder |
| Canonical pantry 100 entries not curated by Week 3 | Ship with smaller pantry (50 entries) + heavier USDA fallback weighting | Founder |
| LLM costs exceed forecasts | Daily budget cap + per-user rate limit are pre-built; if hit, reduce GPT-5 to GPT-5-mini for non-paid (paid stays full) | Dev (config flag) |
| Apple rejects 1.0.7 over 5.1.2(i) disclosure | Disclosure copy + modal pre-built per v3; pre-emptively cite the relevant guideline in App Review Notes | Founder |
| Correction rate >30% on v1.0.7 (trust collapse signal) | Honesty Doctrine designed to mitigate; if signal still triggers, enable Opus 4.7 fallback via config flag (week 2 of launch) | Dev (config flag) |

**Open questions to resolve before Week 1 starts:**
1. Who owns content (founder writes vs curator engaged)?
2. Confirm Supabase Edge Function deployment process (already wired?)
3. Confirm PostHog feature flag access (already wired?)
4. USDA FoodData Central API key — does Han already have one?
5. Open Food Facts integration — direct REST or via library?

---

## 10. Dependencies + parallelization summary

```
Week 1: scaffolding (parallel: SPM + Supabase + Edge Functions + flags + content table refactor)
   ↓
Week 2: capture pipeline (sequential: enum → camera → service → lookup → math)
   ↓
Week 3: result UI (parallel: atoms ↔ plate layouts ↔ quick-add ↔ i'm out ↔ corrections ↔ SwiftData model)
   ↓
Week 4: integration (parallel: Home ↔ Becoming ↔ Settings ↔ Paywall)
   ↓
Week 5: JeniMethod + instrumentation + AI consent + QA (parallel: content sync + events + consent + cost burn)
   ↓
Launch ramp (post-Week 5)
```

**Parallelizable across the entire sprint:**
- Content writing (Days 2 + 16–30 lessons)
- Canonical pantry curation (100 entries)
- Illustration generation via Grok

**Sequential bottlenecks:**
- W2-T3 → W2-T4 → W2-T5 (pipeline must build before rendering)
- W3-T1 → W3-T2 (atoms before plate layouts)
- W4-T1 → W4-T2 (Slot 4 must restructure before intro tile)
- W5-T1 requires W1-T5 done

---

## 11. Definition of done (v1.0.7 ship readiness)

- [ ] All Week 1–5 tickets land
- [ ] 16 JeniMethod lessons live in Supabase
- [ ] 100 canonical pantry entries live in Supabase
- [ ] Internal QA cohort uses food rail for 3 days without P0 bugs
- [ ] Cost telemetry confirms <$5/day burn at internal cohort scale
- [ ] Correction rate <30% on internal test set
- [ ] AI consent modal copy reviewed by founder
- [ ] Paywall food-variant hero copy reviewed by founder
- [ ] Notification copy reviewed by founder
- [ ] Becoming Story Card visual review passed
- [ ] Apple validation green (5.1.2(i), entitlements, app privacy labels updated)
- [ ] App Privacy Label additions submitted in ASC: Photos (linked), Health & Fitness > Nutrition (linked)
- [ ] Feature flag confirmed at 0% in PostHog
- [ ] Rollback plan tested (flag flip → app reverts cleanly)

---

*End sprint breakdown. Source-of-truth for v1.0.7 ticketing. Updates land as separate PRs against this doc.*
