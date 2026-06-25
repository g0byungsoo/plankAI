# Snap Food — hang fix + premium failure UI + accuracy (2026-06-23)

Branch: `feat/snap-food-carousel-redesign`. A 5-expert panel (iOS concurrency,
OpenAI prompt, calorie-estimation scientist, backend, her75/JeniFit design)
diagnosed and specced this. Their full deliverables are summarized here; the
load-bearing artifacts (new prompt, schema, reliability fix, the concurrency
fix) are already applied in the code with heavy inline comments.

## 1. The bug: "scanning forever" — FIXED + verified

**Root cause:** the `isCapturing` flag that pins the "scanning" UI is reset
ONLY by `defer { isCapturing = false }` in `PhotoCaptureView.captureTapped()`,
which requires the whole async chain to settle. Three awaits in that chain
could fail to settle:
1. The AVFoundation capture continuation (`FoodCameraManager.captureStill`)
   was resumed only from `didFinishProcessingPhoto`, which iOS does NOT
   guarantee fires on an interrupted/errored capture → `await` hangs forever,
   network-independent (matches "hangs on fast wifi").
2. A bare `await Task.detached { FoodScanActivity.start }.value` sat OUTSIDE
   the do/catch and could pin the scan.
3. The 180s URLSession timeout was itself "forever" UX.

