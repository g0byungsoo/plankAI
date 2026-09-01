# 61 — THE PRODUCT LEVEL

**feat/app-v2 · built 2026-09-01, after 60.** The founder's brief: take
Jeni one meaningful level forward — not a redesign, not a feature pile,
not an audit that ends in a document. Work the actual product until the
strongest parts stop feeling like exceptions.

Method: three parallel audits first (entry choreography · design-language
drift · the food pipeline end-to-end), category research refreshed
(Sept 2026: the MFP diary revolt + class action, Shotsy/MeAgain review
bodies, the metabolic-kitchen accuracy study), then the app WALKED on the
simulator with a scriptable driver before and after every change. Films
retained in session evidence; every claim below was either RED-proven or
frame-caught.

---

## 1. THE RECORD IS THE READING (food trust)

**The pass's gravest finding: the number she agreed to was not the number
the product kept.** `SnapResultView.displayKcal` summed the items;
`FoodLogPersister.persist` stored the model band's MIDPOINT whenever a
band existed — and `total_kcal_low/high` are REQUIRED fields of the
vision schema, so that was **every photographed plate**. The package's
own fixture demonstrates it: items 1000, band 950–1250 → screen 1000,
record 1100. The stored number feeds Home's dial, the day totals, Apple
Health, the coach envelope and the clinician packet. Every pre-existing
persist fixture passed `kcalLow: nil`, which is why five eras of tests
never saw it.

