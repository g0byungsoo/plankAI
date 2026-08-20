# THE APP I WOULD TRUST WITH 30 DAYS OF MY LIFE

**Status: BUILT 2026-08-14.** Not an era, not a redesign. The audit the
brief asks for, then the smallest set of changes the audit earns.

The standard, taken verbatim from the brief:

> Delete every sentence containing AI · INSIGHT · PATTERN · COACH ·
> JOURNEY · TRANSFORMATION. **Is the rest worth keeping for 30 days?**

`34` asked whether the boring half is *complete*. This pass asked
whether it is complete **over time, for two people, on the days they
get it wrong.**

Nothing in the frozen candidate moved. No change to the calorie
formula, the protein formula, the merge contract, plan selection, the
restore path, the safety rules, payment, paywall, auth, `AppPhase`,
`Info.plist`, entitlements, migrations, the analytics contract, or any
HealthKit type. No migration written. No Edge Function deployed. No
production SQL executed. No production data read or mutated.
`CURRENT_PROJECT_VERSION` untouched.

---

## 0 · THE ANSWER FIRST

**Yes — and the audit found that every remaining weakness worth fixing
was in the same place, for the same reason, and only two of them could
be fixed without a founder gate.**

`34`'s scorecard has five domains below 8. Four of them are blocked on
something this session is forbidden to do:

| domain | `34` score | what blocks it |
|---|---|---|
| NUTRITION ACCURACY | 7 | the four FDA label micros are **written into the EF and not deployed** — founder gate |
| SYNC / RESTORE | 7 | Jeni memory / chat / manual move need **a migration first** — founder gate |
| JENI INTEGRATION | 7 | `open_food_book` + a goal act are **new tool NAMES → an EF deploy** — founder gate |
| **EDITABILITY** | **7** | **a past dose log and a past side effect cannot be corrected** |
| **GLP-1 UTILITY** | **7** | **the same two records** |

**The last two are the same defect, they need no schema, no deploy and
no migration, and the machinery for both already exists.** So the
implementation budget was decided by the audit rather than by
preference, and it is spent entirely on them.

The defect is `34`'s own finding, one domain further on:

> **JENI WAS A WRITE-ONLY RECORD IN THE PAST TENSE.**

`34` closed that for FOOD and WEIGHT — the two records every user has.
It named the other two and deferred them as "a clinical-record write
path". **They are the two records a GLP-1 payer is most likely to get
wrong in a busy week, and they were the last two write-only-in-the-past
records in the product.**

And the audit found one thing neither previous pass did, which is not a
gap but a **contradiction**:

> **Settings → "my pace" does not edit her pace.**

---

## 1 · THE CAPABILITY INVENTORY

Traced to real call sites. Nothing here is inferred from a file name;
where a previous record was wrong, the correction is marked **[CORR]**.

Legend — E: editable · D: deletable · B: backdateable · S: synced ·
R: restored on a new phone · JR: Jeni can read · JA: Jeni can act.

### FOOD

| capability | where it lives | input | source of truth | E | D | B | S | R | JR | JA | verdict |
|---|---|---|---|---|---|---|---|---|---|---|---|
| photo | scan chooser → capture | image | `FoodLogPersister` | ✓ | ✓ | ✓ 14d | ✓ | ✓ | ✓ | ✓ open | KEEP |
| words (front door) | scan chooser field | sentence | same | ✓ | ✓ | ✓ 14d | ✓ | ✓ | ✓ | ✓ `log_food_text` | KEEP |
| label photo | capture mode | image | same | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP (EF gate) |
| barcode | capture mode | code | same + OFF | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP |
| manual / quick add | chooser | numbers | same | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP |
| repeat / relog | again rail | tap | same | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP |
| kcal · protein · carbs · fat | every food surface | derived | one persister | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP |
| fiber · sugar · sodium | Home band · plate | derived | same | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP |
| portion / servings | plate `PlateShare` | stepper | same | ✓ | — | — | ✓ | ✓ | ✓ | — | KEEP |
| meal history | THE BOOK (becoming › your plates) | — | same | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — | KEEP |
| **the day a plate fed** | plate page → `the day` | 14-day picker | `logged_at` | ✓ | — | ✓ | ✓ | ✓ | ✓ | — | KEEP (`34`) |
| meal labels | — | — | — | ✗ | — | — | — | — | — | — | DEFER (schema) |

### BODY / WEIGHT

| capability | where | E | D | B | S | R | JR | JA | verdict |
|---|---|---|---|---|---|---|---|---|---|
| current weight | Home · your numbers · ledger top row | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ `log_weight` | KEEP |
| start weight | plan screen | ✗ by design | ✗ | — | ✓ | ✓ | ✓ | — | KEEP |
| goal weight | Settings › goal weight · your numbers · plan | ✓ | — | — | ✓ | ✓ | ✓ | ✗ no act | KEEP |
| weigh-in list | becoming › your record › `your weigh-ins` | ✓ | ✓ | ✓ any day | ✓ | ✓ | ✓ | — | KEEP (`34`) |
| trend (EMA) | Becoming | — | — | — | ✓ | ✓ | ✓ | — | KEEP |
| units lb/kg | your numbers · weigh-in toggle | ✓ | — | — | device | device | ~ | — | KEEP |
| height | your numbers | ✓ | — | — | ✓ | ✓ | ✓ | — | KEEP |
| body scan | becoming › new check-in | ✓ | ✓ | — | **opt-in** | **✗ default** | ✓ | — | KEEP, **locality unstated** |

### PROGRAM

Every one of the twelve values is visible; the six energy inputs are all
editable in one sheet (`31` §7). `calorie target · protein target · step
target · pace · goal date · day/week · maintenance · safety hold ·
program start · progress` — all KEEP, all pinned by
`OneTargetEverywhereTests` (25 states) and `CalorieGoldenMatrixTests`
(11 fixtures).

**[CORR] `EditProfileView` is NOT unreachable.** `33` and `34` both list
it under REMOVE / "content I would delete", described as "superseded by
both `my pace` and `your numbers`". It is reached at
`ProfileHubView.swift:447` — **it IS `my pace`.** §9 below.

### GLP-1

