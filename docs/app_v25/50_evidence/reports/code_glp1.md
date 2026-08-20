# AGENT EXTRACT — GLP-1 record code audit (ac34a096)

CATALOG: 9 products (ozempic/wegovy/mounjaro/zepbound/trulicity weekly inj; saxenda DAILY inj; rybelsus oral daily emptyStomach; 2 compounded weekly). Ladders = label facts never caps; custom dose 0<x<100 decimal (RegimenSheet:703-727). "Something else" = productId nil + her words. Compounded: no labelFacts by construction. Analytics/chat carry COMPOUND never brand.

SCHEDULE: RegimenPlanRecord scheduleRule ∈ {weeklyAnchor, daily, asNeeded(no writers)}; anchorWeekday single Int. MedicationScheduleEngine.isDoseDay has exactly 2 live arms (:183-191).
NOT REPRESENTABLE: every-5/10-days (no interval field) · twice-weekly (single anchor) · split/2nd dose same day (deterministic id "<uid>-dose-<day>", DoseEventStore:19-21) · two concurrent meds (v1 contract) · per-event mg (strength joined from version) · real therapy start date / pre-Jeni history (startedAt stamped at creation, NO editor; 35d missed lookback, 8d late window, no date picker on DoseSheet) · editing takenAt clock time · non-7-day cycle (length=7 const :126).
CUSTOM INTERVAL FAILURE MODE = TOTAL SILENCE: never a dose day, no reminder, no cycle, no standing, ledger never grows, packet counts 0.
7-DAY HARDCODES: CyclePosition length 7; late window +7d; bands ≤2/3-5/6+; lateDoseWeekDays 5...7; dosesExpected 1-or-7 (JourneyModel:319); read anchor %7.

DEFECTS FOUND:
- **VisitPacket calls EVERY self-reported regimen "your weekly medication" (VisitPacket.swift:189) — a daily Rybelsus user's clinician packet misstates cadence; AND daily-cadence users get scheduledCount 0 (anchor-gated loop :196-204).**
- **TodayStateService.dayKey (:172-177) lacks POSIX locale pin its siblings carry — dayKey producers could disagree on non-Latin-numeral locales; slot ids come from THIS one.**
- Coach/chat cadence collapses to daily?daily:weekly (CoachContextAssembler:371) — asNeeded would be "weekly".
- Late LOG stamps takenAt=tap time → cycle anchor can sit a day off true injection; not editable after.
- Dose event hydrate insert-only (SyncService:1708-1719) → cross-device edits never propagate.
- Symptom NOTES never sync (payload excluded, SyncService:846-867) — device-local only, no UI lists them.

GOOD (verdict-relevant): dose events carry time-of-day + site + skip reasons + source; deterministic converge; late/missed derived reversibly; past-row edit exists (DoseSheet slotDayKey; "tap any of these to fix"); unmark + tombstone; symptoms 14 kinds × 3 severities × 14-day back + delete synced; version chains supersede-never-mutate with endReason vocabulary; titration continuity (schedule-only inherits startedAt); pause/stop/restart UI; wall-clock DST-safe engine (bySettingHour, nextDate, POSIX pins, f.timeZone printers); reminders re-evaluate on tz change; refusals (care-team plans, prescribed facts, memory bans dose content); RLS tightened (bearer can't write care_team rows); care-team read-only face + CorrectionSheet (never mutates).
VisitPacket symptoms: word+count+timing-note (≥2 within 0-2d post-dose), severity does NOT reach packet.
