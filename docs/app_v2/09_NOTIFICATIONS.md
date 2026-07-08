# 09 — Notification strategy v2

## Intent

One orchestrator, one copy source (the voice contract), hard caps,
deep links into the new surfaces, cohort variants preserved. Nothing
fires that isn't personally useful; nothing names unshipped features.

## Consolidation

New `NotificationOrchestrator` (PlankApp/Notifications/) absorbs the
scheduling entry points scattered across RetentionNotifications,
NotificationPermission (moves out of OnboardingComponents),
TrialEndNotificationService, RecapNotificationService. All ids,
categories, and copy pools live in one `NotificationCatalog`.
Existing pending-request surgical-removal discipline is preserved.

## Categories (the full set — nothing else fires)

| id | When | Copy | Deep link |
|---|---|---|---|
| daily_anchor | her promise hour, repeating | brief-engine line of tomorrow's shape (voice-adaptive, name) | jenifit://today |
| day1_promise | day-1 at her hour (kept) | her words back | jenifit://snap |
| evening_plate | ~20:30, only if ≥1 snap in last 3 days AND none today after 17:00 | "today's plate ♥" | jenifit://snap |
| weigh_in_morning | only on cadence days (04), 9:00 bucket | "trend line day — thirty seconds" | jenifit://weigh-in |
| weekly_recap | Sun 17:00, earned (≥2 engaged days) | "your week, kept" | jenifit://becoming |
| milestone_{n} | 3/7/14/30/50/100 shown-up days | existing pool | jenifit://today |
| winback_lapse | 48h idle, re-armed per session | cohort-aware comeback | jenifit://today |
| jeni_unread | ONLY if her question to jeni got a reply she never opened | "jeni answered ♥" | jenifit://jeni |
| trial/day5 machinery | unchanged (dormant while pay-upfront) | — | — |

Caps: max 1/day except day-1 (2), max 5/wk total (research ceiling),
promise + anchor never both fire the same evening. The orchestrator
enforces caps globally (today they're per-category and can stack).

## Cohort layer

Copy pools keep the four-cohort variants (existing Glp1Cohort
plumbing) with the 09/04 rule: cohort lives in the noun phrase
("protein day" / "your maintenance rhythm"), bodies only reference
live features. Post-GLP-1 weekly framing on recap + weigh-in lines.

## Deep links

`AppRouter.handle(url:)` — notifications carry `jenifit://` URLs in
userInfo; a UNUserNotificationCenterDelegate (new, tiny) forwards to
the router post-phase-resolution (queued until .main so a tap never
races the wall — an expired user tapping a push lands on the wall,
never inside).

## What dies

- `food_first_log_nudge` dead code (already cut, delete fully).
- day0_anchor/day2_engagement legacy sweeps (kept as cleanup calls
  for one release, then gone).
- Duplicate voice→name switch in dailyReminderBody (reads CoachAsset
  like everything else).