**Fix (defense in depth), all shipped in the iOS app:**
- `Capture/ScanDeadline.swift` — `withScanDeadline(_:operation:)`: a hard
  deadline that frees the caller even if the work is stuck on a
  non-cancellable await (races two unstructured tasks + a resume-once latch;
  a `withThrowingTaskGroup` can't do this — it blocks on the stuck child).
- `FoodCameraManager` — the capture continuation is now cancellable
  (`withTaskCancellationHandler`) AND has the guaranteed terminal delegate
  `photoOutput(_:didFinishCaptureFor:error:)` as a second safety net, routed
  through a resume-once funnel.
- `captureTapped` + `libraryImagePicked` wrap capture+dispatch in
  `withScanDeadline(scanDeadlineSeconds)`; the ActivityKit start is now a
  direct synchronous call (it was synchronous all along).
- `FoodVisionService.requestTimeout` 180s → **30s**.

**Tunable constants** (set from PostHog scan-duration p95 over time):
- `PhotoCaptureView.scanDeadlineSeconds` = **45s** (hard UI ceiling; was 35s,
  bumped after real-device testing showed legit gpt-4o scans erroring)
- `PhotoCaptureView.scanLongHintSeconds` = **15s** (reassurance nudge; was 9s,
  which fired on nearly every scan)
- `FoodVisionService.requestTimeout` = **30s** (network)
- EF `OPENAI_TIMEOUT_MS` = **26s** (sits under the client so the server
  returns a structured `openai_timeout` before the client gives up)

## Round 2 — founder real-device feedback (2026-06-23)

1. **Scanning had no animation** → rebuilt `ScanningOverlay` as a *luxury laser
   sweep* (warm-white core + soft rose glow, no neon) and reconnected it to the
   camera layer. (The design-review calm-down had removed the old neon scanline;
   the founder wanted the laser feel back, just premium.)
2. **"a little longer" on every scan + errors on good wifi** → gpt-4o vision is
   legitimately ~10-20s (cold EF + sequential Supabase limit queries + the odd
   retry). Raised the nudge to 15s and the ceiling to 45s, and **parallelized
   the EF limit checks** (`Promise.all`). The real speed fix is deploying the
   EF (the parallel checks + the OpenAI-body abort cut the tail). If it's still
   slow after deploy, the next lever is making `checkDailyBudget` a server-side
   SUM instead of fetching all of today's rows.
3. **Result card bottom cut off** → removed the verbose smart-pair sentence
   ("a handful of berries later locks in fiber") from slide 1; the compact
   "+ berries" chip stays, and the "high protein ♥" tag now fits.

## 2. Premium failure / retry UI — SHIPPED + verified

- New `ScanFailure` state (`.general` / `.connection` / `.noFood`) → a gentle
  cream card over the dimmed (kept) photo, with `try again` (cocoa) + `use a
  photo` / `type it instead`. Never red, never a banner, never an error haptic.
- `.connection`/`.general` reuse the captured photo on retry; `.noFood`
  returns to live camera to reframe.
- A ~9s "a little longer than usual…" nudge before the deadline.
- Empty-frame results re-routed from the old top banner into this card.

## 3. Scanning state calm-down — SHIPPED + verified

The old scan fired FIVE simultaneous tells incl. the only neon (#FF13F0) in
the palette. Now: dusty-rose `accent` border (3pt, slow travelling light,
no neon, no color hop); the sweeping scanline is cut; the shutter recedes
instead of spinning; the redundant "scanning ♥" toolbar pill is deleted.

## 4. Accuracy — EF code applied, NEEDS DEPLOY (founder-gated)

The three founder complaints are addressed in `supabase/functions/food-vision/index.ts`:
- **Quantity blindness** → COUNT-FIRST prompt + new `count`/`unit` fields;
  scale-reference + volume/density methodology; `portion_grams = count ×
  per-unit grams`.
- **Cultural naming** → `name_native` (authentic dish name, e.g. *bulgogi*)
  + `english_name` gloss; `name` mirrors the native name for back-compat.
- **Shared food** → the model returns kcal for the WHOLE visible dish +
  `servings_in_dish` + `is_shareable`; the USER resolves their share in the
  app (the model never guesses headcount).

**Reliability fix applied** (the backend expert's #1 defect): the OpenAI
fetch AND response-body read now run under ONE `AbortController` (the body
read was previously unbounded → the opaque long hang), timeout lowered
90s → 26s, and the 405 now returns JSON.

iOS decode is shipped + backward-compatible: `FoodVisionService.VisionResponse.Item`
+ `CapturedItem` gained the new optional fields; `map()` prefers the native
name; the USDA calibration sweep carries the fields through. Until the EF is
deployed these are simply nil and the app behaves as today.

### TO DEPLOY (founder)
```bash
supabase functions deploy food-vision --no-verify-jwt
# optional: deno check supabase/functions/food-vision/index.ts   (deno not installed locally)
```
The new schema is strict-mode legal (every new property is in `required`).
iOS already decodes the new fields, so deploy order is safe either way.

## 5. Remaining follow-ups (not in this pass)

- **"My share" UI control + count display** (the visible half of the
  shared-food + quantity fix). Data now flows on `CapturedItem`
  (`count`, `unit`, `servingsInDish`, `isShareable`). Next: in the result
  card show "5 pieces · 450g" and, when `isShareable`, a "did you share
  this?" stepper that scales the logged totals by `userServings /
  servingsInDish` (linear; apply AFTER the USDA sweep). Spec from the
  calorie scientist: default whole for single servings, 1 serving for
  shareables with an easy "actually I had more" nudge. Deferred because it
  needs careful integration into NutritionCarousel/SingleDishCard.
- **Backend reliability remainder** (do-now, lower priority now that the
  client watchdog protects the user): wrap `auth.getUser` /
  `checkPerUserLimit` / `checkDailyBudget` / `req.json()` in per-step
  timeouts + an overall request-deadline `Promise.race`; add a `fail_step`
  telemetry column. The single highest-value EF fix (the OpenAI body read)
  is already applied above.
- **Model strategy** (founder decision): live model is `gpt-4o` (the
  CLAUDE.md "GPT-5 + Opus + Gemini cascade" is aspirational, not shipped).
  Backend recommendation: ship gpt-4o + the new prompt now; later add a
  confidence-gated `gpt-5` second opinion behind a `FOOD_VISION_MODEL_2`
  env var (fires only on low-confidence / ambiguous-cultural scans), so the
  median scan stays fast.
- **One-line client change** the backend flagged: add `504` /
  `openai_timeout` / `DEADLINE` to the non-transient set in
  `PhotoCaptureView.isTransient` so a server timeout doesn't auto-retry.

## Simulator QA harness (DEBUG)
```
--debug-snap-camera --food-debug-autostart --food-debug-hang --food-debug-deadline 6   # hang → failure card
--debug-snap-camera --food-debug-autostart --food-debug-hang --food-debug-deadline 30  # hold scanning to screenshot
--debug-snap-camera --food-debug-autostart --food-debug-success                        # happy-path result
--debug-snap-camera --food-debug-autostart --food-debug-empty                          # no-food card
```
