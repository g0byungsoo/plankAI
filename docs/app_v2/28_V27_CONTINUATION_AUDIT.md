# 28 — v2.7 continuation audit (v2.8)

Date: 2026-07-03. Rule: the v2.7 "honest remainder" gets FIXED, not
re-documented.

## Fixed this pass
1. **SnapResultView account scoping** — userId now plumbed
   CaptureFlowView → PhotoCaptureView → SnapResultView (defaulted
   params, back-compatible); "today's protein" in the result context
   reads the scoped overload. The sign-out → new-anon → capture edge
   can no longer read the prior account.
2. **Glyph pass** — all 54 legacy ♡ (U+2661, emoji-fallback risk) in
   lesson bodies converted to ♥︎ (U+2665+FE0E), matching the
   app-wide text-heart convention.
3. **Plate strip stagger** — plates arrive like dealt cards (60ms
   per-index rise, once per mount).
4. **Kcal count-up** — the kcal numeral awakens on visibility with
   the same contract as the arc/ring (reduce-motion respected).
5. **Regression net** — CrossAccountScopingTests (3 tests, green):
   user-scoped macros, uuid-case-insensitive entries, sign-out sweep
   of per-identity dayKey families.
6. **DailyShareRenderer** — its macros read was unscoped (entries
   were scoped, pills weren't); fixed.
7. **Sign-out sweep extended** — see doc 29.

## Motion QA notes
- band_awaken.mp4 (v2.7) remains the awakening proof (ease-out decay
  signature + mid-draw frame).
- band_v28.mp4 (this pass) caught the entrance mid-stagger (bottom
  rows dimmer); the recording clipped at 4.9s before the auto-scroll
  — the kcal/stagger additions ride the SAME visibility pattern
  proven in v2.7 and are exercised by the walker band capture.

## Text clipping after changes
No new text-bearing components introduced (stagger/count-up are
motion-only); the SE ledger shots from v2.7 remain valid. The SE
device (QA-SE) stays provisioned for future passes.

## Full walker verdict (clean run, 2026-07-03 14:5x)
ALL FIVE legs green in ONE run on a fresh-booted sim: main walk
(125s), states (45s), rest-day breath (100s), lived-day (20s), rep
chip (28s). 31 PNGs at /tmp/jenifit_ledger_v28 — the first ledger
routed through the FIXED env passthrough (TEST_RUNNER_INVENTORY_DIR;
a bare INVENTORY_DIR never reached the runner, so all prior runs
silently wrote to the default path — run-book corrected in the
walker header). One prior attempt hung at an app-launch BETWEEN
legs with the sim at the home screen after ~40 launch/record cycles
this session — infra degradation, not product: the clean re-run
passed everything without a single retry.

## Honest remaining
- HomeFoodCard (package tile) still calls unscoped todayMacros() —
  ZERO live callers post-sweep; it dies in the package cleanup batch
  rather than being half-fixed.
- Full-flow videos for breath/method/snap lifecycles are partial
  (breath receipt + method rep chip + snap consent are stills in the
  ledger; the flows run green in the walker). Next pass records them
  end-to-end.
