#!/usr/bin/env bash
# THE iOS CAPTURE SYSTEM.
#
#   scripts/demo/capture_ios.sh [outdir]
#
# Deterministic frames of the patient product in its clinic-connected
# states, driven by launch doors rather than by taps — a launch door
# lands on the same pixel every time, and a synthesized tap does not.
#
# The order matters and is the point: the reconciliation sheet can only
# be photographed BEFORE it is confirmed, and the "enter your clinic's
# code" screen only before she is connected. So this walks the story
# forward once, taking each frame at the only moment it exists.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
# shellcheck source=/dev/null
source "$ROOT/scripts/demo/env.sh"

SIM="${DEMO_SIM_UDID:-259952D4-444F-4EFE-864A-F3DD5FBA5D22}"
BUNDLE="com.bk.plankAI"
APP="build/DemoDD/Build/Products/Debug-iphonesimulator/plankAI.app"
OUT="${1:-$ROOT/docs/demo/shots/ios}"
BASE_ARGS=(--demo-backend --demo-patient --uitest-pro-access --uitest-suppress-letter)

mkdir -p "$OUT"

boot() {
  xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl status_bar "$SIM" override --time "9:41" \
    --cellularMode active --cellularBars 4 --wifiBars 3 \
    --batteryState discharging --batteryLevel 100 >/dev/null 2>&1 || true
}

launch() { # settle-seconds, then args...
  local settle="$1"; shift
  xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM" "$BUNDLE" "${BASE_ARGS[@]}" "$@" >/dev/null
  sleep "$settle"
}

shot() {
  xcrun simctl io "$SIM" screenshot "$OUT/$1.png" >/dev/null 2>&1
  echo "  $1.png"
}

echo "capturing → $OUT"
boot

# A fresh install mints a fresh anonymous patient, so the story starts
# where it should: an existing Jeni member with ten weeks of her own
# record and no clinic attached to it.
echo "resetting the clinic + the phone"
"$ROOT/scripts/demo/stack.sh" reset >/dev/null
xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"

# 1 — her own Today, before any clinic exists.
launch 20 --uitest-suppress-reconcile
shot "01-today-before"

# 2 — the door: "connect with your clinic."
launch 18 --uitest-open-care-connect --uitest-care-prefill-code --uitest-suppress-reconcile
shot "02-connect-enter-code"

# 3 — connected, with the real code, through the real RPCs.
launch 20 --uitest-care-connect-code "$DEMO_CLINIC_CODE" --uitest-care-refresh --uitest-suppress-reconcile
shot "03-connected"

# 4 — the clinician authors her care.
echo "the clinician assigns"
python3 "$ROOT/scripts/demo/assign.py" all >/dev/null

# 5 — the plan arrives. This frame exists exactly once.
launch 18 --uitest-care-refresh
shot "04-reconciliation"

# 6 — she confirms, and Today follows the clinic's plan.
launch 18 --uitest-care-refresh --uitest-care-auto-confirm
shot "05-today-clinic-plan"

# 7 — the medication surface, in its read-only care-team face.
launch 16 --uitest-care-refresh --uitest-open-regimen
shot "06-regimen-care-face"

# 8 — the dose sheet: the action the clinic's plan produces.
launch 16 --uitest-care-refresh --uitest-open-dose-sheet
shot "07-dose-sheet"

# 9 — Becoming, care-first: the record she can hand over.
launch 16 --uitest-care-refresh --uitest-start-tab becoming
shot "08-becoming"

# 10 — back to Today, the state the demo rests in.
launch 16 --uitest-care-refresh
shot "09-today-final"

echo
echo "the phone is left in its demo state (connected, plan confirmed)."
