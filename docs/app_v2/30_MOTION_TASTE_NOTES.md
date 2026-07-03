# 30 — Motion-taste pass (v2.9): flow videos as the source of truth

Date: 2026-07-03. Method: continuous recordings of real driven flows
(walker legs + self-driving demo args) read as contact sheets; judge
like a user, fix only what motion exposes; restraint elsewhere.

## Verdicts from watching, per flow

### Breathwork full flow — session EXCELLENT, landing was FLAT → FIXED
70s continuous capture (breath_flow.mp4, ~40s session + receipt).
The session is genuinely alive: dramatic bloom scale between
"breathe in" and "let it go", countdown in the hollow, serif phase
words — nothing meditation-clone about it in motion. THE FIND: after
sixty seconds of rhythm the receipt landed on one frame and sat
identical for 24s (boundary strip at 2fps shows the hard swap).
FIX SHIPPED: the receipt now exhales into place — headline settles
(0.55s), mechanism follows (+0.35s), her week assembles dot by dot
(spring, 70ms stagger, +0.7s), the door last (+1.3s); haptic rides
the headline. Trigger flips plainly so no transaction can flatten
the cascade.

### Method lesson → rep → handoff — GOOD in motion, left alone
The rep chip's tap-to-kept transform (symbol replace + fill +
haptic) proved live in the walker leg (95/96 pair). The reader's
page rhythm is deliberate. Restraint: no churn.

### Today completion moments — GOOD (v2.7 strike), verified again
Strike-as-moment + band awakening re-proven in the fresh ledger's
band captures; entrance stagger caught mid-flight in band_v28.mp4.

### Jeni chat handoff — verified by prior evidence, left alone
Send/stream/tool-card motion is code-defined (.opacity+offset
transitions, thinking indicator, numericText) and proven in earlier
captures; the demo-arg recording window missed the flow this pass
(launch chrome ate the 22s window). Judged: not the weak link.

### Snap / food-log / weight flows — stills + walker green; honest gap
The result carousel, journal, and trend scrub carry earlier
verification (v2.1-2.7). Continuous end-to-end recordings of these
three remain the missing archive pieces — listed as the follow-up,
not because they're suspected weak but because the archive should
match the breath standard.

## Recording rig notes (for the next pass)
- simctl recordVideo dies when xcodebuild test restarts the sim —
  start recording AFTER the leg boots the app.
- `timeout -s INT` (SIGINT), never default TERM — the moov atom
  needs the graceful stop.
- Contact sheets: fps=1/6 for flow shape, fps=2 for boundaries.

## After changes
Unit suite green. Full walker + SE re-verification in flight at
commit time (results in the commit message).