| capability | where | E | D | B | S | R | JR | JA | verdict |
|---|---|---|---|---|---|---|---|---|---|
| regimen + version chains | regimen home (4 doors) | ✓ | — | chain | ✓ | ✓ | ✓ | — | KEEP |
| dose day / next dose | Home standing row | ✓ | — | — | ✓ | ✓ | ✓ | ✓ open | KEEP |
| mark a dose | dose sheet | today + open late slot | same | ~ | ✓ | ✓ | ✓ | ✓ | KEEP |
| injection site | at mark time | ✓ then | — | — | ✓ | ✓ | ✓ | — | KEEP |
| **dose history (`the doses`)** | regimen home | **✗ read-only** | **✗** | **✗** | ✓ | ✓ | ✓ | — | **FIX** |
| **side effects** | regimen home · dose sheet | **today only** | **today only** | **✗** | **~ see §12** | ✓ | ✓ | — | **FIX** |
| **side-effect history** | **nowhere** | — | — | — | ✓ | ✓ | ✓ | — | **FIX** |
| reminders | Settings › reminders | ✓ | — | — | ✓ | ✓ | — | ✓ hour | KEEP |
| clinician export | becoming › visit packet | ✓ | — | — | ✓ | ✓ | ✓ | — | KEEP |
| medication-level curve | — | — | — | — | — | — | — | — | REFUSED ×5 |

### GENERAL / JENI

Steps (HealthKit, measured-or-absent) · breathwork · workouts (legacy,
retirement trigger) · notifications · Settings · account · HealthKit ·
sign-out/in · reinstall — all traced, all KEEP except the workout
library (DEFER).

Jeni: **8 read tools · 12 acts**, envelope resolving through
`PlanSummary`. **Supplements: there is no feature.**
`RegimenService.supplementPlans` has zero call sites — re-verified.

---

## 2 · THE 30-DAY WALK

Two people, thirty days, audited as TIME rather than as screens.

### PERSON A — 5'3" · 124 lb · goal 110 · 34 · female · medium · no GLP-1

| day | what she does | result |
|---|---|---|
| 0 | onboarding | 31 beats; safety gate; plan built |
| 1 | 3 meals + weight | words door ×3; `JKWeightRitual` |
| 2 | repeat · barcode · photo | again rail (2 taps) · live VN · capture |
| 3 | mistyped food → correct | plate → fix with words |
| 4 | forgot yesterday's dinner | **log it now, then `the day` → yesterday** (2 steps) |
| 5 | mistyped weight → correct | `your weigh-ins` → tap the row → ruler |
| 6 | two weigh-ins same day | both listed; each states its **time** (the day word must identify exactly one row) |
| 7 | weekly review | one offer, cooldown-gated |
| 8 | sign out → sign in | target moves **35 kcal** (the age band), stated `about 29 · approximate` |
| 10 | change goal | `JKGoalRitual`; plan mutated in place, day count intact |
| 12 | lb → kg | your numbers; device-level |
| 14 | review two weeks of food | THE BOOK, day ledger first |
| 15 | new phone | everything server-backed returns; **memory, chat, manual move do not** |
| 18 | weight increases | stated in the same words and type as a loss; no red |
| 20 | maintenance edge | `· holding`, **no remainder** (an estimate is not a budget) |
| 21 | weekly review | — |
| 25 | asks Jeni ×6 | 5 of 6 answered; **"change my goal" has no act** (EF gate) |
| 30 | reconstruct the month | **YES** — every question below answers |

*What did I eat · how much · how much protein · what was my target ·
what did I weigh · when did I gain · when did I lose · what is my goal ·
how far am I · did my plan change · why* — **all eleven answer.**

**Person A's month has no unanswerable question.** The two rough edges
are both known and both stated on screen: the 35 kcal age drift, and
"log it now, then say when" being two steps rather than one.

### PERSON B — same body, GLP-1, weekly, a dose change mid-month, several symptoms

Everything above, plus:

| day | what she does | result |
|---|---|---|
| 1 | marks the shot | site pre-picked, last site + reason stated |
| 2 | logs nausea | ✓ — **because it is the same day** |
| 4 | **remembers Tuesday's nausea** | **✗ NOWHERE TO PUT IT** |
| 9 | marked the shot on the wrong site | **✗ NO REPAIR** |
| 11 | marked a dose she didn't take | **✗ NO REPAIR** (the open-slot unmark has closed) |
| 15 | dose 0.5 → 1.0 mg | version chain; old era still true about its weeks |
| 16 | "what side effects have I had?" | **✗ NO LIST** — chips show today only |
| 22 | clears a symptom she logged wrong | local only — **the server row stands** (§12) |
| 28 | visit packet | correct **except** for symptoms she thought she had cleared |
| 30 | reconstruct the month | **PARTLY** |

*When was my shot · what dose · where did I inject · did I skip* —
answered by `the doses`. *What side effects did I record* — **only via
the clinician PDF or Becoming's chart; there is no list.** *Can I correct
a wrong historical entry* — **no, for both records.**

**That is the whole finding.** Person A's month is repairable. Person
B's month is repairable for food and weight and **frozen for medication**
— the domain she is paying the premium for.

---

## 3 · THE BORING TOOL GAUNTLET

C · R · U · D · H(istory) · S(ync) · R(estore). `~` = partial.

| record | C | R | U | D | H | S | R | the hole |
|---|---|---|---|---|---|---|---|---|
| FOOD | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| WEIGHT | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | — |
| GOAL | ✓ | ✓ | ✓ | n/a | ✗ | ✓ | ✓ | no goal history (deliberate — the plan is the record) |
| DOSE | ✓ | ✓ | **✗** | **✗** | ✓ | ✓ | ✓ | **past rows read-only** |
| SIDE EFFECT | **today** | **today** | **today** | **today** | **✗** | **~** | ✓ | **the worst row in the product** |
| BODY SCAN | ✓ | ✓ | — | ✓ | ✓ | **opt-in** | **✗ default** | locality unstated |

**Deliberate refusals, stated:** start weight is not user-editable (every
"since you started" sentence is measured from it; server-repairable, and
`31` proved the repair lands). History families other than these are
insert-only by rule.

**A beautiful write-only feature is broken.** SIDE EFFECT failed five of
seven columns. DOSE failed two. Everything else passes.

---

## 4 · NUTRITION — ONE PLATE, ONE SET OF NUMBERS

Traced end to end: capture → recognition → editable result →
`FoodLogPersister.persist` → day ledger → Home totals → Becoming → Jeni.

**Six doors, one chokepoint, one accumulator.** Re-verified this
session: every reader in the app goes through `FoodLogPersister`. There
is no second sum. The two unscoped legacy readers still have exactly one
call site between them, and it is a `userId.isEmpty` preview fallback.

Against the brief's Lose It test — photograph ✓ · describe ✓ · barcode ✓
· manual ✓ · repeat ✓ · edit quantity ✓ · edit calories ✓ · edit macros ✓
· **change its day ✓** · delete ✓ · find yesterday ✓ · today's total ✓ ·
**what's left ✓** · protein remaining ✓ · nutrient totals ✓ · inspect a
day ✓ · inspect a week ✓. **Seventeen of seventeen.**

