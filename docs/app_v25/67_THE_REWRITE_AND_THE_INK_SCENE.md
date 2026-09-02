# 67 — THE REWRITE + THE INK SCENE

**feat/app-v2 · built 2026-09-02, after 66.** The founder's
propagation brief: carry p66's quality through the rest of the
product — rewrite Jeni's voice (the biggest remaining problem),
continue the minimalism sweep, extend the doodles, and bring the
onboarding's cinematic language in-app as a deliberate transition
grammar with intentional dark scenes. "The current implementation is
not the specification."

Method: git state recorded (`936f412`, clean, synced). Three
parallel inventories before any change — the full poetic-copy audit
(15 surfaces ranked, every test pin named), the consult's exact
transition choreography (token by token, file:line), and the
complete shipping-screen inventory (graded against the p66
standard). Then the product walked on the QA sim (Home, scan
chooser, BOOK, Move, method note, Becoming, desk, regimen, dose
sheet, weigh-in, evening close) and **the real onboarding filmed
end-to-end** (the walker drove it while the sim recorded; 777
frames; the ink flips located by per-frame luminance) before the
grammar was designed. Every consequential change was re-filmed.

---

## 1. THE REWRITE (§11 rewritten — the new writing law)

The founder named the defect: too much of the product speaks in a
poetic register that makes simple information ceremonial ("your
record starts here." · "floor covered." · "the heavy work is on
file" · "tomorrow's morning read is built from what you give me
today."). The new hierarchy: **DIRECT · SHORT · USEFUL · HUMAN**,
then encouraging, occasionally witty. Every line answers WHAT
HAPPENED / WHAT MATTERS / WHAT DO I DO / AM I DONE.

**The vocabulary rulings (product-wide, user-facing):**
- "the floor" → **"protein goal"** ("goal hit", "X g to go"). The
  dial's center — the most-seen string in the app — now reads
  "85 · g protein to go" (it read "g to the floor", the product's
  internal jargon, at the highest-traffic site).
- "on file" / "on the record" → **"logged" / "saved"**, or just the
  fact. The ceremonial eyebrow "on file." died.
- **THE PRAISE AMENDMENT** — the p63-era banned list split. Warm
  words (nice, great, done) are sanctioned for real ADDITIVE acts
  and rationed at celebration sites; grading words (bad, failed,
  too much, not enough, over, behind…) stay banned forever. The
  engine's refusal comment now names the line: praise the act,
  never the food, never restriction.
- Aphorisms became plain statements or died ("goals that move with
  your own weeks are the ones that keep." → "your step goal now
  follows your own real weeks.").
- **Twenty sites that held a number and wrote around it now say the
  number** (the close's mid protein gap says "35 g to go"; Move's
  receipts count "1 of 2"; the desk says "today: 3 plates, 76 g of
  protein.").

**Keystone rewrites (all pinned suites updated in the same
commit):** PlateAnswerEngine (first-ever: "nice. your first plate,
logged."), the moment payloads (crest: "protein goal hit." + "nice
work." once a day by the crossing's own construction), the evening
close (met: "protein goal hit. nice work today."; terminus:
"logged. tomorrow starts fresh."; the anchor's poetic tails cut),
Move's receipts and empty state ("connect health and your walks
count themselves"), the morning read, the weekly read's
observations + teachings, the desk ("ask me anything about your
day."), the method catalog's flagged notes, retention +
orchestrator pushes ("the line misses you" → "a 30-second
weigh-in?"), Becoming's tiles + empties, weigh-in receipts,
first-plate surfaces, the day-one contract ("saved. tomorrow
morning i'll read it back to you." — the value shape, directly),
the BOOK's week words, PlankFood's result lines. The week-intent
"the floor first" became "protein first" (it renders on the
dateline).

Clinical register untouched by design: dose standing, ledgers,
side-effect vocabulary, 988 copy, label facts.

## 2. THE INK SCENE (§4.8, new law)

The founder's ask: study the onboarding's transitions ON FILM, then
derive a small grammar — not a black fade between every navigation.

**What the film showed** (frames in `67_evidence/`): the consult
never slides — the WHOLE SURFACE crossfades to ink over 0.55s with
content crossfading slightly faster underneath; a held beat before
new ink speaks; typography arrives after the surface settles; the
return to paper is the same move reversed. Four ink scenes in the
whole consult — rarity is the effect. The in-app product had ZERO
ink surfaces and every ceremony cover arrived as a hard cut.

**The grammar built:** `JeniScene` (warmHold 0.35 · flip 0.55 ·
exitFlip 0.40). A ceremony cover mounts on the same paper as the
page beneath (the cut disappears), holds one beat, flips to ink,
speaks, then returns to paper before leaving. Three arrivals now:
ASSEMBLY (ordinary), SPEECH (acts), SCENE (ink ceremony).

**Where it landed, by the tier system's own rule:**
- **The celebration page** — crest and moment tiers go dark; the
  shower's rose flecks against ink are finally a celebration (the
  ink-accent flecks swap to paper via `JeniBurst(onInk:)`; the CTA
  inverts to the consult's paper pill via `JFContinueButton
  (inverse:)`). Spark stays paper — several-times-a-week stays
  light.
- **The evening close's goodnight** — the day literally ends in the
  dark: "goodnight" flips the surface to ink as "that's the day,
  maya." speaks, dwells, then paper returns before the cover
  leaves.

Film-caught and fixed: the clock rendered ink-on-ink (scene-scoped
`.preferredColorScheme(.dark)`); the exit flip re-showed the
close's content for a beat (the receipt now stands through the
return). Reduce Motion arrives ON ink — a state, not a motion.

Deliberately NOT flipped: the weekly read, the letter, breathwork,
ordinary navigation, utility sheets. Candidates stay named for a
later judgment by film; a dark screen for variety is the gimmick
the law now names.

## 3. THE MINIMALISM SWEEP (the weakest high-traffic screens)

From the graded inventory (every shipping screen, 1–5 against the
p66 standard):
- **DoseSheet (was 2.5)** — the GLP-1 loop's most important write
  was a hand-rolled 54pt rectangle mid-scroll with "not today" as
  an underlined caption. Now: the standing CTA pinned in the thumb
  zone on its own paper fade; the skip rides the secondary slot;
  reasons open between the pinned bands; the label morphs to
  "taken" and stands through the commit dwell (filmed end to end —
  sheet → mark → morph → the Home row compressing to "today's
  shot, done").
- **SideEffectSheet (was 2.5)** — "done" was the least prominent
  thing on the page, under a 13-pill cloud. Pinned.
- **PlateDetailSheet (was 2.5)** — the most-linked food page had no
  bottom-anchored decision ("log it again" was row six; fix/remove
  were caption capsules at the scroll's bottom). Now: "log it
  again" is the standing CTA (the E4 again-loop is the page's
  most-used act), "off? fix this plate" is its secondary, remove
  stays quiet with the honesty block.
- **RegimenSheet (was 1)** — the four page-level underlined-caption
  links ("not taking it right now", "+ add a past shot", "starting
  again? set it up", "something look wrong?") wear the chip grammar
  now. `JeniQuietCapsule` joined the kit as the NAMED secondary
  label so the web-link affordance cannot reappear; a shipping
  em-dash ("this shot — 0.5 mg") died in the same edit.
- **EditProfileView deleted** (~106L + pbxproj): zero live call
  sites since the hub re-routed "my pace"; its only callers were
  comments.

## 4. THE ILLUSTRATION REGISTER (three more empties)

`JKEmptyState(doodle:)` reached what-jeni-told-you (book),
what-jeni-remembers (user), and the weigh-in ledger (scale). The
desk deliberately did NOT get one — it already carries the j mark
as its identity; two illustrations compete. Dense instruments still
never earn one.

## 5. THE INTERRUPTION REVIEW (with the new writing law)

The p66 policy held; the copy pass made the value shapes literal:
the day-one contract now SAYS the exchange ("saved. tomorrow
morning i'll read it back to you."), the method notes keep
noticed → because → action with the numbers stated, and the
retention pushes name the ask and the payoff instead of the mood
("a 30-second weigh-in? one quiet morning keeps your trend honest").
No interruption was added; none needed removing beyond the copy.

## 6. DECIDED AND REFUSED

- **The close's large protein gap stays number-free** — the
  anti-shame refusal outranks number-showing when the gap is a
  rebuke (>40 g); the mid band (26–40 g) now says its number.
- **The desk gets no doodle** (identity mark already present).
- **doseDay's "the week starts here" kept** — four plain words
  carrying real information (the dose anchors the week), not
  poetry.
- **"a quiet day. it still counts." kept** — warm, true, nothing
  to state.
- **Home keeps no single CTA** — it is a control center; its job is
  the day, not one action (the p59 founder-steered design holds).
- **Weekly read / letter / breathwork ink scenes deferred** — named
  candidates, each wants its own filmed judgment, and four dark
  surfaces in one pass risks the gimmick the law bans.

## 7. VERIFIED

- **plankAITests: 1659 total · 2 skipped · 0 failed** (the exact
  p66 baseline count — the pass changed words and structure, not
  behavior contracts). The full suite's first run failed 17: the
  four remaining pin clusters, including **the p54 fingerprint
  tripwire doing exactly its job** — ten method notes' words
  changed, so ten `version` bumps + `MethodCatalog.version` 2→3 +
  ten re-pins, deliberately.
- **PlankFood: 291/291** (ResultDetailCopy edits covered).
- **Release BUILD SUCCEEDED.**
- Filmed: the consult's real ink flips (the study the grammar came
  from) · crest + moment ink scenes end to end · the goodnight
  terminus twice (exit artifact caught + fixed) · the dose mark
  ceremony · Home + close rewrites. Evidence in `67_evidence/`.

## 7b. ROUND TWO (same pass, after the first push)

- **CareConnectionSheet**: the consent revocation ("turn off my
  clinic's access") and the connect door wear the chip grammar; the
  press-dead hand-rolled continue became the standing CTA.
- **VisitPacketView**: "share as pdf" — the page's one job — is the
  pinned standing CTA.
- **SnapResultView**: "add it" owns the full thumb zone; retake and
  share became quiet words above it, and the word is door-aware
  ("start over" on a typed plate — film-caught on the words door).
- **The whole loop driven live**: chooser → typed words → the
  reading → "add it" → a REAL crossing → the crest ink scene with
  the shower → continue → Home resting on the drawn check +
  "goal hit". Filmed end to end on the shipping pipeline.
- **AX5 filmed**: the dose sheet's pinned pill holds one line and
  content fades beneath the sticky band; the ink scene wraps
  whole-word with the inverse pill intact. Reduce Motion's
  arrive-on-ink path stays a named device check (sim RM toggling is
  not scriptable here; the path is state-not-motion by
  construction).

## 8. NAMED, NOT DONE

- **Device checks**: the ink flip's feel at 60fps over real
  content, the shower on ink, the inverse pill's shadow.
- **The remaining weak screens**: CareConnectionSheet (grade 1.5 —
  zero real buttons on a consent surface), VisitPacketView ("share
  as pdf" is an underlined header caption), NotificationSettings'
  200pt UIKit wheel, AccountView / FoodSettingsView structure,
  RegimenSheet's full split (home vs ledgers vs editors),
  SnapResultView's flanking circles.
- **Ink-scene candidates awaiting film**: the weekly read's
  chapter, the letter, breathwork's session.
- **The copy long tail**: onboarding untouched by design (its own
  register); ResultDetailCopy's remaining GLP-1 note variants;
  chat/coach envelope prose.
- p66's standing list (SPM extraction, haptics door migration,
  spacing/type lint, breath/session moments, PressFeedbackStyle).

**No migration, no schema, no production mutation, no deploy. NOT
ARCHIVED, NOT UPLOADED, NOT SUBMITTED.** Standing QA identities
reused; no sim erases.
