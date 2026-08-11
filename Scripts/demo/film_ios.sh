#!/usr/bin/env bash
# THE PATIENT HALF OF THE FILM — recorded, not photographed.
#
#   scripts/demo/film_ios.sh [outdir]
#
# Three short takes of the real app on the simulator, captured live so
# the film carries the product's OWN motion: the reconciliation sheet
# rising, the sheet resolving, Today composing with the clinic's plan
# in it. No synthesized taps and no drawn cursor — a finger that is not
# there is worse than no finger at all.
#
# The takes are cut apart in film.sh, and the relaunch between them is
# hidden under a dissolve. Both takes are the real product; the join is
# the only thing that is edited.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
WEB="${JENI_WEB_REPO:-$(cd "$ROOT/../jeni-health-web" 2>/dev/null && pwd)}"
# shellcheck source=/dev/null
source "$WEB/scripts/demo/env.sh"

SIM="${DEMO_SIM_UDID:-259952D4-444F-4EFE-864A-F3DD5FBA5D22}"
BUNDLE="com.bk.plankAI"
APP="build/DemoDD/Build/Products/Debug-iphonesimulator/plankAI.app"
OUT="${1:-$WEB/docs/demo/film/raw}"
BASE=(--demo-backend --demo-patient --uitest-pro-access --uitest-suppress-letter)

mkdir -p "$OUT"

boot() {
  xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  xcrun simctl status_bar "$SIM" override --time "9:41" \
    --cellularMode active --cellularBars 4 --wifiBars 3 \
    --batteryState discharging --batteryLevel 100 >/dev/null 2>&1 || true
}

# Record a take: start the camera, launch, hold, stop. The launch
# happens INSIDE the recording so the product's own arrival animation
# is captured; the cold-start frames are trimmed in film.sh.
take() { # <name> <seconds> <args...>
  local name="$1" secs="$2"; shift 2
  local f="$OUT/ios-$name.mov"
  rm -f "$f"
  xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
  sleep 1
  xcrun simctl io "$SIM" recordVideo --codec h264 --force "$f" &
  local rec=$!
  sleep 1.5
  xcrun simctl launch "$SIM" "$BUNDLE" "${BASE[@]}" "$@" >/dev/null
  sleep "$secs"
  kill -INT $rec 2>/dev/null || true
  wait $rec 2>/dev/null || true
  echo "  ios-$name.mov (${secs}s)"
}

echo "recording the patient half → $OUT"
boot

# The state the film needs: connected and assigned, but NOT yet
# reconciled — the sheet only exists before it is confirmed.
echo "setting the stage"
"$WEB/scripts/demo/stack.sh" reset >/dev/null
xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$SIM" "$APP"
xcrun simctl launch "$SIM" "$BUNDLE" "${BASE[@]}" \
  --uitest-care-connect-code "$DEMO_CLINIC_CODE" --uitest-care-refresh \
  --uitest-suppress-reconcile >/dev/null
sleep 22
python3 "$WEB/scripts/demo/assign.py" all >/dev/null

# take 1 — the plan arrives and the sheet rises
take arrive 20 --uitest-care-refresh

# take 2 — confirmed, and Today composes with the clinic's plan
take today 18 --uitest-care-refresh --uitest-care-auto-confirm

# take 3 — the medication card, in its read-only care-team face
take med 16 --uitest-care-refresh --uitest-open-regimen

echo
echo "done. film.sh cuts these together."
