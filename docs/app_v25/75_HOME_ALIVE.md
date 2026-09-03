# PASS 75 — HOME, ALIVE

**feat/app-v2 · built 2026-09-03, after 74.** The founder's brief: make
Home exceptionally premium, minimal, tactile, alive and obvious — while
everything important today stays readable in one glance. Start by USING
the current Home; study the reference video first; extract principles,
never frames.

## 1 · What the reference taught (YEcKmwIk6VUgPl2t.mp4, 5s @ 60fps, 302 frames)

A gamified habit tracker's Home entrance, scrubbed frame by frame
(evidence 01):

- **The page earns its state in front of you.** Counters count UP to
  their true values where the eye can see them (streak 0→3, XP ticking,
  gem total 0→235). Progress bars FILL and their milestone checks pop
  as the fill crosses them. Week-strip checks draw in sequence.
- **One direction, then stillness.** Blocks arrive top-to-bottom in
  ~1.2s — and then the interface is COMPLETELY still for the rest of
  the clip. Stillness after arrival is the design, not the absence of
  one.
- **Three strong blocks, one job each** (identity/streak · level ·
  quest list), a quiet completion count ("0/5 completed"), and a row
  anatomy of identity + title + one support line + right-side check.
- **Deliberately not copied:** streaks, XP, gems, quest language,
  avatar identity, the candy palette — all either banned by standing
  law (no streak guilt, never a grade) or not Jeni. What was taken is
  choreography: *counting where visible, drawing in sequence, then
  silence.*

## 2 · As found (filmed before any code)

Walked morning / midday / evening / GLP-1 / sealed / SE / AX5 with the
DriveUITests walker-arm and simctl films:

1. **The entrance played to nobody** (evidence 04, 05). Home mounts on
   the first frame of the 0.45s phase crossfade; `arrived` flipped at
   +50ms, so the numeral's count, the ring's trace and the 55ms stagger
   all finished under the fade. First legible frame: "83" already
   final, page reads as one flat crossfade — the exact vocabulary the
   product owns (JeniCountingNumeral, JeniRing, jeniArrive), conducted
   too early. The dial numeral counted while the page sat at opacity 0.
2. **The hero spent ~500pt on four facts.** Ring 156/15 + minis + dots
   pushed TODAY below the fold on every medicated day; in the evening
   the "close the day" row rendered 60% behind the tab bar with an
   OPTIONAL session offer fully visible above it (evidence 12).
3. **Done asks kept their imperatives.** "add a small meal, protein
   first" beside a drawn check — with the promoted lead's berry dot
   still attached (evidence 21). The day's plate count lived nowhere
   above the tools.
4. **The strip's kept-check ate today's identity.** At 9:41am the
   selected today cell showed a CHECK instead of the date — read as
   "day complete" while the dial said 83 g to go, and the one selected
   day was the one whose number you could not read.
5. **The GLP-1 standing spent dose-day weight every day.** A 2-line,
   44pt-seat bordered object for "in 6 days" (evidence 10).
6. **Copy:** "move · 1 strength session in" — a sentence that ends
   mid-thought; the method row's 13-word first-state wrapped to two
   lines in a trailing value slot.
7. **SE (walked, then chased in code):** the p62 masthead scrim is a
   fixed 84pt gradient tuned on Dynamic-Island geometry; on the SE's
   20pt status bar its fade zone sits exactly where the resting
   masthead renders — "morning, maya." washed to a ghost on every
   launch (evidence 14).

## 3 · What shipped

① **THE CONDUCTOR'S BEAT.** Home's arrival flips at +0.38s — as the
phase crossfade's tail lands — so the one assembly plays on visible
paper: masthead and strip rise, the dial numeral COUNTS where she can
see it, the ring traces, rows land as receipts, then the page is still
(evidence 06). Runs once per process; tab returns and foregrounds never
replay it (evidence 20). Reduce Motion arrives whole — state, not
motion (evidence 18).

② **THE RECORD DRAWS ITSELF IN.** The strip's kept rings trace closed
left-to-right at arrival (JeniMotion.draw, 50ms per column — the
reference's week-marks moment in Jeni's own grammar); later weeks
render settled (evidence 07). RM: settled from frame one.

③ **THE STRIP KEEPS IDENTITY AND STATE.** The kept mark no longer
replaces the selected day's number: the record rides the ink disc's rim
as a berry ring (rose = data, ink = selection — the v21 split) and the
number stays (evidence 08). Cells speak ", kept" to VoiceOver.

④ **THE HERO'S BUDGET.** Ring 156/15 → 132/11.5, minis air 20→14, dots
10→8. TODAY plus both rows and the offered session now sit above the
fold on a medicated morning (evidence 09); the laws inside (lead rule,
remainder word, count-up silence, sugar-badge-never-gauge, fiber dv
named, absence prints nothing, suppression face) untouched. The
plates/numbers faces still fit the measured stage (evidence 19).

⑤ **THE RECEIPT GRAMMAR.** `BeatCompletion.doneTitle` (pure, pinned ×5
in DelightTests): a done row states what happened, never re-issues the
ask. The meal receipt speaks the RECORD — "1 meal logged" / "4 meals
logged" from the day's actual plate count, "meal logged" when marked by
hand with no plate on file (a receipt never invents a meal). Session /
weigh-in / dose / breath receipts state past facts; steps keep their
own authority (stepsRowTitle); unlisted beats keep their ask. The
promoted lead's dot renders only while the ask is open.

