# 17 — Feature evaluation (v2.4, first principles)

Format per feature: problem → role → rationale → direction → jeni
integration → metric → risk. Verdicts feed 18_V24_REDESIGN_PLAN.

## 1. Breathwork — REFRAME (implemented v2.4)

**Problem:** performs mechanically (69% completion) but is framed as
a wellness module ("settled/sleepy/steady/awake" doorways) — a
meditation-app clone inside a weight program. Nothing connects it to
the moments this audience actually needs it: cravings, stress
eating, post-binge spirals, food noise, begin-again.
**Role:** the nervous-system brake — the tactical reset between urge
and action. **Rationale:** urge-surfing is core CBT for emotional
eating; physiological sighing downshifts arousal in ~60s (Balban
2023); interrupting the urge-action chain is relapse prevention 101.
**Direction:** the doorways speak the real moments ("a craving
wave" / "before i eat my feelings" / "the day went sideways" /
"begin again"); protocol receipts connect the exhale to appetite and
noise, not generic calm. The session mechanics don't change — they
work. **Jeni:** craving language in chat routes to the reset tool;
the EF persona knows breath is her brake, not her spa. **Metric:**
breath sessions started from chat/craving contexts; same-day
logging-resume after a reset. **Risk:** copy-only + prompt line; low.

## 2. Workouts — THE FIVE-MINUTE FLOOR (implemented v2.4)

**Problem:** 59% try, 26% ever complete. The celebration and brief
were rebuilt (v2.1-2.3) but the core objection is the ask itself:
10-15 minutes feels like a project to a beginner having a low day.
**Role:** lean-mass insurance + the daily proof she shows up.
**Rationale:** exercise adherence literature is unambiguous — the
minimum viable session beats the optimal session she skips;
GLP-1 lean-mass preservation needs resistance CONSISTENCY, not
volume. **Direction:** every workout brief carries a second door:
"make it 5 minutes" — one tap regenerates today's session at the
floor. No guilt gradient between doors; the receipt rows already say
"pause or end anytime." **Jeni:** "i don't have energy today" →
suggests the floor version. **Metric:** workout completion rate by
users who saw the floor option; sessions/wk. **Risk:** low — reuses
WorkoutGenerator with lengthMinutes: 5.

## 3. JeniFit Method — READ → DO (chain implemented; content pass scoped)

**Problem:** widest-reach surface (99% of purchasers) but a
lesson is a dead-end read (completion events 19%; module returns
home). Knowledge without a next action decays by dinner.
**Role:** the cognitive layer — why her brain does what it does.
**Rationale:** CBT works through practiced skills, not psycho-
education alone (Cooper 2010's sobering long-term data is exactly
why lessons must end in behavior). **Direction:** lesson completion
chains into ONE related action on Today ("next: 60 seconds of
breath" / "snap tonight's plate") via the chain line — the read
becomes a rep. Content depth (rewriting slots for deficit/protein/
GLP-1 realities) is a founder-present content pass: 84 slots ×
4 pages is authored voice, not chrome. **Metric:** action-within-
1h-of-lesson rate; D7 retention of lesson-readers. **Risk:** low
(chain) / medium (content pass — deferred with reason).

## 4. Food log — a nutrition MEMORY (v2.2 rows hold; day receipt next)

Rows are photo-first, protein-only at rest ✓. Next lever (scoped,
not this session): per-day receipt line ("84g protein · 3 plates ·
fits") replacing raw kcal-total headers + "ask jeni about this day."
The anti-pattern to keep resisting: any macro table at rest.

## 5. Calorie snap — SIGNATURE; protect and extend

Already the strongest surface (capture → carousel → note → share).
v2 wired the canonical protein target + dietary resolver + archetype
hint. Extend-later list: post-log chain ("dinner idea?" seed),
pattern recognition over weeks (InsightEngine already reads the
store). Nothing to fix now; the 26% scan-fallback rate is the
food-vision DEPLOY, not design.

## 6. Protein/nutrition — protein is the score

One formula everywhere (TargetsService ✓), arc as the hero ✓, kcal
as a sentence ✓. GLP-1 sees her floor with the lean-mass note ✓.
Nothing generic left; resist adding rings.

## 7. Weight log + trend — jeni interprets the scale ✓ (v2.1)

Trend story + mechanism lines shipped; brief reacts to deltas;
uptick script defuses panic. Next (scoped): the post-save moment in
LogWeightSheet could whisper the interpretation immediately instead
of waiting for the next brief. Deferred: small, but touches a
shared sheet used by 3 hosts — batch with the notification pass.

## 8. Steps — the easiest lever ✓ (v2.2 sheet)

Honest HealthKit states + the frame line. Resist gamification.

## 9. Journal/reflection — one grammar, later

Evening close's one-tap feeling + reader's JournalingPad + chat all
capture reflection. Unify into "her notes" under Becoming when the
day-reflections table ships client-side (v2.1 of sync). Documented,
not built — three capture points already exist; a fourth surface
without unification would be clutter.

## 10. Chat tools — add the brake, keep the bar high

Seven tools shipped. v2.4 adds craving routing (persona guidance —
breath tool already exists client-side). Bar for new tools: must
either mutate real state or navigate; no decorative cards.

## 11. Daily program — the spine holds (v2 engine)

Beats vary by day/tier/cohort ✓; weigh-in cadences ✓; caps at 5 ✓.
Watch-item: rest-day content for non-stressed users is thin (breath
+ lesson + steps) — correct per "rest is the assignment."

## 12. Program setup — chrome unified (v2.3); ritual pass with founder

It writes the plan; the deeper redesign (making enrollment feel like
the onboarding's commitment ritual) needs founder sign-off on copy +
flow order. Concrete, scheduled, not vague.

## 13. Settings — premium enough, stop touching

Walker-verified, both-tab reachable, sub-screens on register.

## 14. Notifications — spec'd, next pass

Orchestrator consolidation (09) remains the plan; delegate + deep
links shipped. The daily anchor should read the brief engine (same
line in push and in app) — that's the implementation's core.
