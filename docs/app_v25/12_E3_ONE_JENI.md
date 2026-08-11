# E3 — ONE JENI (the architecture)

2026-08-11 · branch feat/app-v2 · the era's law.
`11_E3_DECISION.md` is why this era and not movement;
`13_E3_EVIDENCE.md` is what was proven and how. Where this document is
silent, `00_THE_SYSTEM.md` rules.

---

## 0 · THE ONE SENTENCE

**The coach can read her own record, remember what she is told, and
change the plan in words — through the same chokepoints, the same
authority law and the same engines the rest of the product uses.**

Not a better chat tab. The chat is the *door*; the value shows up in
Today, in the program's memory, and in what the app knows next week.

---

## 1 · WHAT WAS BROKEN (all three confirmed in code, not inferred)

1. **She could not look anything up.** `ChatSession.handleToolCall`
   executed a non-confirming tool and the turn ENDED — the comment
   said "navigation tools act immediately; no continuation needed."
   Fine while every tool opened a screen; fatal for a read, whose
   result could never reach the model. All seven shipped tools were
   *act* tools for exactly this reason.
2. **Everything she knew was one flat snapshot of today.** The
   envelope was rich and disciplined and strictly present-tense. "what
   did i eat friday", "how did last week compare", "what changed since
   my dose went up" had no path to an answer.
3. **The plan was not negotiable.** E1 built `ProgramFactStore` with a
   full authority law and gave it ONE door — the weekly read, which
   needs a week. 82% of people who finish onboarding never have a
   second day.

Plus: the two server prompts that generate most of Jeni's language
still addressed a woman, four days after the unisex correction.

---

## 2 · THE TOOL SURFACE (`JeniToolCatalog`)

Tools are declared **client-side** and sent on the wire. The edge
function validates each against `ALLOWED_TOOL_NAMES` and drops what it
does not recognise; a client that sends nothing gets the built-in
seven.

**Why this matters more than it looks:** every tool addition used to
be a founder-gated deploy, and five eras have queued behind those.
This is the last `jeni-chat` deploy a tool addition ever needs. Both
directions degrade cleanly (old app + new function; new app + old
function).

Three kinds, and the difference *is* the era:

| kind | behaviour | card? | continues the turn? |
|---|---|---|---|
| `read` | answers from the stored record | no | **yes** |
| `actImmediate` | opens or renders something | yes (executed) | no |
| `actConfirmed` | changes stored state | yes (proposed) | yes, after the tap |

`ChatToolRouter` reads the catalog's kinds rather than keeping a
second list, so the list the model sees and the behaviour the app
gives it cannot drift. Pinned.

### The loop

```
user turn
  → model emits read tool call(s)          (≤2 per turn, hard cap)
  → ChatSession replaces its preamble       (a decision to look
                                             something up is not an
                                             answer)
  → readingLine renders under the typing bubble ("reading your trend")
  → JeniReadTools executes against the real stores
  → continuation POST carries results WITH their arguments
  → jeni answers, streaming into the SAME bubble
```

The wire carries `tool_results` in the plural with real `arguments`.
The v2 shape replayed the assistant call as `arguments: "{}"`, which
was survivable only while no tool took arguments; `read_food_day{
weekday:"friday"}` replayed as `{}` tells the model nothing.

---

## 3 · THE READS (`JeniReadTools`)

Eight lookups: `read_food_day` · `read_food_week` · `read_weight_trend`
· `read_dose_history` · `read_symptoms` · `read_patterns` ·
`read_activity` · `read_program`.

**Law 1 — one answer.** Every read renders from the SAME engine the
surfaces render from: `WeightWeekReadEngine` (E2),
`MedicationScheduleEngine.cyclePosition` (E2),
`MedicationPatternEngine` assembled exactly as the Becoming tile
assembles it (v24), `FoodWeekRead` floors (v9), `ProgramFactStore`
(E1). Chat and UI cannot disagree because there is only one answer.

**Law 2 — honest emptiness.** Every read can return `have: false` with
a `why`. A day with no plates is "not logged", **never zero**, and its
refusal repeats S3's law verbatim ("unrecorded is not the same as not
eaten"). One weigh-in has no direction. A pattern under its floor does
not exist. The prompt is told that silence is a real answer.

**Law 3 — provenance travels.** `sufficiency`, sample counts,
`cycle_basis`, `authority` and `sparse` ride with the numbers, so the
hedge is earned rather than decorative.

**Law 4 — the standing floors hold.** Numeric suppression strips every
kcal and weight from a read exactly as it does from a screen (pinned).
Compound, never brand (pinned). No body-scan imagery or derived body
numbers (L4). No free text the user wrote in a note.

Reads never write.

---

## 4 · THE MEMORY (`JeniMemory`)

The compounding half. Every other store records what HAPPENED; this
records what the person SAID about themselves — the only part that
makes next week's conversation better than this one.

- **`JeniMemoryRecord`**: topic · note (verbatim) · basis · createdAt ·
  supersededAt. App-target `@Model` beside `ChatMessageRecord`.
