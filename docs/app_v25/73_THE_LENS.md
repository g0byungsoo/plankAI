# 73 — THE LENS

**feat/app-v2 · built 2026-09-03, after 72.** The standing mandate
(walk as a paying customer, both cohorts, fix classes) plus ONE
explicit founder direction: the Becoming time filter is a control,
not content — reconsider it end to end. Method: DriveUITests
walker-arm sessions on the iPhone 16 and SE QA sims at standard type
and AX5, every change filmed before/after, RED-thinking applied at
the seams that had one (the lens laws are pinned in a new suite).

---

## 1. THE LENS (the founder's direction, closed)

Filmed as-found: the time scope sat mid-page between the insight
carousel and the tile grid — six 13pt gray words with 2pt gaps,
selected-only ink, nothing marking the other five as controls. The
walker itself could not hit "month" (`NOTE tap month: not hittable`
then a coordinate tap that still missed —
`17_before_walker_missed_month.log`); one scroll and the control was
gone. And it half-governed the page: the BODY hero's chart obeyed the
scope while its provenance claimed "this week" under a year lens
(filmed, `02`).

The redesign, per the founder's law ("the filter is not content — it
controls the content"):

- **Placement + pinning.** The lens sits directly under the masthead
  and PINS while she scrolls (LazyVStack section header). Paper
  ground with a 10pt fade so content dissolves under it; while
  pinned the paper extends through the status bar
  (`ignoresSafeArea(.top)`) — the first cut left a 13pt ghost strip
  between the masthead scrim's solid stop and the pin (filmed `06`,
  fixed `05`). Apple Health's fixed range bar is the native
  reference; the pinned header keeps Jeni's scrolling masthead.
- **Form.** Every range wears the chip grammar's hairline capsule
  (p63); selected is the ink-fill morph (§5.4, matched geometry);
  14pt words at 44pt-tall targets on JKPress with the tick haptic.
  After the change the walker hit every range first try, five runs,
  zero misses.
- **The set: five, not six.** `today` left Becoming — a one-day lens
  cannot answer "am I changing?" (the page's three-questions job),
  and today's numbers already live on Home's dial, minis and set
  table. The enum case survives for one-day surfaces;
  `JeniScope.becomingLenses` is the pinned set. Five ranges fit the
  SE at standard type with no scrolling (filmed `16`); at AX sizes
  the row scrolls horizontally with the next chip peeking.
- **The lens governs what it stands over.** The insight carousel was
  "weekly by design, whatever scope the grid is set to" — defensible
  for a section header, a lie under a view-level control. Delta
  cards now compare the lens's own window (week vs last week, month
  vs last month via the same aggregator) and stand down where no
  previous window has a name (3 months / year / all — pinned); the
  kept-run card is a now-fact and stands at every lens. The hero's
  provenance speaks the drawn span. Sensor tiles whose rails read
  exactly one week (steps, movement, sleep) name their true window
  on their face under any other lens ("steps · this week") — the
  control's promise never exceeds the data behavior; widening those
  rails (HK queries over the lens window) is named, not done.
- **AX escape (§5.2).** At accessibility sizes the lens JOINS the
  scroll — a pinned band at AX5 spends the viewport the content
  needs.
- **VoiceOver.** The bar is a labeled "time range" container of real
  buttons with `.isSelected`; a pinned header lands LAST in the
  element tree, so sort priorities order masthead → lens → page.
  XCUI dumps don't reflect VO sort order — the device VoiceOver walk
  is on the device list.
- **Reduce Motion**: the capsule morph and the grid re-key both run
  under `withAnimation(nil)` — state changes whole.

Filmed: before ×2, after at top / pinned / every range on the 16, SE
standard, SE AX5 (`01–07, 13–16`). `BecomingLensTests` (3 tests) pins
the set, the windows and the delta-basis law.

## 2. AX IS A COMPOSITION, NOT A SQUEEZE (the founder's second theme)

SE·AX5 films of the changed pages caught six composition failures —
each fixed as a class, standard sizes untouched by construction
(every change gates on `isAccessibilitySize`):

- Becoming's lead grid stayed TWO columns at AX5 ("6,831 /" crammed
  against its own tile edge, `11`) → one full-width column (`14`).
- `BecomingMetricRow` scaled title+spark+value to their floors and
  still truncated mid-word ("sug… 35 g/…") → the row stacks (title
  wraps; spark + value share the next line).
