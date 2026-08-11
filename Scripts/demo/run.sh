#!/usr/bin/env bash
# The Jeni clinic demo — the iOS half.
#
# THE LOOP SPANS TWO REPOSITORIES.
#   jeni-health-web  the clinic: the clinician product, the demo
#                    clinic's data, the local Supabase stack.
#   plankAI (here)   the patient: the app that connects to it.
# This script owns the phone. The clinic is reset and seeded from the
# web repository (scripts/demo/stack.sh there), which this script
# calls so that one command still runs the whole loop.
#
#   scripts/demo/run.sh fresh     everything, from nothing → ready to demo
#   scripts/demo/run.sh reset     wipe the clinic + reinstall the app
#   scripts/demo/run.sh build     rebuild + reinstall the iOS app
#   scripts/demo/run.sh patient   launch Maya's app (already-connected state)
#   scripts/demo/run.sh connect   launch and connect with JENI-DEMO
#   scripts/demo/run.sh assign    the clinician authors her care
#   scripts/demo/run.sh receive   relaunch so the plan lands + reconcile
#   scripts/demo/run.sh dash      start the clinician dashboard
#   scripts/demo/run.sh status    what state everything is in
#
# `fresh` is the one to run before a demo. It is deterministic: the
# database is dropped and rebuilt from the real migration chain, the
# app is reinstalled (a new anonymous patient), and every date is an
# offset from today, so the story is always "three weeks ago" and
# never a stale absolute.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
WEB="${JENI_WEB_REPO:-$(cd "$ROOT/../jeni-health-web" 2>/dev/null && pwd)}"
if [ -z "$WEB" ] || [ ! -d "$WEB/scripts/demo" ]; then
  echo "cannot find the web repository (the clinic lives there)." >&2
  echo "set JENI_WEB_REPO=/path/to/jeni-health-web and retry." >&2
  exit 1
fi
# shellcheck source=/dev/null
source "$WEB/scripts/demo/env.sh"

SIM="${DEMO_SIM_UDID:-259952D4-444F-4EFE-864A-F3DD5FBA5D22}"
APP="build/DemoDD/Build/Products/Debug-iphonesimulator/plankAI.app"
BUNDLE="com.bk.plankAI"
DASH_LOG="/tmp/jeni-demo-dashboard.log"
DASH_URL="http://localhost:3000/care"

# Every launch carries these: the demo backend, Maya's ten weeks, her
# consumer entitlement (she was a paying member before her clinic
# adopted Jeni), and no once-a-day cover racing the camera.
BASE_ARGS=(--demo-backend --demo-patient --uitest-pro-access --uitest-suppress-letter)

say() { printf '\n\033[1m%s\033[0m\n' "$*"; }

boot_sim() {
  xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1 || xcrun simctl boot "$SIM" >/dev/null 2>&1 || true
  open -a Simulator >/dev/null 2>&1 || true
  # A clock that never reads 2:46 in a screenshot.
  xcrun simctl status_bar "$SIM" override --time "9:41" \
    --cellularMode active --cellularBars 4 --wifiBars 3 --batteryState discharging --batteryLevel 100 \
    >/dev/null 2>&1 || true
}

build_app() {
  say "building the iOS app"
  xcodebuild -project plankAI.xcodeproj -scheme plankAI -configuration Debug \
    -destination "id=$SIM" -derivedDataPath build/DemoDD build 2>&1 \
    | grep -E "error:|warning: no rule|BUILD SUCCEEDED|BUILD FAILED" | tail -5
}

install_app() {
  boot_sim
  xcrun simctl uninstall "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl install "$SIM" "$APP"
}

launch() { # extra args...
  xcrun simctl terminate "$SIM" "$BUNDLE" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM" "$BUNDLE" "${BASE_ARGS[@]}" "$@" >/dev/null
}

start_dashboard() {
  if curl -sf -o /dev/null "$DASH_URL"; then
    echo "  dashboard already running · $DASH_URL"
    return
  fi
  (cd "$WEB" && npm run dev >"$DASH_LOG" 2>&1 &)
  for _ in $(seq 1 60); do
    if curl -sf -o /dev/null "$DASH_URL"; then
      echo "  dashboard up · $DASH_URL"; return
    fi
    sleep 1
  done
  echo "  dashboard did not come up — see $DASH_LOG" >&2
}

case "${1:-fresh}" in
  build)
    build_app; install_app ;;

  reset)
    say "resetting the demo clinic"
    "$WEB/scripts/demo/stack.sh" reset
    install_app ;;

  patient)
    say "launching Maya's app"
    launch --uitest-care-refresh --uitest-care-auto-confirm ;;

  connect)
    say "connecting with $DEMO_CLINIC_CODE"
    launch --uitest-care-connect-code "$DEMO_CLINIC_CODE" --uitest-care-refresh ;;

  assign)
    say "the clinician authors her care"
    python3 "$WEB/scripts/demo/assign.py" all ;;

  receive)
    say "the plan lands in the app"
    launch --uitest-care-refresh ;;

  dash)
    say "clinician dashboard"; start_dashboard ;;

  status)
    python3 "$WEB/scripts/demo/seed.py" --status
    echo
    curl -sf -o /dev/null "$DASH_URL" \
      && echo "dashboard      running · $DASH_URL" \
      || echo "dashboard      not running (scripts/demo/run.sh dash)"
    xcrun simctl list devices | grep -q "$SIM.*Booted" \
      && echo "simulator      booted" || echo "simulator      not booted" ;;

  fresh)
    say "THE WHOLE LOOP, FROM NOTHING"
    "$WEB/scripts/demo/stack.sh" reset
    build_app
    install_app
    start_dashboard
    say "seeding Maya + connecting with $DEMO_CLINIC_CODE"
    launch --uitest-care-connect-code "$DEMO_CLINIC_CODE" --uitest-care-refresh
    sleep 22
    say "the clinician authors her care"
    python3 "$WEB/scripts/demo/assign.py" all
    say "the plan lands, and she confirms it"
    launch --uitest-care-refresh --uitest-care-auto-confirm
    sleep 18
    say "publishing her record back to the clinic"
    launch --uitest-care-refresh
    sleep 14
    "$ROOT/scripts/demo/run.sh" status
    say "ready. dashboard: $DASH_URL  ·  sign in as $DEMO_CLINICIAN_EMAIL / $DEMO_PASSWORD" ;;

  *)
    sed -n '2,20p' "$0"; exit 1 ;;
esac