Taps from Home to a saved meal: **2** (scan tab → sentence + return).
Lose It's cheapest is 3 (Recent → pick → save); its search path is 5+.

Not changed. Not needed.

---

## 5 · WEIGHT — ONE LADDER

onboarding → first weight → weigh-in → latest → calorie target →
protein target → progress → goal distance → Becoming → Jeni → sync →
restore.

One resolver (`TargetsService.resolvedWeightKg`), one writer
(`WeightLogWriter`), one list (`your weigh-ins`). Loss · gain · same ·
two same-day · delete latest · delete older · edit latest · edit older ·
HealthKit · manual · lb · kg · new phone · sign-out/in — **all fourteen
pinned** by `RecordRepairTests` (25) and the golden matrix.

No chart is a source of truth; no latest-value cache exists to disagree
with the ledger. Not changed. Not needed.

---

## 6 · JENI AS AN INTERFACE — THE CLOSED MATRIX

| capability | READ | EXPLAIN | NAVIGATE | CHANGE |
|---|---|---|---|---|
| food today / a day / a week | ✓ | ✓ | ✗ | ✓ `log_food_text` |
| the food record (THE BOOK) | ✓ | ✓ | **✗ named not opened** | — |
| calories left | ✓ computed once | ✓ | — | — |
| protein left | ✓ | ✓ | — | — |
| the calorie target | ✓ | **✓ `targets.inputs`** | ✓ `doors.your_numbers` | via its inputs |
| weight / trend | ✓ | ✓ | ✓ `show_weight_trend` | ✓ `log_weight` |
| a past weigh-in | ✓ | ✓ | ✗ | **✗ no act** |
| goal weight | ✓ | ✓ | ✓ `doors.goal_weight` | **✗ no act** |
| program facts | ✓ | ✓ | ✓ | ✓ `propose_program_fact` |
| dose history | ✓ `read_dose_history` | ✓ | ✓ `open_dose_sheet` | ✗ |
| symptoms | ✓ `read_symptoms` | ✓ | ✗ | ✗ (deliberate) |
| the weekly read | ✓ | ✓ | ✓ | ✓ |