- The masthead wrapped the date into a right-hanging orphan ("thu, /
  sep 3", `10`) → stacks under the title (`13`).
- `JeniTaskRow`'s note was trapped in the middle column — capped it
  censored itself ("water goes down eas…"), uncapped it wrapped one
  word per line → at AX the note takes the row's full width beneath
  the title line (`15`).
- Home's tool-row status capped at 2 lines censored its own fact
  ("down 10.6 lb since you st…", `12`) → p70's law, the cap yields
  to the words at AX.
- The hero door's chevron floated beside the first line of wrapped
  words → `.lastTextBaseline`.

## 3. THE PAGE HOLDS THE HEIGHT ITS JOB NEEDS (p72's named-not-done)

The movement tile's page was a full-screen cover holding four
sentences (p68's arrive-at-FULL law existed because a ledger hid
below the medium fold — with nothing below the fold it was dead
paper). Thin pages (no drawable chart, no comparison ledger:
movement, waist, body fat, every waiting row) now arrive as a modest
sheet (0.45 rest; drag up still reaches full; the v19 physics
untouched). The first cut's film caught the movement hero wrapping
to two 44pt lines restating the sentence below it — the value is
"1 session" now, the read carries the window (`08` → `09`).

## 4. ONE PRESS LANGUAGE (§5.1 debt)

24 `.buttonStyle(.plain)` word-buttons on shipped task surfaces were
press-dead: Home's care row + repair doors, food settings' "export
my data", the symptom sheet's day rows, the weight ritual's
type/remove/unit words, care correction + connection doors, the
visit packet's question actions, the weekly read's doors, the plan
numbers rows, the goal ritual, the program onramp ×5, chat's record
card, JFContinueButton's secondary word, the reading's "keep it".
All wear JKPress now. Deliberately untouched: the paywall
(do-not-migrate), DEBUG galleries, the dormant body-scan flow, the
workout module (retirement-gated), RatingSentimentScreen (rare
surface — swept later with its own film if it survives).

## 5. SMALL TRUTH/POLISH ALONGSIDE

- An insight card with no figure stops reserving the figure's 24pt
  void (filmed on the consistency card — the numeral and its
  sentence sit together now).
- The `deltaCard` figure buckets 3-day bars at the month lens so a
  two-month comparison stays legible.
- **The plate page's day door looks like a door** (found on the
  closing walk): the re-date row wore the exact shape of the two
  stat rows above it ("share of today's calories…") with nothing
  marking it tappable — a rotating disclosure chevron now, the chat
  record card's own grammar (filmed closed + open, `18`/`19`). The
  suite re-ran green after (1673 · 2 · 0).

## 6. WALKED AND SOUND / REFUSED, WITH REASONS

- **"read the whole week" under a non-week lens — KEPT.** The door
  opens the weekly read, a named destination (like "your
  weigh-ins"), not a claim about the chart above it; the page's
  chart labels its own span honestly. Renaming it per-lens would
  trade a stable object name for a moving one.
- **Scoping the steps/movement/sleep RAILS to the lens — REFUSED
  this pass.** It means new HealthKit query windows on the health
  rails (perf + provenance work), not a label change; the face now
  tells the truth instead. Named for a rails pass.
- **Auto-scrolling to the grid on a lens change — REFUSED.** Neither
  Health nor the App Store yank the scroll when a filter changes;
  the pinned bar means the change is visible wherever she is.
- **A "period" headline under the masthead — REFUSED.** The selected
  chip and every panel's span label already state the period; a
  second statement is a label explaining a control.
- **HomeSections' underlined "kcal · add your height" caption door —
  press fixed, underline KEPT for now**: it may be the §5.2
  banned-affordance class, but it sits inside the dial's dense mini
  row where a capsule needs a composition decision — named, with
  film, for the next pass.
- The p72 walk targets (stated day, recap ledger, regimen seat,
  reminders) were not re-walked beyond suite green — nothing this
  pass touched their paths.

## 7. VERIFIED

- **plankAITests: 1673 · 2 skipped · 0 failures** — p72's 1670 + the
  3 `BecomingLensTests`, reconciled exactly.
- **PlankFood: 319/319** — p72's exact count (no food changes).
- **Release BUILD SUCCEEDED** (final gate, after an ENOSPC mid-pass —
  the p68 disk class: stale Release/package derived-data trees under
  `build/` and `~/Library/Developer/Xcode/DerivedData/plankAI-*`
  deleted, ~16 GB; xcarchives kept).
- Films in `73_evidence/` (19 items). The walker missed ZERO taps on
  the new lens across five runs (one miss on the old bar, logged).

## 8. NAMED, NOT DONE

- Device VoiceOver walk of the lens order (sort priorities are set;
  XCUI can't verify VO order) + device feel of the pinned bar.
- The steps/movement/sleep rails still read one fixed week; a lens
  pass over those HK queries would let the whole grid obey.
- The sodium delta card is the only lens-aware insight; protein/
  fiber candidates exist in the same builder shape.
- The scope resets to `week` on relaunch (state, not preference) —
  deliberate for now; a remembered lens is a one-line change if the
  founder wants it.
- HomeSections' underlined caption door (above).
- p70–p72 standing lists (oral supply, SpokenDay V2 weekdays, §5.2
  underline ruling, food settings rose chips).

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases; production untouched (no SQL, no
`supabase db push`, no function deploys).
