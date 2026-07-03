# 26 — Premium gap audit (v2.7, brutal)

Date: 2026-07-03. Method: use the app + read frames like a designer,
not a QA bot. What I found, in the founder's terms:

## What still felt cheap (verdicts, then fixes)

1. **The state band rendered DEAD.** Gauges animated on change but
   not on arrival — and the awakening I first added played at MOUNT,
   below the fold, unseen (frame-diff proof: zero motion at the
   band's reveal). The most-seen module met her pre-filled and
   static. FIXED: visibility-triggered awakening (arc draws, numeral
   counts, ring follows, staggered) with pre-iOS-18 fallback +
   reduce-motion respect. Proven by ease-out pixel-decay signature
   (985→679→76px) and a mid-draw frame.
2. **Completing a beat was a state flip, not a moment.** The strike
   existed but drew in 0.18s racing the cover dismissal. FIXED:
   waits for the cover to clear, draws at pen speed, tick cascade
   rides the line.
3. **Text could ellipsize.** Census: beat titles/subtitles (hard
   lineLimit(1)), masthead eyebrow, CTA labels in a fixed 56pt frame
   (wrap-clip risk), onboarding pills. FIXED with a clipping
   contract: scale-never-truncate floors across the component system
   (JFContinueButton 0.78, beat rows 0.78/0.82, eyebrow 0.8, pills
   0.85). VERIFIED at iPhone SE width — zero "…" in the ledger shots.
4. **The lesson close was a read, not a rep.** FIXED: doc-22 rep
   sentences render as a tappable commitment chip — tap = haptic +
   cocoa fill + "kept. it's on today ♥". Walker-proven both states.
5. **Cross-account data bleed (found BY the motion QA).** todayMacros
   summed every account's plates on device; after a sign-out→new-anon
   switch the old user's lunch fed the new user's kcal line (frame:
   empty plate strip + "860" kcal). FIXED: user-scoped overload +
   case-insensitive uuid compare in allEntries.

## What I expected to be weak but ISN'T (honest)

- **Breath session core**: painted bloom + ambient rotation +
  countdown-in-hollow + generation-guarded haptics — not a plain
  circle. The clone-feel was the doorways (fixed in v2.4).
- **Trend canvas**: already has trace-in, idle shimmer, drag-scrub
  with haptic detents, double-tap window cycling. Interactive.
- **Reader**: paper canvas, pin-dot save, shader chrome. Premium.
- **Snap result carousel**: still the signature.

## Still on the list (honest, small)

- SnapResultView's "today's protein" reads device-today (needs
  userId plumbed through the capture config) — same-user-correct,
  wrong only mid-account-switch.
- JKPlateStrip items could stagger-in individually.
- The kcal line doesn't count up on awaken (numericText rides
  changes only).
- 54 legacy ♡ glyphs in lesson bodies (render acceptably; sweep to
  ♥︎ with the content pass).
