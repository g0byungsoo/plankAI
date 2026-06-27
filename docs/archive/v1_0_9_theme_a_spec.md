# v1.0.9 Theme A — food rail deepening + calorie robustness

Status: spec · 2026-06-08
Founder direction: "let's do A first. and i want to make the calorie
tracking experience more robust."

## What "robust" means here

The v1.0.8 carousel had three soft spots that read as "an estimate
disguised as a number":

1. **Micronutrient labels claim data we don't have.** Slide 2's
   "Vitamins 82%" / "Minerals 79%" / "Amino acids 72%" rows derive
   from fiber + protein proxies. Cohort knows. Trust leak.

2. **Tweaking is whole-plate-only.** A 3-item scan ("salad +
   chicken + dressing") lets the user scale the whole plate or
   rename the first item — but not delete the dressing, swap the
   chicken for tuna, or fix the salad's portion alone.

3. **Confidence is invisible.** The EF returns `kcal_low` +
   `kcal_high` already, but the UI shows only the midpoint. A range
   of 280-420 reads the same as 340-360.

Theme A addresses 1 (real micronutrients) and bleeds into 2 + 3 as
the supporting robustness improvements.

## Scope

### A1 — USDA full nutrient panel

Extend `USDAClient` to fetch the cohort-relevant 10-nutrient set
beyond the current 8 (kcal/protein/carbs/fat/fiber/sugar/sodium/
sat-fat):

  - Vitamins: A, C, D, E, B12
  - Minerals: Calcium, Iron, Magnesium, Potassium, Zinc

Plus `NutritionDensity` struct + `NutritionLookupResult` carry them.
Per-100g values, mapped from USDA nutrient IDs:

  | Nutrient    | ID   | Unit |
  | Vitamin A   | 1106 | µg RAE |
  | Vitamin C   | 1162 | mg |
  | Vitamin D   | 1114 | µg |
  | Vitamin E   | 1109 | mg |
  | Vitamin B12 | 1178 | µg |
  | Calcium     | 1087 | mg |
  | Iron        | 1089 | mg |
  | Magnesium   | 1090 | mg |
  | Potassium   | 1092 | mg |
  | Zinc        | 1095 | mg |

Why only 10: covers the daily-reference-intake panel most cohort
women actually search for. More nutrients = bigger schema migration
+ longer USDA-side parse time without proportional cohort benefit.

### A2 — CapturedItem field additions

Extend `CapturedItem` with the same 10 optionals + the existing
sugar/sodium/saturatedFat (which were already there). Backwards-
compat: all-nil for items that didn't hit USDA.

### A3 — Per-item NutritionLookup wiring

After the EF returns CapturedFood, the iOS NutritionLookupService
walks each item and:
  - Queries `canonical_pantry` (cache hit → done)
  - Falls back to USDA FDC
  - Writes the result back to `canonical_pantry` (corrections-as-moat)

For the carousel to feel snappy, this runs on a background task and
slide 2 reactively updates as nutrients arrive. Slide 1's macros
stay LLM-direct (already there); only the new micronutrient row
data comes from USDA.

### A4 — FoodLogPersister.Entry macro+micro extension

Extend the v1.0.8 Entry struct with the 10 micronutrient values so
"today's totals" on slide 2 can sum real micronutrients across
multiple meals. Backwards-compat decoder defaults missing fields
to 0.

### A5 — NutrientsBreakdownCard wiring

Rewire from heuristic proxies → real intake-vs-DRI ratios:

  - All nutrients = avg of all 5 vitamin + 5 mineral % targets
  - Vitamins    = avg of (A, C, D, E, B12) % targets
  - Minerals    = avg of (Ca, Fe, Mg, K, Zn) % targets
  - Amino acids = stays protein % (we don't have per-aa data)
  - Other       = fat-soluble vitamin % (avg of A, D, E)

Daily reference intakes (DRI):
  Vit A 700 µg, Vit C 75 mg, Vit D 15 µg, Vit E 15 mg, B12 2.4 µg
  Ca 1000 mg, Fe 18 mg, Mg 320 mg, K 4700 mg, Zn 8 mg

(Women 19-50, USDA RDA standard. Different number for pregnancy /
lactation but those aren't the cohort default.)

### B1 — Per-item edit affordance (robustness)

Replace the "tweak this" sheet's flat options with a per-item list:

```
your plate:
  ▸ greek yogurt  ·  150g  ·  150 kcal  · [edit ▾]
  ▸ pineapple     ·  100g  ·  50 kcal   · [edit ▾]
  ▸ granola       ·  30g   ·  130 kcal  · [edit ▾]

  + add an item
```

Tap [edit ▾] opens a per-item editor:
  - smaller portion (×0.75)
  - bigger portion (×1.25)
  - change name (renames this item only)
  - remove (deletes this item from the plate)

Add an item lets user manually type a name + portion that hits
USDA → joins macros automatically.

This replaces "tweak this" entirely. The whole-plate ×0.75/×1.25
is rarely the right answer when the LLM nailed 2 of 3 items.

### B2 — Confidence bar (robustness)

The kcal column on slide 1 shows the midpoint with a thin range
underneath:

  ```
  ───────────────────
  265 kcal
  240 ─────●───── 290
  ```

Subtle. Lets the user see if it's a ±10kcal confident estimate or
a ±50kcal "I'm not sure" guess.

### B3 — Manual entry fallback (robustness)

A "type it instead" link on the empty-scan / no-food error state:

  ```
  no food in that one ♥
  → try a closer angle
  → or type it instead
  ```

Tapping it opens a sheet with name + macros + portion fields.
Persists like any other log.

## Out of scope for Theme A

- Amino acid panel (USDA tracks individual AAs but cohort relevance
  is low; protein % is good enough)
- Branded foods (Starbucks / Chipotle menu data) → v1.0.10 candidate
- Barcode scanning → v1.0.10 candidate
- Voice input → v1.1 candidate

## Commit roadmap

1. USDAClient nutrient panel expansion (A1)
2. NutritionDensity + NutritionLookupResult schema (A1)
3. CapturedItem field additions (A2)
4. NutritionLookupService background-fetch wiring (A3)
5. FoodLogPersister.Entry schema migration (A4)
6. NutrientsBreakdownCard real-data wiring (A5)
7. TweakSheet → per-item edit list (B1)
8. Confidence bar on slide 1's kcal column (B2)
9. Manual entry fallback on no-food error (B3)

Each step builds + ships independently. Steps 1-6 are Theme A core.
Steps 7-9 are the robustness layer.

## Estimated effort

3-5 days. Most of the work is in the schema migrations + propagating
optionals through the data layer. UI changes are surgical.
