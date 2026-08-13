# E9 — THE COHERENCE PASS: the record

**Status: IN PROGRESS (2026-08-12).** A product + design sweep, not a
feature era. The mandate: make the product that eight eras built feel
like ONE designer made it — more coherent, more useful, more premium,
faster to understand — without adding a pile of features and without
redesigning what is already excellent.

The build 1.2.0 (30) is in App Store review. Nothing in this pass
touches the paywall, pricing, entitlements, `AppPhase`, auth,
migrations, or the analytics vocabulary frozen in
`24_MEASUREMENT_CONTRACT.md`.

---

## 1 · THE THESIS (written before any code)

Formed from: STATE.md §0.-13 … §0.-15, the design law, the E8.1
Method record, two commissioned research reviews (behavioral
intervention evidence; hydration evidence), 62 MeAgain reference
frames, and a walk of the running app with 17 captured surfaces.

### What the walk actually found

The product is in much better shape than a "redesign everything"
brief assumes. Onboarding, the morning letter, the evening close, the
dose sheet, Becoming and the Method note are all at or near the bar.
The incoherence is concentrated, and it has ONE shape:

> **Nutrition is the only domain in the app that never became an
> instrument.** Every other domain has a shape — weight has a
> trajectory, movement has a count against a guidance figure, the day
> has a checklist, the week has marks. Nutrition has ONE ring (protein,
> on Home) and everywhere else it is *rows of equal-weight numbers*.

That single defect produces most of what reads as "dashboard", "dense
without hierarchy" and "spreadsheet" in this product:

1. **`PlateDetailSheet` leads with CALORIES.** The product's own law
   (`00_THE_SYSTEM` §9 — "protein floor + fiber lead; kcal quiet") was
   fixed in the post-scan reading by E7 and on Home by E8. **The plate
   sheet was missed by both**, and it is the most reachable food detail
   in the app (Home's food row, the book, the plate chips all land
   here). E6 recorded that "the three food entrances ALREADY converge
   on one reading" — **that was wrong**. There is a fourth reading, and
   it is the oldest one.
2. **Five macros rendered as five identical rows.** Protein, carbs,
   fat, fiber, sugar at the same size, same weight, same colour, each
   on its own hairline. Nothing is loud, so nothing is legible at a
   glance. The plate sheet also drops the vitamins and minerals E7
   spent an era carrying through the pipeline.
3. **Home's food band spends ~750pt to say ~280pt of things.** The
   hero carousel's five faces are mutually redundant: `calories`
   duplicates the strip's kcal cell, `plate` duplicates carbs+fat,
   `chemistry` duplicates fiber/sugar/sodium, `week` duplicates
   Becoming's week scope. Only `protein` says something the others
   cannot — which is why E8 made it lead and why the other four are a
   swipe nobody takes.

### The principle chosen for this pass

> **Two nutrients earn a shape. Everything else earns a place.**

Protein leads with a ring because it is the one food number with a
collected, personal floor and the one the evidence says protects lean
mass. The day's energy gets exactly one shape — the split — because
the macros are ONE relationship, not three metrics (v18.1's law,
applied to food). Fiber, sugar and sodium keep their numbers and lose
their volume. Micronutrients appear only where they exist and never
compete.

This is the same law the design language already states; the pass
applies it to the one domain that never received it.

---

*(record continues — filled in as the pass proceeds)*