**Fix: `CapturedFood.recordedKcal` — ONE rule** (items price the plate;
the band is honesty metadata; the no-items restaurant door keeps the
midpoint; round to 5 like the reading). Persist, the hero, and the
provenance line all read it. RED 7/10 against the shipping rule. The
physics clamp now reaches the record too, and skips unknown mass (a 0g
plate was being "tidied" to 400 kcal by a bound derived from a mass it
didn't know).

## 2. THE FILED PLATE IS CORRECTABLE (the missing product capability)

"add it" was a one-way door: the persister's whole public mutation set
was persist / relog / re-date / delete, and the plate page's only remedy
was **"off? remove this plate"** — while the BOOK's a11y hint promised
"open, fix or remove it".

Built: `FoodLogPersister.repairFood(from:)` (entry → editable plate;
no-detail rows rebuild as one direct-editable item, mass never invented)
+ `updateEntry(id:with:)` (same id, same day, same door, corrections
intact, numbers re-derived by persist's own arithmetic; aggregates the
parts never carried scale with the energy edit instead of zeroing) +
**`PlateRepairSheet`** — the scan-time editor (PlateEditSession + the
ingredient editor + the share ladder) reopened on the filed entry. The
plate page holds `@State entry` and re-reads itself on save, so the
corrected numbers land where the wrong ones stood. `ItemDetail` gains
per-item fiber/sugar so future repairs re-derive. Walked on film: half →
270 kcal → the page and the day total move together. 7 round-trip tests.

## 3. WHEN SHE STATES THE NUMBER, THE NUMBER IS HERS

`StatedPlate` — a words-door sentence that declares its own energy
("protein bar, 190 cal, 20g protein") files instantly: no model round
trip, `NutritionSource.userStated`, unstated fields stay ABSENT, the
provenance line reads "your numbers, as you gave them". Category
research calls quick-add one of the indispensable small features; Jeni's
version refuses to guess what she didn't say. 12 parser tests; the
trigger is the calorie unit, so "2 eggs and toast" still goes to the
model.

## 4. THE REST OF THE FOOD TRUST SWEEP

- **A failed save no longer looks like success** — the persist catch
  DEBUG-printed and dismissed, 1.15s AFTER the success haptic. Now: the
  reading holds, a notice says so, retry is real (`food_log_save_failed`,
  categorical only).
- **Re-dating yesterday's dinner to today** was refused by its own
  preserved clock time ("9pm tonight is the future") while the caller
  fired "redated" and dismissed. A today-move clamps to now. RED 2/3.
- **A spoken rename naming only the NEW dish** ("that's actually a
  panini") kept BOTH dishes — a correction that doubled the plate.
  Replacement-shaped notes swap in place; addition-shaped notes
  ("add the fries", "forgot the yogurt") still never delete. RED 1/3.
- **The words door** gains the photo door's hard deadline (45s), a live
  X during the estimate that truly CANCELS (a cancelled estimate can
  never file late), and **offline fails in milliseconds** via
  NWPathMonitor — hardened after the unit suite caught the startup
  misfire (currentPath reads .unsatisfied before the first update; only
  a DELIVERED no-path verdict fails fast).
- **The label door** refuses label provenance when the model says it saw
  no panel (`is_nutrition_label`, decoded and dropped since 2026-08-12),
  and "copied from the label" stands down when the USDA sanity check
  overrode the printed numbers.
- **Suppressed cohorts** stop seeing calorie numerals in THE BOOK and
  the again rail (the plate page's p35 protein-words face, finally one
  grammar; `FoodModule.numericsSuppressedProvider` seam).
- **Absence prints as absence**: "0 cal" → "not counted"; the "− 0 g +"
  stepper and "0g ·" ledger segments on unrecorded portions print
  nothing; unstated macros print "—", never a zero she didn't say.
- **Analytics hygiene**: the nutrition telemetry left its direct
  PostHogSDK calls; item_name / display_name / barcode no longer travel.
  The hygiene registry gains the new events, with the law SHARPENED:
  Doubles stay refused by default (the tell for a measured body value)
  and pass per-key only for pipeline numbers; arrays pass only as
  categorical word-lists. The mechanism caught my own unregistered key
  as a DEBUG crash mid-walk — working as designed.
- Deliberately REVERSED after review: treating Open Food Facts' present
  zeros as declarations — the existing pin ("not stated never becomes a
  number") is right about community data; an import-artifact zero
  wearing label provenance would be the worse lie.

## 5. ONE INTERACTION DIRECTOR (the founder's entry complaint)

The audit mapped four auto-presenting surfaces racing one modal slot:
the evening close scheduled itself from `refresh()` (which runs on every
tab switch, plate log, sheet dismissal, foreground), collided with the
letter 200ms apart on the first evening open, and re-armed all evening;
three different settle delays (0.6/0.7/0.9); two surfaces sliding while
two hard-cut; MainShell's reauth/post-purchase invisible to Home's
`nothingPresented`; the upgrade cover landing at a network-determined
instant; a notification tapped at cold launch consumed by nobody.

**Now:** the evening close joins `HomeAutoPresent` — priority is law
(reconcile › evening close › letter › upgrade), the morning read stands
down for the whole evening (one arrival, one voice; its day-key stays
unburned for tomorrow), and the close speaks only at an ARRIVAL (appear
· foreground · midnight) — mid-session the invitation row is its door.
ONE settle beat (0.6s). ONE cover grammar (instant materialize, the
moment owns its motion — the letter's own recorded pattern, now also the
close, the upgrade, and the invitation row). `PresentationGate` makes
the shell's surfaces visible to the arbiter; the director stands down
while the launch ATT prompt is owed (`ATTService.promptIsPending`) and
re-runs when RootView posts `.attPromptSettled`. The upgrade's offerings
fetch is bounded (>5s stands down; eligibility survives). Home consumes
a cold-launch `pendingRoute` on appear (Becoming's own E4 consumer,
finally mirrored). Arbiter tests 8/8 with the collision pinned as law.

**The arrival cascade steps once per block** (the dose row duplicated
the strip's index; the day-one card, chain row sat outside the cascade
and the card hard-appeared when its async OS gate flipped — animated
now, indices 0…6). **The hydrate announces itself** —
`.appSyncDidHydrate` posts once per completed `hydrateAndSync`, so Home
recomposes when the record lands instead of sitting on pre-hydrate
numbers for the measured 35s window. **The atmosphere rests** — 20fps
(drift speed unchanged), paused under covers (two 30Hz shader loops used
to run behind every cover). The evening cover gains the kit's trap guard
(nil-snapshot self-dismisses).

## 6. THE OLD PARTS LEAVE (design-language convergence)

The drift audit measured five eras resident in the tree. Acted on:

- **~2,900 lines of PROVEN dead code deleted** from the shipping
  target: JKSignalVisuals.swift (1,361L, all 15 types), StepsBentoTile,
  ChapterCompleteView, JKArcRibbon, EditorialEmptyState, MagicalLoading,
  BodyVisionIntroView, RoastCardView, 17/23 types in Components.swift,
  PlankShadow/LuxuryCardChrome (zero callers), SettingsSelectRow,
  EveningJournalLine, JKCitationChip, JKRhythmRow, six
  OnboardingComponents types, three Handwritten renderer roots. Every
  symbol `git grep -w`-proven to zero non-comment references first.
- **One material**: both scrapbook chromes now render the §6.1 surface
  (opaque paper · 0.5pt hairline · contact shadow). Every surviving call
  site was the pre-paywall reveal chain — the last screen before the
  wall now wears the same material as the app she's buying, and the rose
  curve is the card's only rose. Filmed before/after
  (--debug-projection).
- **One geometry**: FoodTheme.screenPadding 20→16, Radius.card 24→22 —
  the food rail sat at a different gutter and radius than the whole app,
  the diffuse "this section feels different". Radius pin updated with
  reasoning.
- **One type system**: SF Rounded (camera zoom pill) and New York
  (visit-packet headline) leave; the reveal's and device demo's raw
  `.system` copy joins DMSans at identical sizes; the two surviving
  hard-offset "sticker" shadows become the soft contact shadow; the
  settings pearl's baby blue (the only off-hue on a live surface)
  becomes a lilac rose.
- The package's two inner sheets gain the always-visible grabber (the
  p57 law, kept by hand where jeniSheet can't reach).

## 7. VERIFIED

- **plankAITests: 1581 · 2 skipped · 0 failed** (p60's 1577 + 4 new
  arbiter = exact) — plus the hygiene suite re-run 13/13 after the
  sharpening.
- **PlankFood: 288/288** (253 baseline + 10 energy + 3 re-date + 12
  stated + 7 repair + 3 hygiene-adjacent edits reconciled; every RED
  proven before GREEN where a stub could fail honestly).
- **PlankSync: 29/29.** **Release BUILD SUCCEEDED.**
- Walked on film (QA sim + SE at standard size + the AX-sized SE):
  Home entry, the letter, THE BOOK, the plate page, the repair loop
  (half → 270 → every consumer moves), the stated plate (type → instant
  reading → filed answer sentence), scan slow/timeout/empty states, the
  reveal before/after.

## 8. NAMED, NOT DONE (for the next session)

- The reveal chain's deeper §7 spacing/motion pass (the chrome and
  typography converged; 48 magic spacings remain) — conversion surface,
  film-first.
- `PresentationGrammarTests` still stops at the package boundary (the
  three package presenters now carry grabbers by hand; extending the
  sweep needs a package-side marker convention).
- Two-device food sync is still push-only (`hydrateFoodLogs` only runs
  when a family is empty); offline edits still lack a retry queue —
  both pre-existing, both documented in the pipeline audit.
- The book's swipe actions / undo-on-relog; the `16pt` radius orphan
  (33 uses, no token); RegimenSheet's 55 magic spacings.
- Research flags worth founder thought: a maintenance/off-ramp era
  (two-thirds regain; only Shotsy has one), cycle-aware energy
  interpretation (MacroFactor's loudest women-specific complaint;
  CycleService already wired), the clinician/insurance export framing.

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.**