- **Nothing is written silently.** `remember` is `actConfirmed`, so the
  card comes first, showing the exact words. The adaptation-consent
  law (§13) applied to knowledge.
- **`MemoryGuard`** refuses at the door: doses, brands, diagnoses,
  symptoms, body descriptions, weights, ED/self-harm language, and
  numbers the app already stores with a basis. Length-bounded.
- **Near-duplicates supersede.** "before 11am" → "before noon" leaves
  one live fact, not two contradicting ones.
- **Bounded** (6 per topic) so the set fits a context envelope and a
  person's patience.
- **It is theirs**: `what jeni remembers` in settings shows every note
  verbatim with `forget` on each and `forget all of it` beneath. A
  memory a person cannot audit is a profile.

Basis is `told` or `confirmed`. There is deliberately no `inferred`:
nothing here is written behind their back.

---

## 5 · THE ACTS (`JeniActTools`)

`propose_program_fact` is the era's second door onto E1's memory.

**The laws that do not bend:**

1. **A chat proposal is a PREFERENCE, never a prescription.** The store
   is called with `.preferred`; nothing else can be passed.
2. **A prescribed head REFUSES.** No write, no "preference underneath",
   and a refusal that routes to the correction door. The failure worth
   pinning is not the overwrite — it is the quiet preference filed
   below a clinician's number, waiting to surface the day the
   prescription ends.
3. **Value coherence is checked, not trusted.** `walkTiming` +
   `softened` is refused, not stored.
4. **The stored value is what gets acknowledged**, not the requested
   one, so a clamped goal is reported as what it became.

**The closed set chat may touch:** `stepGoal` · `weighCadence` ·
`loggingMode` · `notificationPosture` · `walkTiming`. Deliberately
EXCLUDED: `proteinAdjust` and `movesAdjust` (clinical advisory bands
the weekly read composes from rules — an LLM doing dietary maths in a
chat turn is the shape of the never-dose-advice redline) and
`readAnchor` (structural).

Also: `log_food_text` hands the words to the app's own describe path
with the estimate and the confirm intact — jeni never authors a plate,
because a number with no reading has no provenance. `open_dose_sheet`
routes; she never marks a dose and never restates label rules.

---

## 6 · THE ENVELOPE (zero-deploy value)

`CoachContextAssembler` grows three blocks that work with the
**currently deployed** function:

- `remembered{}` — what she was told, verbatim, by topic.
- `program_facts[]` — kind, value and **authority**. E1 built the
  ladder and chat could not see it, so jeni could recommend against a
  prescription without knowing one existed.
- `food_week{}` — days logged, days that met the protein floor.

---

## 7 · THE VOICE, CORRECTED

- Both EF prompts unisex. `jeni-chat` gains a WHO YOU ARE TALKING TO
  block (any sex, any age, never assume; biological sex appears only
  where the maths needs it). `food-vision` loses "gen-z women" twice,
  including over its recognition priors, and its cohort list broadens.
- **AI-identity disclosure** (CA/IL/TX, in force; §8 promised it):
  "jeni is a digital coach. not a person, not your clinician." on the
  chat desk and in settings, plus a prompt rule that she answers the
  question directly rather than joking past it. Statute outranks the
  never-say-"AI" style law; "digital coach, not a person" clears both.
- Jeni takes **no pronoun** (the 08-10 rule: where a sweep flattens
  jeni, the pronoun is removed rather than assigned).

---

## 8 · WHAT THIS ERA DELIBERATELY DID NOT DO

- No new tab, no mascot, no proactive chat pushes. The desk stays
  quiet (§8).
- **No method/lesson work and no library kill.** 132 post-onboarding
  openers make it the #2 activity in the product; the audit's REMOVE
  line was about lesson libraries in the literature, not this corpus
  in this product, and the claim needs data we do not have.
- No food-vision accuracy work (E4, still behind its measurement
  gate).
- No clinic UI (E6, founder-gated).
- No PK curves, no dosing math, no diagnosis.
- **No transcript sync.** Chat stays device-local, as it has since v2.

---

## 9 · THE DECISIONS (with what was declined)

| # | decision | declined |
|---|---|---|
| 1 | reads continue the turn into the SAME bubble | a tool card showing plumbing, then a second bubble |
| 2 | tools declared client-side, allowlisted server-side | a server-owned tool list, and a deploy per tool forever |
| 3 | ≤2 reads per turn | unbounded tool loops |
| 4 | memory written only through a visible card | silent LLM-extracted profiling |
| 5 | memory refuses medical/body categories outright | trusting a prompt rule to hold |
| 6 | chat writes `preferred`, prescribed refuses | a chat-only shadow of the program |
| 7 | chat cannot touch protein/calorie targets | letting the model do dietary maths |
| 8 | `log_food_text` opens the describe path | an LLM-authored plate with no reading |
| 9 | a richer envelope AND tools | tools only (which would strand every value behind the deploy) |
| 10 | the identity line replaces the old disclaimer | adding a second line and keeping an em-dash |
