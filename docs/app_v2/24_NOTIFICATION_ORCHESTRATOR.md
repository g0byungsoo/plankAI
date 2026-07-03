# 24 — Notification orchestrator (v2.6 RC)

## The ladder
Seven one-shot anchors (ids anchor_d1..anchor_d7), rebuilt once per
day on Today's first refresh. Each rung fires at her preferred hour
with THAT day's line: tomorrow-relative archetype voice on rungs
1-2; begin-again register from rung 3 ("the plan kept your place.
begin again, anytime ♥") — because day 3+ of silence is a comeback
moment, not a reminder moment. The ladder ENDS at 7 silent days: no
zombie nags; lapse-recovery is the winback intent's job (unbuilt,
scoped in 09).

## Why a ladder beats the repeating trigger
The v2.5 repeat spoke ONE line forever if she stayed away (staleness
bound). The ladder gives seven distinct, decaying-urgency lines and
then respectful silence. Every open re-anchors the whole week.

## Discipline (unchanged guarantees)
- Removal set = ladder ids + legacy ids (daily_reminder, daily-plank)
  ONLY. Trial-end (trial_ending), day-1 promise (day1_promise),
  day-2 engagement, day-5 anti-refund: never touched — verified by
  id-list inspection.
- Respects notificationsEnabled + authorization; no-ops for
  unenrolled/completed programs; once-per-day guard.
- Bodies follow the notification voice memo: no labor verbs, no
  streak threats, name-prefixed, lowercase, text-hearts.

## Deep link
Every rung carries jenifit://today (NotificationDelegate routes
through AppRouter, queued until .main).
