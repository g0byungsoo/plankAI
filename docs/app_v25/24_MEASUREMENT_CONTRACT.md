# 24 — THE MEASUREMENT CONTRACT (frozen 2026-08-12)

**This document is a contract, not a dashboard.** It defines the few
questions release 1.2.0 (30) exists to answer, the exact PostHog
predicates that answer them, and the discipline for reading them.
A future session may ADD a dated section; it may not reinterpret,
rename, or re-derive anything below. If an analysis needs a metric
this contract doesn't define, that is a new section with founder
sign-off, not a creative read of an old one.

Why it exists: eight eras were built on data later shown to be
contaminated (TestFlight testers stamped `production` — see
`22_E8_MERGE_AND_LEDGER.md`). 1.2.0 (30) is the first build whose
events can be trusted. The next product decision comes from the first
clean cohort, and only through these definitions.

---

## §1 The trust boundary

Production behavioral data is trustworthy **iff all three hold**:

```
environment = 'production'
AND is_test_user is not set        -- PostHog "internal & test accounts" filter
AND app_version = '1.2.0 (30)'     -- or any later build
```

- `environment` / `is_test_user` are runtime-resolved per event AND
  registered as super-properties before any event can fire
  (`BuildChannel`, `bootstrapAnalytics` — audited 2026-08-12: no
  launch race; posthog-ios lifecycle events are notification-driven
  and land after `register`).
- PostHog-native events (`Application Opened`, `$screen`, …) don't
  carry `app_version`; they carry `$app_version = '1.2.0'` and
  `$app_build = '30'`. Use those keys there.
- TestFlight installs of 30 stamp `environment = 'testflight'` +
  `is_test_user = true`. Debug builds stamp `debug`. A release build
  with no receipt classifies `production` deliberately (conservative:
  never shrink the customer denominator).
- **Everything before 1.2.0 (30) is permanently mixed.** No
  reclassification is possible or permitted. Historical numbers may
  be cited only with the word "contaminated" attached.
- The boundary is a BUILD, not a date. TestFlight days before App
  Store release produce only `testflight` rows; the production series
  simply starts when Apple releases the version.

**Founder verification step (once, on the TestFlight install):** one
event in PostHog Live Events must read `environment: 'testflight'`.
If it reads `production`, STOP — the boundary is broken and every
rule below is void until fixed.

---

## §2 The clean cohort

**PAYER(30):** a person whose first `purchase_completed` satisfies §1.

All metrics below use PAYER(30) as the population unless stated.
Products with `hasCareEntitlement` (B2B clinic patients) enter no
funnel here — they never see the wall and their volume is ~0; exclude
by requiring `purchase_completed`.

Volume reality: historically ~2 purchases/day. **Expect n≈14 after
one week, n≈60 after one month.** Every rule in §4 exists because of
this.

---

## §3 The questions

Format — Q: the question. N/D: numerator / denominator.
Events: exact predicates. Supports / Falsifies: what the observation
means for the release's central hypotheses. Each carries its
minimum-n before any percentage may be spoken (§4 rule 2).

### Q1 · DAY-0 ACTIVATION
Does a new payer put one real thing on the record the day she pays?
- **D:** PAYER(30).
- **N:** those with ≥1 *meaningful record* within 24h of
  `purchase_completed`: `food_log_saved` OR `dose_marked` OR
  `weight_logged` OR `move_activity_recorded`.
