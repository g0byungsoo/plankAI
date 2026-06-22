# JeniMethod education content audit — 2026-06-11

Lessons touch 84% of WAU vs workouts 8.5%. The curriculum is the strongest surface in the app
and it is still written for the plank-app era: 5 of 14 lessons are workout-centric, the protein
lesson says "no apps, no tracking" (contradicting the shipped snapMeal rail), and zero lessons
teach the three rails users actually touch daily (plate snaps, weigh-in, lighter days). The arc
below rebalances toward food + body literacy while keeping the psychology spine, which is the
genuinely strong half.

Sources read: `JeniMethodRitual.swift` (all live copy), `JeniMethodContent.swift`,
`JeniMethodRitualView.swift`, `PlanView.swift`, `EnergyLedger.swift`, `ProgramDayPrescription.swift`.

---

## 1 · the revised 14-day arc

| new day | old | verdict | topic + rationale |
|---|---|---|---|
| 1 | d1 welcome | **rewrite** | keep 4-page welcome but reframe from "muscle math + your workout plan" to "your program" (rails: plate snaps, steps, lessons, plank). soften the muscle-math over-claim (§4). handoff → first unchecked row, not workout. |
| 2 | — | **new** | *snap it, don't count it.* the snapMeal row is on her checklist from day 1 with zero education behind it. self-monitoring is the single best-evidenced weight-loss behavior (Burke 2011); teaching it day 2 is the highest-leverage slot in the arc. drafted in §5. |
| 3 | d10 protein | **move + rewrite** | *protein first.* protein-first framing just shipped on the food rail; the lesson must arrive before week-1 habits set. delete "no apps, no tracking" line. add GLP-1-relevant muscle-preservation angle (appetite-suppressed users under-eat protein by default, mirrors EnergyLedger's GLP-1 floor). add missing citation (Leidy 2015). |
| 4 | d2 paradox | **rewrite** | *you can't out-move your plate.* the strongest diet-first lesson already in the deck. fix banned vocab ("crush a workout", "out-burn" → "out-move"). repoint the action from workout-feeling to the food rail: movement keeps it off, plates move the number. |
| 5 | — | **new** | *the scale is moody. the trend is honest.* weighIn is a checklist row and weight logging was near-zero at launch (v1.0.6 findings). scale literacy (water, glycogen, cycle ≈ ±2 lb noise) is the missing unlock, and it is the natural data-aware lesson (her own trend line). drafted in §5. |
| 6 | d5 walk | **keep** | walk right after you eat. concrete, evidence-clean (Engeroff 2023), zero overlap. em-dash retrofit only. |
| 7 | — | **new** | *lighter days.* the founder's deficit insight just shipped; the mark is deliberately quiet (no statement on unmarked days) so a lesson must teach what it means and what it never means (not a grade, not a streak, under-eating never earns it). week-1 close is the right reveal moment. |
| 8 | d8 + d9 | **merge** | *the comeback.* what-the-hell effect (Polivy & Herman) + self-compassion (Adams & Leary 2007) are one behavior taught twice. merge: page 1 the trap, page 2 the kind return. frees a slot. |
| 9 | — | **new** | *food noise.* the cohort's own word for it (GLP-1-era fluency); no competitor lesson teaches it without selling a drug. positions breathwork occasions as the in-app tool (Balban 2023). drafted in §5. |
| 10 | d13 sleep | **move + rewrite** | sleep is the multiplier. keep Spiegel hunger-hormone core; cut the cortisol→belly-fat over-claim (§4). engine already reads sleep (Nedeltcheva floor), so make it data-aware: "your plan already paces for your sleep." |
| 11 | d3 + d12 | **merge + rewrite** | *the quiet 7,500.* NEAT + exercise snacks are one idea: untracked movement counts. anchor on the steps rail's 7,500 (Paluch 2022) and cite her own step average. rename away from "invisible burn" (banned verb). |
| 12 | d6 small | **keep** | small you'll do beats heroic you won't. core brand thesis. fold one line of d11's enjoyment finding into the action page ("pick the version you don't dread"). soften NWCR claim (§4). |
| 13 | d7 66 days | **keep** | sixty-six days. lands best late: two weeks in, she needs the "this is supposed to take a while" reframe before the arc ends. |
| 14 | d14 begin again | **rewrite** | fresh-start effect stays. fix the close: "you made it two weeks" must hand off to *her* plan length ("day 15 of your N" via `plan.totalDays`, never hardcoded). |
| 15+ | generic | **rewrite** | daily check-in stays one page, but the body should reference her yesterday (steps, plates logged, lighter mark) instead of rotating form tips, and the CTA must point at today's next unchecked row, not "start today's workout." |

**Cut entirely:** d4 *the boring hold wins* (the plank check-in screen already carries McGill norms +
the Edwards brief; duplicating it spends a curriculum slot on the 8.5% surface) and d11 *enjoyment*
as a standalone (folded into day 12).

---

## 2 · retention mechanics

**what Noom gets right (copy it):** sequenced daily curriculum with a visible arc, psychology before
mechanics, one idea per lesson, lessons unlock daily (scarcity beats binge). their lessons are the
moat because they make the user feel smarter every day, not because the science is deep.

**what Noom gets wrong (don't):** article-length walls of text, quizzes that grade you, calorie-density
color coding (green/yellow/red = good/bad food labels, a direct anti-shame violation), 2010s
CBT-worksheet register that reads condescending to this cohort. Noom teaches *at* her; JeniFit
should hand her a receipt and get out of the way.

**length:** the 2-page lock is correct and is the moat against Noom fatigue. fact page ≤ 65 words,
action page ≤ 40. one lesson = under 60 seconds. never add a third page to "fit more in"; cut instead.

**interaction beats:** keep tap-to-advance only. no quizzes, no sliders. the one interaction worth
adding is a single **tap-to-reveal** on the fact page (headline poses it, tap flips the number:
"how much of eating-less loss is muscle? → about a quarter"). curiosity-gap beats quiz-grade.

**"save this" moments:** the re-read index (`JeniMethodReReadView`) is the save surface. give each
lesson one screenshot-shaped line (the headline already is one). day 5's "the scale is moody. the
trend is honest." and day 9's "food noise isn't hunger." are share-bait by design.

**data-aware lessons (her week beats generic content):** all from collected fields only
(data-provenance rule). day 5 → her own trend vs last single weigh-in; day 7 → her week's lighter
marks; day 11 → her 7-day step average vs 7,500; day 14 → her plates logged + lessons done count;
generic → yesterday's one best number. each needs a guarded fallback to universal copy when the
field is empty (same pattern as `bodyFocusPhrase`).

---

## 3 · last-page verdict: repair and redirect

**verdict: redirect, don't delete.** end every lesson on the day's **next unchecked checklist row**
("next: snap your first plate" / "next: 10 easy minutes"), falling back to "back to your plan" when
the day is done.

why not delete: lesson→action chaining is real. implementation-intention evidence (Gollwitzer
meta-analysis, d = .65) and habit-stacking both show that pairing a prompt with an immediately
available action beats prompt-alone. the lesson is the app's highest-attention moment; ending it
on a dead "done" wastes the day's best handoff.

why not keep the workout handoff: it chains the 84% surface to the 8.5% behavior. a daily CTA she
ignores 3 days out of 4 trains CTA-blindness for the whole app. and it is literally broken: in
`PlanView.swift:171` the lesson is presented without `onCompleteAndStartWorkout`, so the final
button says "start today's workout" and then just dismisses. a button that lies daily is worse
than no button. the checklist redirect also rides goal-gradient motivation (Kivetz 2006): each
checked row makes the next more likely, and the lesson row auto-checks on completion, so she
lands on a fuller day than she left.

implementation shape (for the eng pass, not this doc): `isHandoff` pages take their CTA label from
the next `ProgramDayPrescription` title; `RitualToWorkoutSplash` generalizes to a ritual-to-next-row
bridge.

---

## 4 · evidence receipts

**pattern rule:** every fact page carries exactly one lowercase citation line; action pages never do.
the receipt is a brand differentiator against Noom's vague "psych-backed" claims, and this cohort
(skeptical-but-hopeful, burned by misinformation) reads an unsourced claim as another TikTok take.
two lessons currently break the rule: d10 protein (no citation) and d1's recomp page (no citation).

**over-claims to fix in the rewrite:**
- **d1 muscle math:** "muscle burns ~3× more at rest" is true per kg but tiny in absolute terms
  (~13 kcal/kg/day; 2 kg of muscle ≈ one apple). reframe from "more muscle = more burn" to
  "keeping muscle protects your spend while you lose." the ratio stays, the promise shrinks.
- **d13 cortisol:** "stress hormone… the one most tied to belly fat" overstates an associational,
  modest link. cut the belly-fat clause; the Spiegel hunger-hormone finding carries the page alone.
- **d6 NWCR:** "study after study" describes a self-selected registry. soften to "the people who
  kept it off for years" and keep the citation honest.
- **d12/d11 VILPA:** "linked to living longer" is correctly correlational; keep that exact hedge
  in the merged day-11 lesson.
- **vocabulary retrofit (applies to every kept lesson):** all copy predates two locks. remove
  every mid-sentence em-dash (2026-06-09 lock); replace banned verbs: "crush a workout" (d2),
  "out-burn" (d2 headline), "the invisible burn" (d3), "earn" framings. mechanism-sense "burn"
  still reads as 2010s diet culture to this cohort; "spend" is the replacement.

---

## 5 · three drafted replacement lessons

italic punch words marked [word]. fact page → action page. each ends on the next-unchecked-row CTA.

### day 2 — snap it, don't count it
**page 1 · fact** · eyebrow: "the camera trick"
headline: "snap it. don't [count] it."
body: "people who keep track of what they eat lose about twice as much as people who don't.
not because tracking changes the food. because [seeing] it does. no math, no judgment, no
good or bad. one photo before you eat. that's the whole habit."
citation: "burke et al., j am diet assoc (2011)"
**page 2 · action** · eyebrow: "today"
headline: "snap your next plate."
body: "every food fits. the photo isn't a confession, it's a [receipt]. you're collecting
evidence of a person who pays attention."
cta: next unchecked row

### day 5 — the scale is moody. the trend is honest.
**page 1 · fact** · eyebrow: "scale literacy"
headline: "the scale is [moody]. the trend is honest."
body: "your weight swings up to a kilo in a day. water, salt, your cycle, when you last ate.
none of it is fat. a single morning number is weather. the line through your week is
[climate]. that's the only number we read."
citation: "helander et al., plos one (2014)"
**page 2 · action** · eyebrow: "today" *(data-aware: her trend when ≥3 logs, else universal)*
headline: "step on. write it down. walk away."
body: "log it and let the trend do the reading. an up day changes nothing. you weigh in to
[feed the line], not to get graded."
cta: next unchecked row

### day 9 — food noise
**page 1 · fact** · eyebrow: "name it"
headline: "food noise isn't [hunger]."
body: "that loop where you're thinking about snacks an hour after lunch? it has a name now,
and it spikes with stress. five minutes of slow exhale-heavy breathing measurably lowers the
stress response. you can't argue with the loop. you can [breathe under] it."
citation: "balban et al., cell reports medicine (2023)"
**page 2 · action** · eyebrow: "next time it's loud"
headline: "breathe first. then decide."
body: "open your breath session, two minutes, long exhales. still want it after? have it.
it fits. the breath isn't a no. it's a [pause] you own."
cta: next unchecked row

---

*all new copy: lowercase, no em-dashes, no "AI", no deficit/burn/earn/crush, hearts only terminal,
one italic punch per line max. fact bodies ≤65 words, action bodies ≤40.*