⑥ **THE STANDING ADAPTS TO THE DAY.** dueToday/late keep the full
2-line seated object; upcoming/done/skipped compress to one quiet line
("your next shot is wednesday · in 6 days", 20pt glyph, ~44pt row —
evidence 09 vs 10). At accessibility sizes every standing takes the
stacked layout (the caps yield to the words), capped at accessibility2
(JFContinueButton's precedent) after AX5 films caught "wednesda/y"
shearing twice (evidence 16, 17); the spoken label carries the full
sentence at any size.

⑦ **THE EVENING'S OWN ACT OUTRANKS AN OFFER.** The close invitation
joins the list ABOVE the offered rows — it used to render last, where
the optional session pushed it behind the tab bar. Filmed fully visible
with receipts above and the offer below (evidence 13).

⑧ **THE SCRIM DERIVES FROM THE DEVICE** (kit-level, every tab page).
Solid through the window's real top inset + 28pt decay, instead of a
fixed 84pt. SE masthead crisp at rest (evidence 15); the
Dynamic-Island geometry keeps its p62 behavior.

⑨ **COPY.** "1 strength session in" → "1 session this week" (and
plural); method first-state → "notes come from your record" (5 words,
one line).

## 4 · Tried / rejected / refused

- **Refused to copy** the reference's streak counter, XP economy, gems,
  quest vocabulary (standing law: no streaks, never a grade).
- **Kept the dial carousel** (plates/numbers faces) — information the
  glance can reach; deleting hidden-but-honest surfaces wasn't this
  pass's mandate.
- **No permanent sticky CTA on Home** — the day's actions are the rows;
  a standing button would re-rank the whole page daily.
- **No section reorder beyond the evening close seat** — the 150th
  open depends on stable geography.
- **Entrance kept under ~1s total** and cold-launch-only; a warm app
  never replays it (the 30-day test: choreography that replays on
  every tab switch is noise by week two).
- **minimumScaleFactor on the wrapping dose headline** — tried, filmed,
  did nothing (scale floors don't engage on unbounded multiline text);
  replaced with the accessibility2 cap. The film decided.
- **The 0.5s arrival beat** — filmed as a beat of dead paper under the
  tab bar; trimmed to 0.38s and re-filmed clean.

## 5 · Session infrastructure notes (owned, not hidden)

- **ENOSPC fired again mid-pass** (the p68/p73 class): Xcode's global
  caches + 27GB of stale physical-device symbols left 1.5GB free, and
  an ENOSPC-era build wrote a TRUNCATED launcher stub (39,200 bytes vs
  58,128 healthy) while still printing BUILD SUCCEEDED — every fresh
  install spawn-failed with launchd error 163 until the bundle was
  deleted and relinked. Recovered by deleting stale iOS DeviceSupport
  (kept the founder's current 26.5.2), Previews caches and Homebrew
  cache (28GB free after). **Lesson for the standing list: after any
  ENOSPC window, delete and relink the Products bundle before trusting
  it.**
- **One simulator erase happened** (QA-iPhoneSE3) while chasing the
  spawn failure before the truncated-stub root cause was found — an
  erase I had intended to hold. Its next app launch mints one fresh
  anonymous bootstrap account (the documented §45 mechanism). No other
  sim was erased; no production data touched. Walking moved to the
  stock iPhone SE (3rd generation) sim afterwards.
- The `--uitest-persona-nogoal` calories-lead face could not be
  reproduced over the polluted QA account (protein floor survives from
  prior seeds); the calories branch of `dialCentre` is untouched by
  this pass.

## 6 · Proof

- **App unit suite: 1690 tests · 2 skipped · 0 failed.** Reconciled
  the hard way: 1,690 `func test` declarations in the target, 1,690
  executed — every declared test ran. Delta vs HEAD is exactly the 5
  new `BeatCompletion.doneTitle` pins (DelightTests 38 → 43). [CORR
  p74: its proof line says 1686, but HEAD as committed declares 1685
  app-target tests — the p74 figure was one high against its own
  committed tree; this pass counts declarations against executions so
  the number cannot drift again.]
- **PlankFood 319/319** (untouched by this pass; the p74 baseline
  exactly).
- **Release BUILD SUCCEEDED** (0 errors).
- Films/frames in `75_evidence/` (21 items), before/after for every
  change that moved pixels.
- Production: **no migration, no schema, no SQL, no deploy, no
  customer-row mutation.** One anonymous bootstrap account will mint on
  the erased SE sim's next launch (named above).

## 7 · Named, not done (device or future passes)

- Device checks: entrance feel at 60fps, ring trace + count-up on
  hardware, haptic timing of the receipt beats, strip trace under
  ProMotion.
- The words-only suppression face and the calories-lead face were not
  refilmed this pass (unchanged code paths; the polluted QA account
  blocks the nogoal persona — a `--uitest-wipe-targets` door would
  close this).
- The reference's "milestone checks pop as the fill crosses them" has
  one more natural home: the fiber mini crossing its dv. Unplaced —
  rarity is the law.
- p70–p74 standing lists.