**Jeni never disagrees with a screen.** The envelope resolves through
`PlanSummary` — the same object the screens are made of — so
Home == Plan == Jeni is structural, pinned across 25 states × 3 surfaces.
`35` fixed the last divergence (the coach's own weight ladder).

**Every ✗ in the CHANGE and NAVIGATE columns is a new tool NAME, and a
new tool name is an Edge Function deploy.** The allowlist gates names,
not payloads. Named, not smuggled — and the reason JENI INTEGRATION
cannot move this session.

---

## 7 · GLP-1 AS A MODE

**Verified again on the running app: a non-GLP-1 account's Home has zero
medication pixels.** `doseStandingRow` is nil by construction without a
scheduled regimen; the only medication surfaces are two quiet Settings
rows that announce nothing. A GLP-1 account gets the rhythm as Home's
first line and a full-page regimen home. The split was right and is
untouched.

| job | Jeni | MeAgain | Shotsy | winner | copy the job? | copy the interaction? | decision |
|---|---|---|---|---|---|---|---|
| shot schedule / next / last | ✓ | ✓ ring + countdown | ✓ ring | level | — | no | keep |
| dose + dose changes | **version chains** | overwrite | overwrite | **JENI** | — | — | keep |
| **dose history list** | ✓ since `33` | "Show All Dose Logs" | Shots tab | level | — | — | keep |
| **correct a past shot** | **✗** | ✓ | ✓ *(widget: "tap to edit shot details")* | **THEM** | **YES** | **YES** | **BUILD** |
| injection site + rotation | ✓ states the reason | ✓ body map | ✓ | **JENI** | — | no | keep |
| side effects | 14 chips × 3, incl. 4 under-reported | 6 sliders 0–10 | onboarding only | **JENI** | — | no | keep |
| **side effect on a past day** | **✗** | **✓ a `Date` row on the log screen** | ✗ | **MEAGAIN** | **YES** | **YES** | **BUILD** |
| **side-effect history list** | **✗** | ✓ | ✗ | **MEAGAIN** | **YES** | adapt | **BUILD** |
| weight × dose relationship | floor-gated, timing-never-causality | ✓ | ✓ chart annotated by dose era | level | — | no | keep |
| medication-level curve | **refused ×5** | ✓ | ✓ | — | **NO** | no | refuse |
| brand names in the product | never in notifs/analytics | **names Ozempic®** | names brands | **JENI** | no | no | keep |
| clinician export | **VisitPacket PDF** | ✗ | ✗ | **JENI** | — | — | keep |
| protein / fiber / water | protein + fiber, water refused ×4 | trio | ✗ | deliberate | no | no | refuse |
| a global "+" reaching every record | ✗ | **✓ FOOD/LOG groups** | ✗ | MeAgain | **no** | no | IA change to a protected anchor |
| mascot · streak flame · "3× more effective" | ✗ | ✓ | ✓ | **JENI** | no | no | refuse |

**The convergent finding, and it decided the build:** *both* GLP-1
references put an **editable date on the logging screen itself** —
MeAgain for food **and** side effects, Shotsy by promoting "tap to edit
shot details" all the way to its home-screen widget. It is the single
interaction Jeni was missing in this domain, and Jeni already ships the
same idea for plates (`the day`, 14 days, expand in place).

---

## 8 · JENI METHOD — ZERO SACRED COPY

Three systems carry the name. Re-verified by grep, not inherited.

| piece | reachable? | what decision does it help her make | verdict |
|---|---|---|---|
| `MethodEngine` + `MethodCatalog` — 15 rule-based notes | ✓ Home tile + lesson beat | each carries a **required action** and a quiet condition; **silence is a return value** | **KEEP — this is the Jeni Method** |
| `MethodLedger` / `MethodToldView` | ✓ Settings | stops Jeni re-teaching | KEEP |
| 14-lesson `LessonID` corpus (`JeniMethodReReadView`) | **✗ zero navigating rows** — the `case .jeniMethod` at `ProfileHubView:454` has no row that reaches it (re-verified) | none | **DELETE** |
| 84-day CBT manifest + `LessonReaderView` | **✗** — only production reader is `RepEngine`, **zero call sites** (re-verified); still parsed on every launch | none | **DELETE** |
| `RepEngine` | **✗ zero call sites** | none | **DELETE** |

**Wellness filler: still zero reachable.** Re-swept this session for the
brief's archetypes — "part of your journey", "best version of yourself",
"listen to your body", "small choices add up", "you've got this",
"crushing it". **Zero files.** `"amazing"` survives only inside
`PlateAnswerEngine`'s **banned-word list** and in a DEBUG-only legacy
screen. Four prior sessions removed that register and it has not grown
back.

**Not deleted here.** All three are inert with zero production call
sites, so none is costing a customer anything today, and `32` §12's rule
stands. They are a cleanup pass with its own build; the evidence is now
written down twice.

---

## 9 · DESIGN CONSISTENCY — AND THE WORST SCREEN LEFT

Anchors (onboarding · Home · Becoming · camera) **not touched.**

Mechanical sweep re-run: **zero** `Form`, **zero** `List`, **zero**
`navigationTitle` outside the anchors' own grammar.

### The sheet / detent inventory

Every `presentationDetents` in the repo, classified:

| presentation | count | class | verdict |
|---|---|---|---|
| `.large` | 20 | DESTINATION | correct |
| `JeniSheetHeight.tall` = `[.fraction(0.68), .large]` | 12 | body-of-content, **draggable to full** | correct |
| `JeniSheetHeight.tallFixed` = `[0.68]` | 2 | camera/canvas underneath needs its room | correct |
| `JeniSheetHeight.brief` = `[0.42]` | 1 (MoveSheet) | one question | correct |
| `[.fraction(0.45)]` | 1 (`RoutineSessionSheets`) | one question | correct |
| `[.medium]` | 1 (`TerminalErrorSheet`) | one error + dismiss | correct |
| `[.fraction(0.66)]` | 1 (food capture) | camera underneath | correct |
| `[.fraction(0.55), .large]` | 1 (`PlankAIApp` preview route) | **DEBUG only** | n/a |
| `fullScreenCover` | `your weigh-ins`, evening close | DESTINATION | correct |

**No content-heavy screen opens at half height.** `33` promoted the one
real offender (regimen home 0.68 → `.large`) and `34` put `your
weigh-ins` on a `fullScreenCover` by construction. Nothing was
mechanically converted this session and nothing needed to be.

### THE WORST DESIGN-INCONSISTENT SCREEN LEFT — and it is a contradiction, not a style

**Settings → "my pace" does not edit her pace.**

Traced: `ProfileHubView.swift:351` renders a row titled **`my pace`** →
`go(.myPace)` → `:447` → **`EditProfileView`**, a v4-era screen titled
*"your pace"* whose only control is `@AppStorage("workoutLevel")` — a
**device-local, unsynced workout-difficulty preference** that
`RoutineSessionView` also nudges on its own after a session.

Her actual pace tier — the value that decides her deficit and her
horizon — is edited two rows above, inside **`your numbers` → pace**,
built by `31` §4 *specifically because the onramp prints "pick the
rhythm, you can change it later"* and nothing could.

So the customer who wants the thing the onramp promised taps the row
named for it, lands on a screen titled for it, picks an option, and
**her calorie target and goal date do not move.**

It is worse than a wrong destination, because the two screens **share
two of three words for two unrelated concepts**:

| `EditProfileView` (workout difficulty) | `your numbers` → pace (the deficit) |
|---|---|
| keep it gentle | **gentle** |
| **steady** | **steady** |
| a little more | strong |

**[CORR]** `33` §"THE TEN ANSWERS" 4 and `34` "CONTENT I WOULD DELETE" 4
both call `EditProfileView` dead and "superseded by both `my pace` and
`your numbers`". It is not dead. **It is `my pace`.** Two sessions
reasoned about a screen from its name.

### The other vocabulary split — pace, four ways

Re-verified. The same three stored values (`soft`/`medium`/`hard`) are
shown as:

| surface | words | when |
|---|---|---|
| storage (`intensityTier`, `onboardingPickedTier`) | `soft · medium · hard` | never rendered |
| consult reveal (`ProjectionMath`) | `gentle · steady · focused` | **pre-purchase funnel** |
| `ProgramSetupSubflow` (`IntensityTier.label`) | `soft · medium · hard` | **post-purchase** |
| Home · `your numbers` · pace editor · chat | `gentle · steady · strong` | **post-purchase** |

P2 since `32` ("a release candidate is not a naming pass"). **This pass
is explicitly a semantic-entropy pass**, and `IntensityTier.label` has
exactly **two call sites, both display-only, both in
`ProgramSetupSubflow`**. So she picks `medium` on the screen that builds
her plan and every screen afterwards calls it `steady`.

---

## 10 · PRODUCT NOISE

Swept `goal · pace · program · plan · calorie target · budget ·
remaining · protein target · weight · weigh-in · record · book ·
journal · dose · shot · regimen · method`.

**Clean, with two exceptions, both above:** the four-way pace vocabulary
(§9) and `EditProfileView`'s collision with it. Everything else has one
name: the day's food is `your plates`, the weight record is `your
weigh-ins`, the shot log is `the doses`, the version chain is `dose
changes`, the six inputs are `your numbers`. `33` already split *"the
record"* into two headings that each say what they are.

No generic motivation, no AI theater, no fake precision, no unsupported
medical language reachable in production. Every assumption the app makes
is stated in her words on the surface that makes it (`31` §15, seven
sentences, re-verified).

---

## 11 · DISCOVERABILITY — 10 SECONDS

| job | path | ≤10s? |
|---|---|---|
| edit goal | Settings › goal weight *(states the number)* · your numbers · plan screen | ✓ |
| edit weight | Home tile · weigh-in · your numbers | ✓ |
| weight history | becoming › your record › **your weigh-ins** | ✓ |
| food history | becoming › your record › **your plates** | ✓ |
| delete food | plate page → remove | ✓ |
| change food day | plate page → **the day** | ✓ |
| **dose history** | Home medication row → regimen home → **the doses** | ✓ |
| **side effects** | regimen home → *how it's sitting* · dose sheet after a mark | ✓ |
| **side-effect history** | **nowhere** | **✗** |
| edit body facts | Settings › your numbers | ✓ |
| **change pace** | Settings › **your numbers** › pace — **NOT** Settings › `my pace` | **✗ actively misdirected** |
| change units | your numbers · the weigh-in's own toggle | ✓ |
| restore purchases · sign in | Settings › account | ✓ |
| doctor export | becoming › visit packet | ✓ |

**Two failures, and no new Home button is the answer to either.** One is
an information-architecture bug (a row pointing at the wrong screen); the
other is a missing list in a page that already has two.

**One honest note, recorded not fixed:** `becoming › your record` lists
plates, weigh-ins, check-ins and the visit packet — **but not the doses
or the symptoms**, which live in the regimen home. That is `33`'s
deliberate placement, copying MeAgain's own principle that the shot log
belongs beside the plan it documents. Stated so it is a choice on the
record rather than an oversight.

---

## 12 · SYNC IS A PRODUCT FEATURE — THE ACCOUNT TRANSFER MATRIX

Every user-owned fact. `34` and `35` measured most of this; the new rows
are marked **[NEW]**.

| fact | old device | server | new device | lossless? | if not, what she experiences |
|---|---|---|---|---|---|
| height · weights · goal · sex | ✓ | `users` | ✓ | **EXACT** | — |
| age | exact year | band only | band midpoint | **DEGRADED** | ≤35 kcal, screen says `about 29 · approximate` |
| activity | raw | 3-value alias | alias | DEGRADED, 0 kcal | ambiguity stated |
| GLP-1 · hormonal · sleep · trend · stress · food relationship | ✓ | `users` | ✓ | **EXACT** (`35`) | — |
| safety pace cap | ✓ | **none** | derived for `under18`+`bmi_low`, else absent | **PARTIAL** | no deficit published either way (`35`) |
| numeric suppression | ✓ | **none** | ✗ | **MISSING** | weight numerals return; no calorie numeral (`35`) |
| program mode / goal direction | ✓ | columns exist, **zero writers** | ✗ → **the app asks** | **MISSING, HANDLED** | one plain question (`35`) |
| program plan · units · pace | ✓ | ✓ | ✓ | EXACT | — |
| weigh-ins + **deletions** | ✓ | ✓ | ✓ | EXACT online | lost if the delete happened offline |
| food + photos + corrections + **a plate's day** | ✓ | ✓ | ✓ | EXACT | — |
| day checks · reflections · weekly reads · consents · sessions | ✓ | ✓ | ✓ | EXACT | — |
| regimen chains · dose events + **deletions** | ✓ | ✓ | ✓ | EXACT | `deleteDoseEvent` ships |
| **observations (side effects) — the WRITE** | ✓ | `observations` | ✓ | EXACT | — |
| **observations — the CLEAR** **[NEW]** | row removed | **row survives** | **row returns** | **✗ BROKEN** | **a symptom she retracted reappears — including in the clinician PDF** |
| steps / sleep | HealthKit | — | HealthKit | n/a | Apple's |
| body scans | local, backup **OFF** by default | opt-in | empty | BY DESIGN | **unstated on the surface** |
| Jeni memory | listed as durable | **✗ no table writer** | **empty** | **MISSING** | *"what jeni remembers"* starts at zero |
| chat transcript | on device | table exists, **zero writers** | empty | MISSING | — |
| manual move entries | UserDefaults | ✗ | empty | MISSING | a recorded session does not follow her |

### **[NEW] THE FINDING: clearing a side effect never reaches the server**

Traced this session:

- `SideEffectLog.remove` → `ObservationStore.delete(id:)` → **`context.delete` and nothing else.** Every sibling store queues a server delete; this one does not.
- `SyncService` has `deleteDoseEvent`, `deleteWeightLog`, `deleteFoodLog` — and **no `deleteObservation`.**
- `SyncService.hydrateObservations` is **insert-only by id** (`if let existing … continue`).

So a symptom she taps off comes back on the next hydrate — a new phone,
a reinstall, or any launch that pulls observations. **And
`VisitPacket.symptomSection` reads `SideEffectLog`**, so the resurrected
symptom reaches the PDF she hands a clinician.

This is exactly the shape `34` closed for weight — *"a delete the
insert-only hydrate undoes is worse than no delete"* — and it needs **no
migration**: `observations_delete_own` and
`grant … delete on public.observations` have both shipped since the
2026-07-28 care-platform migration. Verified in
`supabase/migrations/20260728000000_app_v8_care_platform_foundation.sql:50-54`.

It also repairs a second path: `MedicationLog.resolve(.unmark)` deletes
the `DoseEventRecord` **server-side** but its `.doseTaken` observation
**locally only** — so unmarking a past dose has always left half a row
on the server.

### Jeni's memory — investigated fully, per the brief, and NOT built

- **What is lost:** every `JeniMemoryRecord` — the things she explicitly asked her coach to remember, listed in Settings under *"what jeni remembers"* with a per-row forget.
- **Does she reasonably expect it to follow the account?** **Yes.** A per-row *forget* affordance is a promise of durability; nothing on that screen says "this phone only".
- **Does it change Jeni's behaviour?** Yes — the envelope carries it every turn.
- **Migration requirements:** a `jeni_memories` table with RLS + grants, on the established pattern (insert-only by id, `pendingUpsert`-guarded), plus DTO + hydrate + upsert.
- **Backward compatibility:** additive; old clients ignore it.
- **Privacy:** this is the most sensitive free-text a user gives the product. `MemoryGuard` already refuses doses, diagnoses, symptoms and body judgements **at the door**, so the table would never hold clinical text — but it must be RLS-scoped and it must be covered by delete-account.
- **Minimum safe architecture:** exactly `weight_logs` — table, four policies, grants, insert-only hydrate, a real server delete for *forget*.

**Recommendation: migration first, client in the build after.** It is
`31` §21's ordering hazard verbatim: the client 400s the whole `users`
row until the migration lands, so it cannot ride a build that must be
safe on its own. **Not prepared here, because a client that needs an
unapplied column is a loaded gun.**

---

## 13 · THE COMPETITOR GAP TABLE

MUST = a user reasonably expects this from the product Jeni claims to
be, and its absence materially weakens daily utility.

| job | Lose It | MeAgain | Shotsy | Jeni today | Jeni after | importance | action |
|---|---|---|---|---|---|---|---|
| calories remaining, stated | ✓ | ✓ | — | ✓ | ✓ | MUST | done (`33`) |
| the day's food as a list | ✓ | ✓ | — | ✓ | ✓ | MUST | done (`33`) |
| edit / delete a food entry | ✓ | ✓ | — | ✓ | ✓ | MUST | done |
| **put food on the day it was eaten** | ✓ 1 tap | ✓ Date row | — | ✓ 2 steps | ✓ 2 steps | MUST | done (`34`) |
| weight history as a list | ✓ | ✓ | ✓ | ✓ | ✓ | MUST | done (`34`) |
| edit / delete a weigh-in | ✓ | ✓ | ✓ | ✓ | ✓ | MUST | done (`34`) |
| every input to the target, visible | ✗ | ✗ | ✗ | ✓ | ✓ | — | **JENI ONLY** |
| dose history list | — | ✓ | ✓ | ✓ | ✓ | MUST | done (`33`) |
| **correct a past dose log** | — | ✓ | ✓ | **✗** | **✓** | **MUST** | **BUILD** |
| **log / fix a side effect on any day** | — | ✓ | ✗ | **✗** | **✓** | **MUST** | **BUILD** |
| **see side-effect history as a list** | — | ✓ | ✗ | **✗** | **✓** | **MUST** | **BUILD** |
| **a cleared record actually clears** | ✓ | ✓ | ✓ | **✗** | **✓** | **MUST** | **BUILD** |
| **the pace row edits the pace** | ✓ | ✓ | ✓ | **✗** | **✓** | **MUST** | **FIX** |
| food text search over a DB | ✓ | ✓ | — | ✗ | ✗ | NO | the words door is cheaper |
| meal buckets + per-meal suggestion | ✓ | ✗ | — | ✗ | ✗ | SHOULD | schema + a second mental model |
| a persistent global date pager | ✓ | ✗ | ✗ | ✗ | ✗ | SHOULD | IA change to a protected anchor |
| a global "+" reaching every record | ✗ | ✓ | ✗ | ✗ | ✗ | SHOULD | same |
| exercise adds calories back | ✓ | — | — | **✗ deliberate** | ✗ | NO | **JENI BETTER** |
| water target | ✓ | ✓ | ✗ | ✗ refused ×4 | ✗ | NO | no guideline body prescribes a volume |
| medication-level curve | — | ✓ | ✓ | ✗ refused ×5 | ✗ | NO | a PK claim about her body |
| clinician export | premium reports | ✗ | ✗ | ✓ | ✓ | — | **JENI ONLY** |
| streaks · badges · milestones · mascot | ✓ | ✓ | ✓ | ✗ | ✗ | NO | engagement theater |
| **blurred premium teasers over her own data** | ✓ Dashboard + Goals | ✗ | ✗ | ✗ | ✗ | NO | it makes her record feel rented |
| home-screen widget | ✓ | ✓ | ✓ | ✗ | ✗ | SHOULD | named, not built |

**Five MUSTs open. Four of them are the same defect. All five are
buildable without a founder gate.**

---

---

## 14 · WHAT WAS BUILT

Three boring capabilities and three consistency fixes — the budget the
brief sets, spent where §0 showed it was the only place it could be.

### CAPABILITY 1 · A past dose row is correctable

`the doses` rows are `Button`s now, opening **`DoseSheet` on that row's
own slot**.

**No new editor, and no new engine.** `DoseSheet` has taken a
`slotDayKey` since v24 and already carries the entire past-slot face —
the day's own title (`thursday's shot`), the taken record with its time,
the site still editable, `didn't, actually`, the four skip reasons.
`MedicationLog.resolve` has taken a `slotDayKey` since v24 too, and
already refuses to touch today's checklist or retire today's reminders
when the slot is not today. **What was missing was a tap target.** The
list `33` built showed her every shot and could not be touched, which is
the same write-only defect the list was written to close.

It cannot invent a day: `doseEntries` maps `DoseEventStore.events`, so a
row exists only for a slot **already on file**. The window is therefore
the record itself, not an arbitrary date range — pinned by
`testTheDoseRecordOnlyListsSlotsAlreadyOnFile`.

One line of copy: *"tap any of these to fix the site, the status, or take
it back."*

### CAPABILITY 2 · `the symptoms` — the record as a dated list

**`SymptomLedger`** (new, pure) + a section in the regimen home, sitting
between `the doses` and `dose changes`: what you did → how it sat → what
changed.

Its refusals are the design, and they are its two siblings' refusals: no
count of bad days, no "worse than last week", no severity average, no
streak, no link to a dose or a weight. **A day is one row**, so a
Tuesday that carried three things says three things once — never three
rows competing for the same date. Within a day the words are
alphabetical, which is stable and **ranks nothing** (ordering by severity
would be a judgement; the order a `Dictionary` returns is not an order
at all).

Pinned by `testTheSymptomRecordHasNoVocabularyForJudgement`, which sweeps
**every symptom × every severity** — 42 combinations — against a
28-word banned list.

### CAPABILITY 3 · A symptom on any of the last fourteen days — and a clear that actually clears

Two halves.

**The write.** `SideEffectSheet` takes a day and states it. The rule that
pinned the whole logger to today was **one line inside a view body** —
`where entry.dayKey == today` in `load()` — and `record`/`remove` simply
took their default argument. It moved to the store as
`SideEffectLog.recorded(on:userId:in:)`, because "which day am I
reading" is a store question, and **because a rule inside a view body
cannot be tested, which is why nobody noticed it was a rule.**

The interaction is the one both references ship (MeAgain puts a `Date`
row at the top of its side-effect log; Shotsy promotes *"tap to edit shot
details"* to its widget) and the one this product already ships one
domain over: `the day`, expanding in place, fourteen days, **never
forward** — a symptom cannot have happened tomorrow. Fourteen because
that is what the plate's picker offers, and one product should not hold
two opinions about how far back a person can honestly remember.

The row is the **first** thing on the sheet, above the title, because
everything below it writes to that day and a person who arrived from a
three-week-old row must never think she is recording today.

**The clear.** `SyncService.deleteObservation` — the missing half.

`ObservationStore.delete` and `.deleteSingular` did `context.delete` and
nothing else, while `hydrateObservations` is **insert-only by id**. So a
symptom she cleared came back on the next pull, and
`VisitPacket.symptomSection` reads these rows — **the resurrected symptom
could reach the PDF she hands a clinician.** It also repairs a second
path: `MedicationLog.resolve(.unmark)` has always deleted the
`DoseEventRecord` server-side and its `.doseTaken` observation locally
only, leaving half a row on the server.

**No migration.** `observations_delete_own` and
`grant … delete on public.observations` have both shipped since
`20260728000000_app_v8_care_platform_foundation.sql:50-54` — verified,
not assumed. Additive, no DTO, no schema, no transport change, and it
mirrors `deleteWeightLog` line for line.

### FIX 1 · One pace vocabulary in the paid product

`IntensityTier.label`: `soft/medium/hard` → **`gentle/steady/strong`**.

Two string literals. **Two call sites, both display-only, both in
`ProgramSetupSubflow`** — the screen that builds her plan. She picked
`medium` there and Home, `your numbers`, the pace editor and the coach
all called it `steady` from that moment on. The raw values are what is
persisted and they are untouched, so nothing about an installed account
moves. The consult's own `gentle/steady/focused` is left alone: it lives
entirely in the pre-purchase funnel, which this line of work does not
edit. One word differs in one place, stated.

### FIX 2 · Settings → "my pace" edits her pace

The row now opens **`JKPlanNumbersSheet(focus: .pace)`** and states the
pace she is on, in the same three words Home uses (the goal row's rule,
`29`, applied to the fact beside it). `HubRoute.myPace` is removed —
a route nothing navigates to is a false contract (`35` §9) — which
leaves `EditProfileView` with **zero call sites**, where `33` and `34`
already believed it was.

### FIX 3 · Two AX5 breaks, found by filming

Both on `SideEffectSheet`, both `33`'s `medica/tion ozem/pic` law:

- **mine**: `the day` beside `yesterday` wrapped to `the` / `day` — a
  word breaking inside itself, in a row I had just written;
- **pre-existing since E7**: a recorded pill is two strings, and
  `queasy · noticeable` ran **off the right edge of the screen** —
  `FlowLayout` places a capsule at its ideal width, and two long strings
  on one line exceed the device. It had never been filmed at AX5 because
  this sheet had no film door of its own until this session.

Both now stack from `xxxLarge`, the rule
`HomeNutritionSummary.stacksForType` has used since E9.

---

## 15 · RED → GREEN

The three cores reverted to their pre-session behaviour, then restored.

```
Executed 14 tests, with 18 failures (0 unexpected)
** TEST FAILED **
```

**9 of 14 red.** Restored: **14/14, exit 0, `TEST SUCCEEDED`.**

| test | RED |
|---|---|
| `testTheSymptomRecordListsEveryDayNewestFirst` | ✗ |
| `testADayThatCarriedTwoSymptomsIsOneRowStatingBoth` | ✗ |
| `testTheSymptomDayWordInheritsTheCalendarTimeZone` | ✗ (4 assertions) |
| `testTheSymptomRecordOffersFourteenDaysAndNeverTomorrow` | ✗ |
| `testASymptomCanBeRecordedOnADayThatIsNotToday` | ✗ |
| `testCorrectingAPastSymptomChangesThatDayAndNothingElse` | ✗ |
| `testClearingAPastSymptomLeavesEveryOtherDayOnFile` | ✗ |
| `testRecordingOnAPastDayNeverTouchesToday` | ✗ |
| `testThePaidProductHasOnePaceVocabulary` | ✗ |
| **the four DOSE tests** | **passed** |
| `testTheSymptomRecordHasNoVocabularyForJudgement` | **passed** |

**The five that passed are the point, and they say two different things.**

The **four dose tests passed because `MedicationLog.resolve(slotDayKey:)`
already worked.** The defect was never in the engine — it was an absent
tap target, and a stub cannot revert a missing button. Those four are the
**safety envelope** for the new tap target (a past correction must not
touch today's checklist, must not move another slot, must take both
halves of an unmark), not a demonstration of a fixed bug. **That is the
defect boundary drawn exactly**, the same way `34` recorded
`testCorrectingTheFreshestWeighInMovesTheDailyTargets` not failing.

The **banned-word sweep passed because it asserts a REFUSAL**, and a stub
that returns fewer rows still refuses everything. `34` and `35` both
recorded this lesson; it is now three for three.

### Two defects this session found in its own work

1. **A test file that broke another suite.** The first full run was
   `Executed 1242 tests, with 2 failures` — `ReattributionTests` counting
   **42** `WeightLogRecord` rows where it expects 2. `MedicationQASeeder`'s
   `history` variant also seeds ten weekly weigh-ins, four of my tests
   call it, and my `wipe` listed three model types instead of four.
   **The defect was in my file, not in the product and not in the test it
   broke** — and `ReattributionTests` was not weakened to accommodate it.
2. **A film door that filmed the paywall.** The first attempt at the
   side-effect frame paired `--debug-symptom-day` (which only opens the
   picker *inside* the sheet) with `--uitest-open-side-effects` (a
   HomeView door) and captured the **subscription wall**, because without
   an entitlement the app never reaches Home. `30` §12.1's law again:
   *a film door that cannot reach the surface it names is a fixture that
   lies about what was inspected.* Fixed by building
   `SymptomDayDebugHarness`, which mounts the sheet alone and seeds its
   own rows. **The door was fixed, never the frame.**

---

## 16 · FILMS

Every frame taken from the live build, iPhone 16 unless noted.

| frame | what it shows |
|---|---|
| `10_regimen_record_after.png` | the regimen home, nine doses, the new footnote |
| `11_regimen_both_lists.png` | **both record lists in one frame** — `the doses` (2 on file) and `the symptoms` (3 days on file), with `aug 12` proving the two-symptom row: `hair shedding · a touch, worn down · rough` |
| `12_symptom_past_day.png` | the logger on **yesterday** — `the day · yesterday`, two recorded pills in blush |
| `13_symptom_day_picker.png` | the fourteen-day picker open: `today`, `yesterday — the one you're on`, `aug 12` … `aug 1`. **No future day.** |
| `20_regimen_both_ax5.png` | AX5 — the regimen rows stack, no word wraps inside itself |
| `21_symptom_past_day_ax5.png` | **AX5, BROKEN** — `the` / `day` wrapped; the pill ran off the edge |
| `22_symptom_past_day_ax5_fixed.png` | AX5, fixed — both pairs stack |
| `14_symptom_past_day_normal.png` | normal text after the AX5 fix — **unchanged** |
| `30_regimen_both_se.png` · `31_symptom_past_day_se.png` | SE |

**The long-page problem, stated.** The regimen home with nine doses is
longer than one screen, so `the symptoms` sits below the fold and
`simctl` cannot scroll (this repo's own record: synthesized drags do not
move the iOS 26.2 simulator). `--debug-regimen-record-short` seeds ONE
dose so both lists fit one frame. It is the same page with a shorter
history — not a different page — and it exists because a section nobody
has filmed is a section nobody has looked at.

---

## 17 · PROOF

Every command run **serially**, unpiped, `$?` captured directly
(`32` §13 — `PIPESTATUS` is bash; this shell is zsh).

| command | expected | actual | exit | verdict |
|---|---|---|---|---|
| `-only-testing:plankAITests/PastRecordRepairTests` | 14 | **14** | **0** | `** TEST SUCCEEDED **` |
| `-only-testing:plankAITests` | 1242 | **1242** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankSync` (from the package dir) | 9 | **9** | **0** | `** TEST SUCCEEDED **` |
| `-scheme PlankFood` (from the package dir) | 200 | **200** | **0** | `** TEST SUCCEEDED **` |
| `… WallExitWalkUITests/testSpentWallCloseButtonAlwaysResponds` | 1 | **1** (10.4 s) | **0** | `** TEST SUCCEEDED **` |
| `build -configuration Release` | — | — | **0** | `** BUILD SUCCEEDED **` |

App suite **+14** over `35` (1228 → 1242), which is exactly
`PastRecordRepairTests` and nothing else. **No existing test changed and
none needed to.** Baseline re-measured at the start of this session
rather than inherited: 1228/1228.

**A suite passes only if expected == actual AND exit == 0 AND the final
verdict is `TEST SUCCEEDED`.**

The 5.6 regression gate is included because this session touched two
sheet-presenting surfaces, which is the family the rejection was about.

### Release binary

`Release-iphoneos/plankAI.app/plankAI`, **85.7 MB, 123,475 strings** —
size and total count stated first, because *a zero from a file that does
not exist is the `Executed 0 tests` trap in different clothes* (`35`).

| string | count |
|---|---|
| `--uitest` · `--debug` · `--food-debug` | **0 · 0 · 0** |
| `persona-customer` · `persona-autym` | **0 · 0** |
| `debug-weigh-ins` · `debug-plate-day` | **0 · 0** |
| `debug-regimen-record` · `debug-symptom-day` | **0 · 0** |
| `the symptoms` · `tap any of these to fix` | **1 · 1** — the new copy IS in the shipping binary, not behind a door |

### Protected paths vs the reviewed release `1710180`

| path | diff |
|---|---|
| `PlankApp/Payment` · `Views/Paywall` · `Auth` | **EMPTY** |
| `App/AppPhase.swift` · `Info.plist` · `plankAI.entitlements` | **EMPTY** |
| `Notifications` · `Care` · `BodyScan` · `Workout` · `JenifitWidgets` | **EMPTY** |
| `supabase/migrations` | **EMPTY** |
| `PlankApp/Analytics` | `31`'s +6 allowlist lines. **This session: EMPTY.** |
| `Packages/PlankFood` | `34`'s `setLoggedDay`. **This session: EMPTY.** |
| `Packages/PlankSync` | `31`'s merge + `34`'s delete + **this session's `deleteObservation`** |

**One protected path moved and it could not be avoided.** The delete
lives in `SyncService` and nowhere else, and a delete the insert-only
hydrate undoes is worse than no delete — `34`'s argument for
`deleteWeightLog`, verbatim, for the same reason.

**All three files that DECLARE a `@Model`** (`PlankSync/Models.swift`,
`Chat/ChatModels.swift`, `Chat/JeniMemory.swift`) have a **zero diff
against `1710180`** — measured with `grep -E "^\s*@Model"`, not with a
loose substring match, and re-verified rather than inherited. **There is
no SwiftData store migration to fail.**

### This session's files

`SymptomLedger.swift` (new, pure) · `PastRecordRepairTests.swift` (new,
14) · `SideEffectLog.swift` · `ObservationStore.swift` ·
`SideEffectSheet.swift` · `RegimenSheet.swift` · `ProfileHubView.swift` ·
`ProgramSetupSubflow.swift` · `AppSync.swift` · `DebugPreviewRoutes.swift`
· `PlankSync/SyncService.swift` · `project.pbxproj` (two file
references) · this document. **Thirteen.**

New DEBUG doors, all inside `#if DEBUG`: `--debug-regimen-record`
[`-short`] · `--debug-symptom-sheet` · `--debug-symptom-day`.

**No migration written or applied. No Edge Function deployed. No
production SQL executed. No production data read or mutated.**
`CURRENT_PROJECT_VERSION` still **30** — the archive-time bump to **31**
stands and is still the founder's step.

---

## 18 · WHAT REMAINS

### P0 — none.

### P1

1. **Jeni's memory does not follow the account.** Investigated in full
   (§12): a `jeni_memories` table on the `weight_logs` pattern.
   **Migration first, client after** — the ordering hazard, not the cost.
2. **`users.program_mode` / `goal_direction` / `medication_status`** —
   three columns that already exist with zero writers. Verify applied,
   then it is a client-only change (`35` §5.5).
3. **The four FDA label micros** are written into the food-vision EF and
   not deployed. Standing founder gate.
4. **`open_food_book` and a goal-weight act** — both new tool NAMES,
   therefore an EF deploy. The only thing keeping JENI INTEGRATION off 8.
5. **`onb_consent_personalize`** — a recorded consent the product does
   not honour. Founder/legal, recommendation on file since `30` §15.
6. **Run `docs/app_v25/census.sql`**, `reconcile_21.sql`,
   `no_target_census.sql`. Three sessions overdue.

### P2

- Logging food **directly** to a past day (two steps today).
- Meal labels, so the record answers by name and not by clock.
- Manual move entries and the chat transcript do not sync;
  **body-scan device-locality is unstated on the surface.**
- A record deleted **offline** still returns (tombstones are the real
  fix; this now matches all four existing deletes rather than three).
- The consult's `focused` vs the product's `strong` — one word, funnel.
- The CONSISTENCY streak card in Becoming.
- **Dead code with zero production call sites, re-verified this
  session:** `EditProfileView` (**newly** unreachable, §9) · `RepEngine` ·
  `supplementPlans` · the 14-lesson corpus · the 84-day CBT manifest
  (still parsed on every launch) · `SafetyCheckInView` ·
  `EnergyLedger.spentKcal`/`isLighterDay` · `StepsBentoTile` · the legacy
  v4.5 `OnboardingView`.
- Everything carried from `32` §15, `34` and `35`: the age band's 35
  kcal, the offline day-stamp, the residual resurrection window, start
  weight not user-editable, two devices / two units.

---

## SAFE FOR NEXT BUILD: YES

Not because the suites are green. Because the change is shaped so that
the only customers whose experience moves are the ones who were stuck:

- **Nothing existing writes differently.** `SideEffectSheet`'s day
  defaults to today, so its three pre-existing call sites are
  byte-identical. `MedicationLog.resolve` is untouched. The dose rows
  gained a tap target; the rows themselves render the same.
- **One new store method** (`recorded(on:)`, extracted from a view) and
  **one new sync method** (`deleteObservation`, additive).
- **No `@Model` changed**, so no SwiftData migration exists to fail.
- **No schema change.** The DELETE grant and the `delete_own` policy have
  shipped since 2026-07-28.
- **The arithmetic is untouched.** Not one constant moved; the golden
  matrix, `OneTargetEverywhere`, `AutymRecovery`, `UpgradeBoundary`,
  `PlanIdentity` and `SafetyRestore` are all green and all unchanged.
- **A non-GLP-1 account sees exactly one changed pixel** — the pace word
  on the plan-builder screen and the Settings row that now works.
- Twelve protected paths EMPTY, the thirteenth additive, the binary
  strings-clean, and the 5.6 exit path re-verified green.

