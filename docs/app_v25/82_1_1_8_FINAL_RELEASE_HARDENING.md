# 82 · 1.1.8 FINAL RELEASE HARDENING

**Built 2026-09-07, after 81.** The founder's brief: the final
comprehensive product + engineering hardening pass before 1.1.8 is
archived. Marketing version decided: **1.1.8**. Cold start, whole-product
walk, six+ parallel audit lanes, fix what is material, stop at the
archive/upload/submit/deploy boundary. Evidence in `82_evidence/`.

**THIS SECTION IS THE WORKING RISK MAP — rewritten into the final
record at pass end.**

---

## 0 · Initial release-risk map (as discovered; classification per brief §0)

### RELEASE BLOCKER

- **N-F3 · Medication reminders survive account deletion / sign-out /
  Apple-credential revocation.** No sweep site removes
  `MedicationReminders.allIds`; the weekly/daily reminders are
  REPEATING triggers, so "today's your shot day." fires indefinitely
  on the device under the next identity after the account is gone.
  Health-category lock-screen content surviving deletion = the
  p37/p38 deletion-law class. (AppSync sweep sites + MedicationReminders.)

### MATERIAL BEFORE SHIP

- **T-D1 · The dose-backfill door defaults to "took it just now".**
  "+ add a past shot" → DoseSheet preselects the just-now chip; an
  untouched confirm records `takenAt = now`, re-anchoring CyclePosition
  and the interval chain to TODAY — the exact opposite of the door's
  premise. Fix: seed `lateTakeDayKey = slotDayKey` when opened from the
  backfill grid. (DoseSheet.swift:45,254,645; RegimenSheet backfill.)
- **N-2a-i · Weekly + daily dose reminders re-fire on a resolved slot.**
  Repeating calendar triggers have no resolved-today awareness; the
  morning-marked shot still gets "mark it when it's taken." that
  evening, every week. The interval branch already models the fix.
- **N-F1 · `markSessionCompleted` re-arms winback/day1 with master
  toggle OFF** (RetentionNotifications) — "master off means off" (p54).
- **N-F2 · Food-settings evening-review toggle schedules without the
  master toggle or OS-auth check** (FoodSettingsView → RetentionNotifications).
- **C-1 · Chat consent sheet's disclosure omits the menstrual-cycle
  phase** (and name/meals/consult texture/memories) that the envelope
  actually sends — 5.1.2(i) sensitivity class; copy-only fix
  (ChatAIConsent.swift:65 vs CoachContextAssembler.swift:94-107).

### PRODUCT QUALITY (candidates; triage below)

- T-D2 · THE BOOK prints tell-time as meal-time on backdated plates
  (needs a persisted tell-clock flag in payload jsonb + display rule).
- T-D4 · Moving today's only plate off today leaves the food beat
  marked done.
- T-D3 · Day-moved plate's HK dietary sample stays on the original day.
- T-C1 · A past-day weigh-in cannot be ADDED in-app (largest remaining
  retro asymmetry; workaround = Apple Health).
- T-B1 · Camera Snap has no "when" affordance; day-move is post-file
  only, undiscoverable from the reading.
- T-D6 · PlateDetailSheet dayWord formatter unpinned (locale).
- N-2a-v · Lock-screen "taken" on a stale reminder files today, not
  the open slot.
- N-§4 · day-5 onGlp1 body "…it's working" register brush.
- N-2d · Re-signing knock can re-arm the same evening after signing.
- D-F1 · JeniMethodState: 4 of 5 keys in no sign-out sweep (§38 class).
- D-F5 · retryPendingUpserts not uid-scoped → permanent 403 loop after
  an account switch (noise, RLS holds).
- C-2/C-3 · read_dose_history lacks a dated last-dose key;
  doors.medication doesn't name the backfill door (payload-only).
- C-4 · EF prompt still permits ♥ the client always strips (prepared-
  source edit; deploy stays founder-gated).
- H · HK dietary-energy toggle stays ON after write-denial (dead-knob
  class); sleep grant unreachable post-onboarding (dead requestAccess);
  HRV/cycle/leanMass structurally ungrantable for onboarding-granted
  users; reinstall loses movement/bodyMass request flags.
- W-1 · Becoming "22.4 lb to go" vs Settings goal 159.8 lb (implies
  158.8 vs 159.8 — chase: two goal reads or trend-vs-raw mix?).
- W-2 · Settings "my pace · not set" on a day-16 paced plan (chase:
  which key does the row read?).
- W-3 · Becoming movement thin page says "from apple health" — verify
  it has a denial branch (MoveSheet does).
- W-4 · Chat tool answer "averaging 368g protein" vs BOOK's ~60-104g
  days (probably QA seed pollution in an old transcript bubble —
  verify read_food_week arithmetic against a clean seed).

### SAFE TO DEFER (verified, named)

- SIWA token revocation: **deferral re-verified on fresh evidence** —
  TN3194 (2025-10) explicitly blesses the implemented no-token
  fallback (all three steps present in code); 1.1.7 approved with this
  exact shape; the staged B1/B2 server package carries a schema/ACL
  defect (private-schema table PostgREST cannot reach; no service_role
  grants) and must be revised before ANY deploy — founder list.
- Data lane: breathwork uid-keys survive deletion; offline-delete
  server latency; prescribed-adopt stance; day-reflection no-retry;
  p38 two-device flap (server tombstone founder-gated).
- Notifications: second-device plate doesn't cancel evening review;
  food-settings "8:30pm" subtitle vs bucket hours.
- Temporal: meal TIME-of-day remains unrepresentable (deliberate law —
  inventing a time is inventing a fact; fix the DISPLAY lie T-D2
  instead); words door stays yesterday-only V1; dose backfill 14-day cap.
- HK: sleep multi-source double-count; no movement/sleep observers.

### NOT A PROBLEM (verified sound this pass)

- Consent-gate route completeness (one wire path, every entry gated).
- Deletion ledger / tombstones / hydrate NULL laws / retry idempotency
  / launch order — all chokepoints verified standing.
- One-fold laws (trendSeries, recordedKcal) hold for every consumer
  added since p53.
- HK purpose strings enumerate exactly the 12 read types; no dead
  permissions; denial grammar honest on every consumer; analytics clean.
- Notification lock-screen privacy (no compound/dose/weight/symptom).
- Deep-link map complete; permission-denied paths sound; wall-clock
  triggers DST-safe.
- Dose backfill re-anchors interval chain, cycle position, reminders,
  pen count, envelope (verified end-to-end) — apart from T-D1.
- Backdated plates: celebrations can't fire, beat can't mark, HK
  exports at stated day, morning read picks them up.

## 1 · Founder's two temporal questions, answered

**(a) Forgotten GLP-1 shot with the actual date:** YES at day level —
"+ add a past shot" (14 days) through the one DoseSheet; chain,
cycle, reminders, pen, envelope all re-derive. One material defect
(T-D1's wrong default chip) fixed this pass.

**(b) Food Snap to the actual meal date/time:** Date YES — words door
files "last night…" to yesterday automatically; any filed plate moves
across 14 days via the plate page's day row (same id, photo travels,
HK stays put = T-D3). TIME is deliberately not representable (the
clock law); this pass fixes the display lie (T-D2) rather than
inventing a stated-time model.