- Min n: 25.
- Supports the release if the E5-era finding (essentially every
  arrival is a payer; the product's first day is the whole game)
  translates into ≥ half of payers recording day-0.
- Falsified for the release if day-0 activation is rare (<25%):
  proof-of-record isn't landing even for people who just paid, and
  the next era must attack the first hour, not week two.

### Q2 · FOOD ENTRY MIX
Which door do real users walk through? (E7's hypothesis: words.)
- **D:** all `food_log_saved` (§1 filter).
- **N:** split by `entry_method` ∈ `photo · label · words · barcode
  · again`. Report as share of D, plus per-user medians.
- Min n: 100 events.
- Supports E7 if `words + again` carry a material share (≥25%) —
  the cheap doors mattered.
- Falsifies E7's door if `words` is <5% — the field was built for a
  population that only ever wanted the camera; do not build more
  typed-first surfaces on assumption.

### Q3 · FOOD QUALITY (correction behavior)
Are estimates trusted as filed?
- **D:** `food_log_saved`. **N:** `food_scan_correction_saved`.
- **KNOWN GAP:** the correction event carries `surface` only — it
  CANNOT split by `entry_method` in this build. Overall rate only.
  Splitting requires an instrumentation addition in a future build;
  do not attempt joins through timestamps to fake it.
- Min n: 100 saves.
- High correction rate (>30%) does not falsify anything by itself —
  corrections are also engagement (the flywheel). It flags reading
  order for the vision pipeline, nothing more.

### Q4 · D1 RETURN, SPLIT BY DAY-0 FOOD
The E4 finding (day-0 food loggers return 76% vs 17%) — does it hold
in clean data?
- **Cohorts:** PAYER(30) with ≥1 `food_log_saved` within 24h of
  purchase, vs PAYER(30) without.
- **Return:** any §1 event in hour 24–48 after purchase.
- Min n: 25 per side. At ~2/day this is ≥3–4 weeks of patience.
- Supports E4/E8's whole line if the split reproduces directionally
  (loggers return at a multiple of non-loggers).
- Falsified if the split vanishes — day-0 food was a correlate of
  something else, and the evening/morning loop needs rethinking
  before extension.

### Q5 · ONE JENI
Does anyone talk to the coach once the coach knows something?
- **D:** PAYER(30). **N₁:** ≥1 `jeni_chat_message_sent` in week 1.
  **N₂ (the era's real question):** ≥1 `jeni_read_tool_called` —
  the record answered in chat.
- Min n: 25 payers.
- Supports E3 if N₂/N₁ is high (reads happen when chat happens —
  the tool loop is doing work). Falsifies the surface's PLACEMENT
  (not the mechanism) if N₁ ≈ 0: nobody opens the desk at all.

### Q6 · METHOD (JITAI)
Do notes fire, and do they move?
- **D:** `method_note_shown` (carries `trigger`).
- **N:** `method_note_action` (carries `door`); secondary
  `method_follow_up{met}`.
- Min n: 50 shown.
- Supports E8.1 if action/shown ≥ 20% on any trigger. A trigger with
  ≥50 shows and ~0 actions is dead content — retire that note, not
  the system.
- Silence is a return value: LOW `method_note_shown` volume is not
  failure; the engine refusing to speak on quiet days is designed.

### Q7 · THE EVENING LOOP (the release's central hypothesis)
Evening close → intention → morning read-back → action.
- Chain, all §1-filtered, per person per calendar day (user-local day
  is approximated by ±4h around the person's typical event hours —
  PostHog stores UTC; state this caveat on every read):
  1. `evening_close_shown` (props: `protein_met`, `has_intention`)
  2. `evening_intention_set` same evening
  3. `morning_read_shown` with `has_intention = true` next day
     (TRUE only when the read-back sentence actually rendered —
     the honest-render law)
  4. a meaningful record (Q1 set) within that next day
- Report all four counts; conversion between adjacent stages only.
- Min n: 50 closes.
- Supports the ship line if steps 2→3 survive at all (the intention
  is round-tripping) and step 4 for has_intention=true exceeds step 4
  for has_intention=false mornings.
- Falsified if `evening_intention_set` ≈ 0 — the one-tap ask is
  wrong or unseen, and the close should get quieter, not richer.

### Q8 · MOVE
Is the movement record opened, and does recording happen?
- **D:** PAYER(30). **N₁:** ≥1 `move_opened` week 1. **N₂:**
  ≥1 `move_activity_recorded` (prop `counts_as_strength`).
- HealthKit-backed row coverage is DELIBERATELY not instrumented
  (health measurements don't ride analytics). Device walk + support
  contacts are the only honest read of HK coverage. Do not proxy it.
- Min n: 25.

### Q9 · MEDICATION
Does the medicated cohort use the loop?
- **Cohort:** person property `glp1_cohort = 'on_glp1'` within
  PAYER(30).
- **N:** ≥1 `dose_marked` in week 1; secondary `side_effect_logged`.
- Min n: 15 (the cohort is a fraction of an already-small base;
  counts will be single-digit for weeks — report counts only).

### Q10 · RETENTION SHAPE
- D1 / D2 / D7 / W2 for PAYER(30), any §1 event as return.
- Always absolute counts beside percentages. A retention TABLE below
  n=25 per cell is a list of anecdotes; label it as such.

---

## §4 Reading discipline (binding)

1. **No product-era decision from this data before n ≥ 100 payers or
   6 weeks post-App-Store-release, whichever comes FIRST — and never
   from TestFlight-period data alone.** Until then the only permitted
   outputs are the counts themselves.
2. **No percentage without its denominator count printed beside it.**
   Below the per-question min-n, report counts only, no rates.
3. **No cross-metric narrative** ("food is up so method must…") —
   each question answers itself or waits.
4. **No segment fishing.** The segments are defined above. A pattern
   discovered by slicing until something moves is a hypothesis for
   the NEXT contract section, not a finding.
5. **One afternoon of production is weather.** The first read happens
   at day 14 or n=25 payers, whichever is later; before that, only
   the §1 founder verification step is a legitimate reason to open
   PostHog.
6. Historical (pre-30) numbers may inform PRIORS, never conclusions,
   and always carry the word "contaminated".

---

## §5 Known instrumentation gaps (accepted for this release)

- `food_scan_correction_saved` has no `entry_method` (Q3).
- User-local day boundaries are approximate (UTC storage).
- The evening intention's ACCEPTED state is engine-pinned but was
  never filmed; production events are the proof now (deliberate).
- HK read-grant coverage is unobservable by design (Apple privacy
  boundary) — `healthkit_requested{completed|skipped}` records the
  ASK's outcome, and nothing records the grant.
- `nutrition_*` events fire via the SDK directly (not the wrapper);
  they inherit `environment` through super-properties — equivalent
  under §1, noted for completeness.
