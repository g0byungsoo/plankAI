# 21 — v2.6: the release-candidate pass

Date: 2026-07-03. Every prior "gate: founder taste" is now a shipped
v1 + a review note. Companion docs: 22 (Method samples), 23 (setup
ritual), 24 (notification orchestrator), 25 (weekly receipt).

## The six gates, closed

1. **Method content** — verdict: existing 84 slots are stronger than
   assumed; the gap was structural (closes had no rep). Four-beat
   structure defined; three closes live-patched (D03/D19/D25); seven
   staged with full copy in doc 22. REVIEW: read doc 22; the sweep
   is mechanical once you bless the structure.
2. **Setup ritual** — commitment page now answers all six questions
   (what/commit/today/jeni-carries/different/doable). Biggest call:
   the old copy said "starts tomorrow" while the mechanics start
   TODAY — fixed to "day one is *today*" (truth + day-0 activation).
   REVIEW: 91_setup_commitment.png.
3. **Reflection + chat sync** — day_reflections gains `note` (edited
   in the still-undeployed migration = zero prod risk); SyncService/
   AppSync upsert seam (fire-and-forget, silent until you migrate);
   the evening note now reaches jeni's context envelope
   (her_note_yesterday/today, 140-char cap) with persona guidance
   (reference gently, once, never quote at length). Chat transcript
   sync remains deferred (coach_messages table exists; client
   history is local-first by design this release).
4. **Notification freshness** — the repeating anchor became a 7-rung
   ladder of one-shots (anchor_d1..d7), each carrying THAT day's
   archetype line; rungs 3+ ease into begin-again register; ladder
   ends after 7 silent days (no zombie nags). Trial-end/promise/
   engagement pushes untouched (surgical removal on ladder + legacy
   ids only). Doc 24.
5. **Weekly receipt artifact** — built + exported (doc 25, shot 93).
   Register call: wax-seal receipt on cream, one glossy heart, ONE
   serif-italic jeni line, wordmark. ImageRenderer @3x → 1080×1350.
   "keep it" chain on the Sunday block; --uitest-force-receipt +
   --debug-weekly-receipt harnesses for QA.
6. **Legacy clusters** — REMOVED (PlanView, AnalyticsView,
   FutureRailCard, the --legacy-* flags, retired-surface debug
   harnesses). Rationale: two ledgers prove the new surfaces; the
   honest "before" is production build 22 on your own device. The
   launch loader's JeniAffirmations was extracted to its own file
   and survives. Remaining legacy in the app: onboarding v4.5
   (pre-existing separate gate) — nothing else.

## Production safety delta

- Server artifacts touched: the UNDEPLOYED migration file (added a
  nullable `note` column to a table that exists nowhere yet) and the
  UNDEPLOYED edge function prompt (persona lines). Deploy checklist
  in 13 unchanged in shape; re-run reading: still GO/GO.
- Client: notification changes preserve the removal discipline
  (verified id lists); no gating/auth/RevenueCat surface touched.

## Ship checklist for the founder

1. Review shots: 91 (commitment), 92 (Sunday block), 93 (the card).
2. Read doc 22; bless the four-beat structure.
3. Run the migration, deploy jeni-chat (13_DEPLOY_SAFETY).
4. Device pass; production build 22 is your before.

## Release blockers vs nice-to-haves

**Blockers:** none known in the app itself. The chat tab requires
the EF deploy to go live (mock covers QA); food photo→text context
awaits the food-vision deploy — both founder-credential actions, not
code.
**Nice-to-haves (post-RC):** Method full-content sweep (doc 22
template) · chat transcript cloud sync · per-user anchor minute
jitter · receipt card on-canvas week-dots · ♡→♥︎ manifest sweep.
