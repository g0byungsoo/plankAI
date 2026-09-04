# 80 — THE LIVING PRODUCT

**feat/app-v2 · opened 2026-09-04, after 79.** The brief: keep
iterating until the product AND the experience deserve each other —
beautiful, responsive, useful, distinctive — with an explicit founder
challenge to the current large-editorial typography on the
Becoming / weight / dose surfaces ("multiple large text blocks
competing for attention" vs real composition), and a named
investigation into epistemic grammar (fact vs derived read vs personal
pattern vs population context). Method: read p79 + its four research
lanes, then a cold walker-arm drive over the GLP-1 persona across every
surface, screenshots + a11y dumps, before deciding anything.

## 1 · The cold critique (walked, GLP-1 persona, standard type)

Surfaces walked: morning letter → Home (rest + full scroll) → Becoming
(rest + full scroll) → weight detail → regimen/dose sheet → scan
chooser → words-door reading → chat. Screenshots in `80_evidence/`.

### The dominant class: TYPOGRAPHY-AS-COMPOSITION on Becoming (the founder's exact challenge)

Becoming's week view is a vertical STACK OF SAME-WEIGHT HERO CARDS —
four white cards, each leading with a large serif numeral, each with
its own eyebrow:

- **BODY** — `181.2 lb` (JeniHeroSerif 34pt) — legitimate hero.
- **YOUR DOSE** — `1 mg` (serif 22pt) — its own full-width white card.
- **YOUR BURN** — `1,225 to 1,625` (serif 22pt) — its own full-width
  white card.
- an insight card — **`down 35%` vs last week** (huge serif) for
  **SODIUM**, with bars, full-width — competing at hero scale.

Ask the founder's question — "what is the ONE thing this surface wants
me to notice?" — and the week view has no answer. Everything is a hero.
Worse: **sodium renders twice** — once as the giant "down 35%" insight
card near the top, and again as a `1,068 mg` row far below. And a
sodium drop is not news a GLP-1/weight-loss customer needs at hero
scale at all (the silence test: obvious, not actionable, duplicated).

The dose and the burn are not co-heroes — they are the *context* that
explains the body trend for a medicated person (dose era = the
category's most-asked read; burn = what her body runs on). They earned
a place, not a hero card each. The screen uses type size where it needs
composition.

### Secondary finds (walked)

- **Home: `the method` appears twice** — once as a large tool card
  ("the method · a 2-minute read") and again as a tools-index row
  ("the method · notes come from your record"). Genuine duplication on
  the most-seen surface.
- **Chat register** — "on 1 mg, you've lost 7.4 lb over 8 weeks. that's
  a solid progress! it looks like this dose has been effective for you.
  are there any specific aspects you want to discuss…" — the generic
  AI-coach voice with trailing questions and praise that R3 names as
  the retained products' anti-pattern. EF-deploy-gated (standing since
  p77); the client can't fix the server prompt this pass.
- **The words-door reading is well composed** (protein lead 40g · kcal
  520 · unmeasured macros as "—" · "600 left today after this") — kept.
- **Weight detail + regimen/dose sheet are strong** — clean single-hero
  composition, real hierarchy; left alone.

## 2 · What shipped

### ① THE BECOMING HIERARCHY REBUILD (flagship — the founder's exact challenge)

Becoming's week view stopped being a stack of four same-weight hero
cards. It now forms one hierarchy:

- **ONE hero** — the BODY card (weight, trend sentence, sparkline,
  "the whole story" door). This is the page's reason to exist: "am I
  changing?"
- **A quiet context caption beneath it** (`bodyContext`, replacing the
  p74 `doseSeatCard` and p79 `burnCard`): the dose era and the learned
  burn read as a caption to the hero — bare on the paper (no white
  card), in DMSans (never the hero serif), one tier below the hero's
  surface. The dose line ("1 mg · week 9 at this dose" over "down 7.5
  lb · 8 wks") is still tappable into the medication page through the
  exact p74 morph (frame reported, opacity-gated, verified navigating —
  evidence e07). The burn line ("your burn runs 1,225 to 1,625 a day"
  over its derivation) is a plain fact, no door (p79's refusal stands).
  A weight-loss customer with neither sees nothing here and the hero
  stands alone.
- **THE SODIUM HERO IS CUT.** The Becoming insight builder rendered a
  sodium week-over-week delta as "down 35%" at hero-serif scale in a
  full-width card, landing directly under the body/dose/burn stack AND
  duplicating the sodium row the page already carries below (its own
  deltaWord whispers there). Sodium is not a metric this customer
  manages, ±8% is ordinary daily noise, and the water-weight teaching
  it carried already lives in the weekly read when it matters. The
  silence test: obvious, not actionable, duplicated → cut. Its dead
  builders (`deltaCard`, `dayLetter`) went with it (git holds them).

The result (evidence 04): one white hero card, then quiet context,
then the CALORIES/PROTEIN pair, then the chemistry rows. There is now a
clear answer to "what's the ONE thing to notice?" — the body trend —
and the dose and burn are visibly *context*, not co-heroes. The
composition carries the hierarchy (card vs bare caption · serif vs
DMSans · size · position), not typographic bulk. Verified at standard
type (e03), AX5 (the caption wraps gracefully, hierarchy survives —
evidence 07), Reduce Motion (identical composition — the change adds no
motion-dependent meaning), and the dose tap-through (e07).

### ② THE EPISTEMIC GRAMMAR OF THE FELT WEEK (the founder's named investigation)

The founder quoted p79's waning line — "day 6 of your dose week.
appetite often comes back in this stretch." — and asked whether that is
the right way to speak. Ruling: it was close but blurred. Both the
personal-pattern and the population branches opened identically ("day N
of your dose week"), and the epistemic register was then carried only
by a weak word. The population line read as a claim about HER appetite
(she is hungry on day 6, reading a sentence addressed to her); "often"
was too soft a population marker.

The fix makes the two registers grammatically parallel and lets the
**italic accent fall on the epistemic marker itself**, so the reader
instantly knows whose pattern it is:

- **Population** (her record hasn't shown the pattern): "day 6 of your
  dose week. *many people* get hungrier toward the end." — "many
  people" carries the italic; the statement is unmistakably about
  people and about the week's shape, never a claim about her body
  (evidence 06, filmed in the real letter chrome).
- **Personal** (her record holds the food-noise signature): "day 6 of
  your dose week. *in your last cycles*, food noise came back around
  day 6." — "in your last cycles" carries the italic; grounded in her
  own record.

The chat seeds carry the register forward explicitly (speak THEIR
pattern vs the POPULATION shape). Banned-verdict register unchanged and
still pinned (never failing/tolerance/working/next-dose). This directly
answers the founder's rule: never make her interpret whether a
statement is about her or about people in general.

### ③ THE CHAT REGISTER — PREPARED, NOT DEPLOYED (walked finding)

The live EF chat produced the exact anti-pattern R3 names in the
retained products: "on 1 mg, you've lost 7.4 lb over 8 weeks. that's a
solid progress! it looks like this dose has been *effective* for you.
are there any specific aspects you want to discuss…" — three faults:
(a) **a clinical efficacy verdict** ("this dose has been effective for
you"), which is a medical redline and R2's forbidden judgment ("is it
working?" is the clinician's call); (b) inflated praise ("solid
progress!"); (c) a vague trailing homework question. The system prompt
already forbade these in spirit but not by explicit example, and the
model wasn't obeying. Two sharpened rules added to
`supabase/functions/jeni-chat/index.ts` (evidence 03 is the as-found):
a hard redline against ever judging the medication "working / effective
/ the right dose" (show the trend and record, route the verdict to the
prescriber), and a voice rule banning vague open trailing questions and
inflated exclamation-praise. **Source only — NOT deployed** (founder's
EF-deploy gate; `deno check` shows the same 3 pre-existing errors as
HEAD, zero introduced).

## 3 · Refused / deferred, with reasons

- **A card for the dose+burn context** — considered; refused. A white
  card says "hero object." The founder's own "do not assume a card is
  the right container" applies: bare-on-paper caption is the correct
  figure/ground (one white hero, its caption beneath) and the strongest
  subtraction.
- **Pairing dose+burn as two half-width cards** (matching the
  CALORIES/PROTEIN tier) — considered; refused. The burn band
  ("1,225 to 1,625") is too wide for a half card, and two more cards
  would still read as cards, not context. The caption is quieter.
- **Home's "the method" duplication** (a today-action beat + the tools
  destination row) — left. Both placements are defensible (a JITAI
  today-note vs the persistent library door), and removing either
  trades one inconsistency for another (method missing from the tools
  footer, or a real today-action deleted). Noted, not forced.
- **Adding `.contentTransition(.numericText())` to the dial** — not
  needed; the Home dial already carries it in four places
  (HomeSections 408/549/665, HomeView 963). R4's numericText gap is
  already closed on the most-seen surface.
- **The dead tail below the last Becoming/Home row** — it is the
  floating-tab-bar scroll clearance (Spacer 120), not a void to fix.
- **Deploying the EF prompt** — founder gate, unchanged.

## 4 · Verified

- `app` **1739 · 2 skipped · 0 failed** (exactly the p79 baseline —
  the epistemic change edited existing DoseWaningBriefTests pins in
  place, the Becoming change altered composition/copy not contracts;
  no net new tests). `ExpenditureReadTests` 16/16 · `BecomingStoryTests`
  12/12 · `WeeklyReadOffersTests` 23/23 · `DoseWaningBriefTests` 7/7
  (with the new italic-epistemic-marker assertions).
- **Release BUILD SUCCEEDED** (unsigned, generic iOS).
- `PlankFood` untouched this pass (byte-identical to p79; 321/321
  stands — the full app suite links it and passed).
- Films (80_evidence): the stack-of-heroes as found (01) · Home method
  twice (02) · chat register as found (03) · the rebuilt one-hierarchy
  Becoming (04) · the glp1waning Home (05) · the waning letter with the
  new epistemic line in real chrome (06) · Becoming after at AX5 (07).
  Plus dose tap-through to the medication page (session shots e07).

## 5 · Named, not done

- The EF prompt refinement is prepared, not deployed (founder gate).
  Its effect can only be seen after a deploy + a live chat.
- Home's "the method" duplication (documented above) — a product call
  about whether the JITAI today-note should present distinctly from the
  tools destination; left for a Method-side pass.
- The Method note's own waning line (`MethodCatalog` "often the hungry
  end of it.") and BrandVoice's "appetite often comes back about now"
  carry the same population register the DailyBrief line just tightened;
  aligning them is a consistency sweep, deferred (the morning read is
  the flagship moment and is done).
- SE-viewport films of the rebuilt Becoming (AX5 verified; SE is the
  lower-risk composition, the standing p78 note).
- p70–p79 standing lists.

**No migration, no schema, no SQL, no deploy, no production mutation.
NOT ARCHIVED, NOT UPLOADED, NOT SUBMITTED.**
